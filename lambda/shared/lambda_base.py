"""
Base Lambda handler template with X-Ray integration.

This module provides common functionality for all Lambda functions including:
- X-Ray tracing with tenant_id and request_id annotations
- Structured JSON logging
- Tenant ID extraction from Lambda authorizer context
- Error handling with proper status codes
- Common request/response handling

Requirements: 2.3, 7.2, 9.2, 9.5, 11.1, 11.2, 11.4
"""

import json
import os
import traceback
from datetime import datetime
from decimal import Decimal
from typing import Dict, Any, Callable
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

# Patch AWS SDK for X-Ray tracing
patch_all()

class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder for DynamoDB Decimal types."""
    
    def default(self, obj):
        if isinstance(obj, Decimal):
            # Convert Decimal to int if it's a whole number, otherwise float
            if obj % 1 == 0:
                return int(obj)
            else:
                return float(obj)
        return super(DecimalEncoder, self).default(obj)


class LambdaResponse:
    """Helper class for building Lambda responses."""
    
    @staticmethod
    def success(data: Any, tenant_id: str, request_id: str, status_code: int = 200) -> Dict[str, Any]:
        """
        Build a successful response.
        
        Args:
            data: Response data
            tenant_id: Tenant identifier
            request_id: Request identifier
            status_code: HTTP status code (default: 200)
            
        Returns:
            Lambda response dictionary
        """
        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
            },
            'body': json.dumps({
                'data': data,
                'tenantId': tenant_id,
                'requestId': request_id,
                'timestamp': datetime.utcnow().isoformat() + 'Z'
            }, cls=DecimalEncoder)
        }
    
    @staticmethod
    def error(
        error_type: str,
        message: str,
        tenant_id: str,
        request_id: str,
        status_code: int = 500
    ) -> Dict[str, Any]:
        """
        Build an error response.
        
        Args:
            error_type: Error type (e.g., 'BadRequest', 'NotFound')
            message: Error message
            tenant_id: Tenant identifier
            request_id: Request identifier
            status_code: HTTP status code
            
        Returns:
            Lambda response dictionary
        """
        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
            },
            'body': json.dumps({
                'error': error_type,
                'message': message,
                'tenantId': tenant_id,
                'requestId': request_id,
                'timestamp': datetime.utcnow().isoformat() + 'Z'
            }, cls=DecimalEncoder)
        }


class StructuredLogger:
    """Structured JSON logger for Lambda functions."""
    
    def __init__(self, tenant_id: str, request_id: str):
        """
        Initialize logger with context.
        
        Args:
            tenant_id: Tenant identifier
            request_id: Request identifier
        """
        self.tenant_id = tenant_id
        self.request_id = request_id
        self.log_level = os.environ.get('LOG_LEVEL', 'INFO')
    
    def _log(self, level: str, message: str, **kwargs):
        """
        Log a structured JSON message.
        
        Args:
            level: Log level (INFO, ERROR, DEBUG, WARNING)
            message: Log message
            **kwargs: Additional context fields
        """
        log_entry = {
            'level': level,
            'message': message,
            'tenant_id': self.tenant_id,
            'request_id': self.request_id,
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            **kwargs
        }
        print(json.dumps(log_entry))
    
    def info(self, message: str, **kwargs):
        """Log info message."""
        self._log('INFO', message, **kwargs)
    
    def error(self, message: str, **kwargs):
        """Log error message."""
        self._log('ERROR', message, **kwargs)
    
    def debug(self, message: str, **kwargs):
        """Log debug message."""
        if self.log_level == 'DEBUG':
            self._log('DEBUG', message, **kwargs)
    
    def warning(self, message: str, **kwargs):
        """Log warning message."""
        self._log('WARNING', message, **kwargs)


def extract_tenant_id(event: Dict[str, Any]) -> str:
    """
    Extract tenant ID from the Lambda authorizer context.
    
    The Lambda authorizer resolves tenant_id from the Cognito client_id
    and passes it in the authorizer response context. Downstream Lambdas
    receive it at event.requestContext.authorizer.tenant_id.
    
    Args:
        event: Lambda event object
        
    Returns:
        Tenant ID string
        
    Raises:
        ValueError: If tenant_id is not present in authorizer context
    """
    try:
        tenant_id = event.get('requestContext', {}).get('authorizer', {}).get('tenant_id')
        if tenant_id:
            return tenant_id
        raise ValueError('tenant_id not found in authorizer context')
    except ValueError:
        raise
    except Exception as e:
        raise ValueError(f'Failed to extract tenant_id: {str(e)}')


def extract_request_id(event: Dict[str, Any]) -> str:
    """
    Extract request ID from the request context.
    
    Args:
        event: Lambda event object
        
    Returns:
        Request ID string
    """
    return event.get('requestContext', {}).get('requestId', 'unknown')


def verify_tenant_access(
    requesting_tenant_id: str,
    data_tenant_id: str,
    resource_type: str,
    resource_id: str,
    logger: StructuredLogger
) -> None:
    """
    Verify that the requesting tenant matches the tenant of the data being accessed.
    
    This function enforces tenant isolation by ensuring that a tenant can only
    access their own data. If a cross-tenant access attempt is detected, it logs
    a security violation and raises TenantIsolationError.
    
    Args:
        requesting_tenant_id: Tenant ID from authorizer context
        data_tenant_id: Tenant ID from the data being accessed
        resource_type: Type of resource (e.g., 'product', 'order')
        resource_id: ID of the resource being accessed
        logger: Structured logger instance
        
    Raises:
        TenantIsolationError: If tenant IDs don't match
        
    Requirements: 2.5
    """
    if requesting_tenant_id != data_tenant_id:
        logger.warning(
            'SECURITY VIOLATION: Cross-tenant access attempt detected',
            security_event='cross_tenant_access_attempt',
            requesting_tenant_id=requesting_tenant_id,
            data_tenant_id=data_tenant_id,
            resource_type=resource_type,
            resource_id=resource_id
        )
        raise TenantIsolationError(
            f'Access denied: Cannot access {resource_type} from another tenant'
        )


def extract_http_method(event: Dict[str, Any]) -> str:
    """
    Extract HTTP method from the request context.
    
    Args:
        event: Lambda event object
        
    Returns:
        HTTP method string (GET, POST, etc.)
    """
    return event.get('requestContext', {}).get('httpMethod', 'UNKNOWN')


def extract_path(event: Dict[str, Any]) -> str:
    """
    Extract request path from the request context.
    
    Args:
        event: Lambda event object
        
    Returns:
        Request path string
    """
    return event.get('requestContext', {}).get('path', 'unknown')


class TenantIsolationError(Exception):
    """Exception raised when cross-tenant access is attempted."""
    pass


def lambda_handler_wrapper(handler_func: Callable) -> Callable:
    """
    Decorator that wraps Lambda handlers with common functionality:
    - X-Ray tracing with annotations
    - Structured logging
    - Error handling
    - Request/response formatting
    
    Args:
        handler_func: The actual handler function to wrap
        
    Returns:
        Wrapped handler function
        
    Example:
        @lambda_handler_wrapper
        def my_handler(event, context, tenant_id, request_id, logger):
            # Your handler logic here
            return {'result': 'success'}
    """
    def wrapper(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        tenant_id = 'unknown'
        request_id = 'unknown'
        
        try:
            # Extract context information
            tenant_id = extract_tenant_id(event)
            request_id = extract_request_id(event)
            http_method = extract_http_method(event)
            path = extract_path(event)
            
            # Initialize logger
            logger = StructuredLogger(tenant_id, request_id)
            
            # Add X-Ray annotations for filtering and searching
            # Wrap in try-except to handle FacadeSegmentMutationException when API Gateway X-Ray is enabled
            try:
                xray_recorder.put_annotation('tenant_id', tenant_id)
                xray_recorder.put_annotation('request_id', request_id)
                xray_recorder.put_annotation('http_method', http_method)
                xray_recorder.put_annotation('endpoint', path)
            except Exception:
                # Silently ignore - API Gateway X-Ray creates facade segments that can't be mutated
                pass
            
            # Add X-Ray metadata for detailed analysis
            try:
                request_body = event.get('body', '')
                xray_recorder.put_metadata('request_body', request_body)
                xray_recorder.put_metadata('request_body_size', len(request_body) if request_body else 0)
                xray_recorder.put_metadata('path_parameters', event.get('pathParameters', {}))
                xray_recorder.put_metadata('query_parameters', event.get('queryStringParameters', {}))
            except Exception:
                # Silently ignore - API Gateway X-Ray creates facade segments that can't be mutated
                pass
            
            # Log request
            logger.info(
                'Processing request',
                http_method=http_method,
                path=path,
                source_ip=event.get('requestContext', {}).get('identity', {}).get('sourceIp')
            )
            
            # Call the actual handler
            result = handler_func(event, context, tenant_id, request_id, logger)
            
            # Serialize response for metadata (use DecimalEncoder for DynamoDB Decimal types)
            response_body = json.dumps(result, cls=DecimalEncoder)
            
            # Add response metadata to X-Ray trace
            try:
                xray_recorder.put_metadata('response_size', len(response_body))
                xray_recorder.put_metadata('response_data', result)
            except Exception:
                # Silently ignore - API Gateway X-Ray creates facade segments that can't be mutated
                pass
            
            # Log success
            logger.info('Request processed successfully', response_size=len(response_body))
            
            # Return success response
            return LambdaResponse.success(result, tenant_id, request_id)
        
        except TenantIsolationError as e:
            # Cross-tenant access attempts (403)
            logger = StructuredLogger(tenant_id, request_id)
            logger.error(
                'SECURITY VIOLATION: Cross-tenant access attempt',
                error_type='TenantIsolationError',
                error_message=str(e),
                security_event='cross_tenant_access',
                stack_trace=traceback.format_exc()
            )
            
            # Add error annotations to X-Ray trace for filtering
            try:
                xray_recorder.put_annotation('error', 'TenantIsolationViolation')
                xray_recorder.put_annotation('security_violation', 'cross_tenant_access')
                xray_recorder.put_annotation('error_status_code', 403)
            except Exception:
                pass
            
            # Add detailed error metadata to X-Ray trace
            try:
                xray_recorder.put_metadata('error_details', {
                    'type': 'TenantIsolationError',
                    'message': str(e),
                    'stack_trace': traceback.format_exc(),
                    'tenant_id': tenant_id,
                    'request_id': request_id,
                    'timestamp': datetime.utcnow().isoformat() + 'Z'
                })
            except Exception:
                pass
            
            return LambdaResponse.error(
                'Forbidden',
                'Access denied',
                tenant_id,
                request_id,
                403
            )
            
        except ValueError as e:
            # Validation errors (400)
            logger = StructuredLogger(tenant_id, request_id)
            logger.error(
                'Validation error',
                error_type='ValueError',
                error_message=str(e),
                stack_trace=traceback.format_exc()
            )
            
            # Add error annotations to X-Ray trace for filtering
            try:
                xray_recorder.put_annotation('error', 'ValidationError')
                xray_recorder.put_annotation('error_status_code', 400)
            except Exception:
                pass
            
            # Add detailed error metadata to X-Ray trace
            try:
                xray_recorder.put_metadata('error_details', {
                    'type': 'ValueError',
                    'message': str(e),
                    'stack_trace': traceback.format_exc(),
                    'tenant_id': tenant_id,
                    'request_id': request_id,
                    'timestamp': datetime.utcnow().isoformat() + 'Z'
                })
            except Exception:
                pass
            
            return LambdaResponse.error(
                'BadRequest',
                str(e),
                tenant_id,
                request_id,
                400
            )
            
        except KeyError as e:
            # Not found errors (404)
            logger = StructuredLogger(tenant_id, request_id)
            logger.error(
                'Resource not found',
                error_type='KeyError',
                error_message=str(e),
                stack_trace=traceback.format_exc()
            )
            
            # Add error annotations to X-Ray trace for filtering
            try:
                xray_recorder.put_annotation('error', 'NotFound')
                xray_recorder.put_annotation('error_status_code', 404)
            except Exception:
                pass
            
            # Add detailed error metadata to X-Ray trace
            try:
                xray_recorder.put_metadata('error_details', {
                    'type': 'KeyError',
                    'message': str(e),
                    'stack_trace': traceback.format_exc(),
                    'tenant_id': tenant_id,
                    'request_id': request_id,
                    'timestamp': datetime.utcnow().isoformat() + 'Z'
                })
            except Exception:
                pass
            
            return LambdaResponse.error(
                'NotFound',
                'Resource not found',
                tenant_id,
                request_id,
                404
            )
            
        except Exception as e:
            # Internal server errors (500)
            logger = StructuredLogger(tenant_id, request_id)
            logger.error(
                'Internal server error',
                error_type=type(e).__name__,
                error_message=str(e),
                stack_trace=traceback.format_exc()
            )
            
            # Add error annotations to X-Ray trace for filtering
            try:
                xray_recorder.put_annotation('error', 'InternalServerError')
                xray_recorder.put_annotation('error_status_code', 500)
            except Exception:
                pass
            
            # Add detailed error metadata to X-Ray trace
            try:
                xray_recorder.put_metadata('error_details', {
                    'type': type(e).__name__,
                    'message': str(e),
                    'stack_trace': traceback.format_exc(),
                    'tenant_id': tenant_id,
                    'request_id': request_id,
                    'timestamp': datetime.utcnow().isoformat() + 'Z'
                })
            except Exception:
                pass
            
            return LambdaResponse.error(
                'InternalServerError',
                'An error occurred processing your request',
                tenant_id,
                request_id,
                500
            )
    
    return wrapper
