"""
Catalog API Lambda Function

Handles product catalog operations with tenant isolation:
- GET /catalog - List all products for a tenant
- GET /catalog/{productId} - Get specific product details

Requirements: 5.1, 5.3, 5.4, 2.4
"""

import json
import os
import sys
from typing import Dict, Any, List

# Add shared layer to path
sys.path.insert(0, '/opt/python')

import boto3
from lambda_base import lambda_handler_wrapper, StructuredLogger, verify_tenant_access

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'api-gateway-demo')
table = dynamodb.Table(table_name)


def get_all_products(tenant_id: str, logger: StructuredLogger) -> List[Dict[str, Any]]:
    """
    Retrieve all products for a tenant.
    
    Args:
        tenant_id: Tenant identifier
        logger: Structured logger instance
        
    Returns:
        List of product dictionaries
        
    Requirements: 5.1, 2.4
    """
    logger.debug(f'Querying all products for tenant: {tenant_id}')
    
    try:
        # Query DynamoDB with tenant-specific partition key
        response = table.query(
            KeyConditionExpression='PK = :pk',
            ExpressionAttributeValues={
                ':pk': f'TENANT#{tenant_id}#PRODUCT'
            }
        )
        
        products = response.get('Items', [])
        logger.info(f'Retrieved {len(products)} products for tenant {tenant_id}')
        
        # Transform DynamoDB items to API response format
        return [transform_product(item) for item in products]
        
    except Exception as e:
        logger.error(f'Failed to query products: {str(e)}')
        raise


def get_product(tenant_id: str, product_id: str, logger: StructuredLogger) -> Dict[str, Any]:
    """
    Retrieve a specific product for a tenant.
    
    Args:
        tenant_id: Tenant identifier
        product_id: Product identifier
        logger: Structured logger instance
        
    Returns:
        Product dictionary
        
    Raises:
        ValueError: If product is not found
        
    Requirements: 5.3, 5.4, 2.4, 2.5
    """
    # Validate product_id
    if not product_id or not isinstance(product_id, str):
        raise ValueError('Invalid product ID format')
    
    logger.debug(f'Querying product {product_id} for tenant: {tenant_id}')
    
    try:
        # Get item from DynamoDB with tenant isolation
        response = table.get_item(
            Key={
                'PK': f'TENANT#{tenant_id}#PRODUCT',
                'SK': f'PRODUCT#{product_id}'
            }
        )
        
        if 'Item' not in response:
            logger.warning(f'Product {product_id} not found for tenant {tenant_id}')
            raise ValueError(f'Product {product_id} not found')
        
        item = response['Item']
        
        # Verify tenant isolation - ensure the data's tenant matches JWT tenant
        data_tenant_id = item.get('tenantId', '')
        verify_tenant_access(tenant_id, data_tenant_id, 'product', product_id, logger)
        
        logger.info(f'Retrieved product {product_id} for tenant {tenant_id}')
        return transform_product(item)
        
    except ValueError:
        # Re-raise validation errors
        raise
    except Exception as e:
        logger.error(f'Failed to get product: {str(e)}')
        raise


def transform_product(item: Dict[str, Any]) -> Dict[str, Any]:
    """
    Transform DynamoDB item to API response format.
    
    Args:
        item: DynamoDB item
        
    Returns:
        Transformed product dictionary
    """
    return {
        'productId': item.get('productId'),
        'name': item.get('name'),
        'description': item.get('description'),
        'price': item.get('price'),
        'currency': item.get('currency', 'USD'),
        'category': item.get('category'),
        'inStock': item.get('inStock', True),
        'createdAt': item.get('createdAt'),
        'updatedAt': item.get('updatedAt')
    }


@lambda_handler_wrapper
def lambda_handler(
    event: Dict[str, Any],
    context: Any,
    tenant_id: str,
    request_id: str,
    logger: StructuredLogger
) -> Dict[str, Any]:
    """
    Main Lambda handler for Catalog API.
    
    Handles:
    - GET /catalog - List all products
    - GET /catalog/{productId} - Get specific product
    
    Args:
        event: Lambda event object
        context: Lambda context object
        tenant_id: Tenant ID from authorizer context
        request_id: Request identifier
        logger: Structured logger instance
        
    Returns:
        Product data (wrapped by decorator)
        
    Requirements: 5.1, 5.3, 5.4, 2.4
    """
    http_method = event.get('httpMethod', 'GET')
    path_parameters = event.get('pathParameters') or {}
    
    logger.debug(f'Processing {http_method} request', path_parameters=path_parameters)
    
    # Handle GET /catalog - List all products
    if http_method == 'GET' and not path_parameters.get('productId'):
        products = get_all_products(tenant_id, logger)
        return {
            'products': products,
            'count': len(products)
        }
    
    # Handle GET /catalog/{productId} - Get specific product
    elif http_method == 'GET' and path_parameters.get('productId'):
        product_id = path_parameters['productId']
        product = get_product(tenant_id, product_id, logger)
        return product
    
    # Unsupported method
    else:
        raise ValueError(f'Unsupported HTTP method: {http_method}')
