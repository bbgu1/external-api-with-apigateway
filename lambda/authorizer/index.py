"""
Lambda Authorizer for API Gateway
Validates Cognito JWT tokens and returns usageIdentifierKey for rate limiting.

When api_key_source = "AUTHORIZER" on the REST API, API Gateway uses the
usageIdentifierKey from this authorizer's response to enforce usage plan limits.
This allows per-tenant rate limiting without requiring an x-api-key header.

Two SSM parameters are used (both populated by the terraform/tenants workspace):
- client_tenant_map: {cognito_client_id: tenant_id}  — resolves who the caller is
- tenant_api_key_map: {tenant_id: api_key_value}      — maps tenant to usage plan key

The resolved tenant_id is passed to downstream Lambdas via the authorizer response
context, so they never need to parse the JWT themselves.
"""

import json
import os
import time
import urllib.request
from functools import lru_cache

import boto3
import jwt  # PyJWT
from jwt.algorithms import RSAAlgorithm


REGION = os.environ.get("AWS_REGION", "us-east-1")
USER_POOL_ID = os.environ["COGNITO_USER_POOL_ID"]
JWKS_URL = f"https://cognito-idp.{REGION}.amazonaws.com/{USER_POOL_ID}/.well-known/jwks.json"

# SSM parameter paths
TENANT_API_KEY_MAP_PATH = os.environ["TENANT_MAP_SSM_PATH"]
CLIENT_TENANT_MAP_PATH = os.environ["CLIENT_TENANT_MAP_SSM_PATH"]

# In-memory caches (refreshed every ~5 minutes)
_CACHE_TTL_SECONDS = 300

_tenant_api_key_cache = {"data": {}, "expires_at": 0}
_client_tenant_cache = {"data": {}, "expires_at": 0}

ssm_client = boto3.client("ssm", region_name=REGION)


def _get_ssm_json(path: str, cache: dict) -> dict:
    """Load a JSON SSM parameter with in-memory TTL cache."""
    now = time.time()
    if cache["data"] and now < cache["expires_at"]:
        return cache["data"]

    try:
        resp = ssm_client.get_parameter(Name=path, WithDecryption=True)
        data = json.loads(resp["Parameter"]["Value"])
    except Exception as e:
        print(f"Failed to load SSM parameter {path}: {e}")
        return cache["data"] or {}

    cache["data"] = data
    cache["expires_at"] = now + _CACHE_TTL_SECONDS
    return data


def _get_tenant_api_key_map() -> dict:
    """Load tenant_id → API key value map."""
    return _get_ssm_json(TENANT_API_KEY_MAP_PATH, _tenant_api_key_cache)


def _get_client_tenant_map() -> dict:
    """Load client_id → tenant_id map."""
    return _get_ssm_json(CLIENT_TENANT_MAP_PATH, _client_tenant_cache)


@lru_cache(maxsize=1)
def _get_jwks() -> dict:
    """Fetch and cache JWKS from Cognito. Cached for Lambda container lifetime."""
    with urllib.request.urlopen(JWKS_URL, timeout=5) as resp:
        return json.loads(resp.read())


def _get_public_key(kid: str):
    """Return the RSA public key matching the given key ID."""
    jwks = _get_jwks()
    for key_data in jwks.get("keys", []):
        if key_data["kid"] == kid:
            return RSAAlgorithm.from_jwk(json.dumps(key_data))
    raise ValueError(f"No matching key found for kid={kid}")


def _validate_token(token: str) -> dict:
    """Validate JWT signature and expiry. Returns claims dict."""
    header = jwt.get_unverified_header(token)
    public_key = _get_public_key(header["kid"])

    claims = jwt.decode(
        token,
        public_key,
        algorithms=["RS256"],
        options={"verify_exp": True},
    )

    if claims.get("token_use") != "access":
        raise ValueError("token_use must be 'access'")

    return claims


def _build_policy(principal_id: str, effect: str, resource: str,
                  usage_key: str = None, tenant_id: str = None) -> dict:
    """Build IAM policy document for API Gateway authorizer response.

    The 'context' dict is forwarded to downstream Lambdas at
    event.requestContext.authorizer.<key>.
    """
    arn_parts = resource.split(":")
    if len(arn_parts) >= 6:
        api_part = arn_parts[5].split("/")[0]
        wildcard_resource = f"{':'.join(arn_parts[:5])}:{api_part}/*"
    else:
        wildcard_resource = resource

    policy = {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": effect,
                    "Resource": wildcard_resource,
                }
            ],
        },
        "context": {},
    }
    if usage_key:
        policy["usageIdentifierKey"] = usage_key
    if tenant_id:
        policy["context"]["tenant_id"] = tenant_id
    return policy


def lambda_handler(event, context):
    """
    TOKEN-type Lambda authorizer entry point.

    Flow:
    1. Extract Bearer token from Authorization header
    2. Validate JWT signature against Cognito JWKS
    3. Resolve tenant_id from client_id via SSM client→tenant map
    4. Look up tenant's API key value from SSM tenant→API-key map
    5. Return Allow policy with usageIdentifierKey and tenant_id in context
    """
    token_str = event.get("authorizationToken", "")
    method_arn = event.get("methodArn", "*")

    if token_str.lower().startswith("bearer "):
        token_str = token_str[7:]

    if not token_str:
        raise Exception("Unauthorized")

    try:
        claims = _validate_token(token_str)
    except Exception as e:
        print(f"Token validation failed: {e}")
        raise Exception("Unauthorized")

    # Resolve tenant_id from client_id using SSM mapping
    client_id = claims.get("client_id") or claims.get("sub", "")
    client_tenant_map = _get_client_tenant_map()
    tenant_id = client_tenant_map.get(client_id)

    if not tenant_id:
        print(f"Unknown client_id={client_id}, no tenant mapping found")
        return _build_policy(client_id or "unknown", "Deny", method_arn)

    print(f"Resolved client_id={client_id} -> tenant_id={tenant_id}")

    # Look up the tenant's API key value for usage plan enforcement
    tenant_api_key_map = _get_tenant_api_key_map()
    api_key_value = tenant_api_key_map.get(tenant_id)

    if not api_key_value:
        print(f"Tenant {tenant_id} has no API key mapping")
        return _build_policy(tenant_id, "Deny", method_arn)

    print(f"Authorized tenant={tenant_id}, applying usage plan key")
    return _build_policy(tenant_id, "Allow", method_arn,
                         usage_key=api_key_value, tenant_id=tenant_id)
