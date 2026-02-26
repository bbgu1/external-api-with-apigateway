"""
Order API Lambda Function

Handles order operations with tenant isolation:
- POST /orders - Create a new order
- GET /orders - List all orders for a tenant
- GET /orders/{orderId} - Get specific order details

Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 2.4
"""

import json
import os
import sys
import uuid
from datetime import datetime
from typing import Dict, Any

# Add shared layer to path
sys.path.insert(0, '/opt/python')

import boto3
from lambda_base import lambda_handler_wrapper, StructuredLogger, verify_tenant_access

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'api-gateway-demo')
table = dynamodb.Table(table_name)


def validate_order(order_data: Dict[str, Any]) -> None:
    """
    Validate order data for required fields and valid values.
    
    Args:
        order_data: Order data dictionary
        
    Raises:
        ValueError: If validation fails
        
    Requirements: 6.3
    """
    required_fields = ['customerId', 'productId', 'quantity']
    
    # Check for missing required fields
    for field in required_fields:
        if field not in order_data:
            raise ValueError(f'Missing required field: {field}')
    
    # Validate quantity
    quantity = order_data.get('quantity')
    if not isinstance(quantity, int):
        raise ValueError('Quantity must be an integer')
    
    if quantity <= 0:
        raise ValueError('Quantity must be a positive integer')
    
    # Validate customerId and productId are non-empty strings
    if not order_data.get('customerId') or not isinstance(order_data['customerId'], str):
        raise ValueError('Invalid customerId')
    
    if not order_data.get('productId') or not isinstance(order_data['productId'], str):
        raise ValueError('Invalid productId')


def get_product(tenant_id: str, product_id: str, logger: StructuredLogger) -> Dict[str, Any]:
    """
    Retrieve a product to validate it exists and get pricing.
    
    Args:
        tenant_id: Tenant identifier
        product_id: Product identifier
        logger: Structured logger instance
        
    Returns:
        Product dictionary
        
    Raises:
        ValueError: If product is not found
        
    Requirements: 2.5
    """
    logger.debug(f'Fetching product {product_id} for order validation')
    
    try:
        response = table.get_item(
            Key={
                'PK': f'TENANT#{tenant_id}#PRODUCT',
                'SK': f'PRODUCT#{product_id}'
            }
        )
        
        if 'Item' not in response:
            raise ValueError(f'Product {product_id} not found')
        
        item = response['Item']
        
        # Verify tenant isolation - ensure the product belongs to the same tenant
        data_tenant_id = item.get('tenantId', '')
        verify_tenant_access(tenant_id, data_tenant_id, 'product', product_id, logger)
        
        return item
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f'Failed to fetch product: {str(e)}')
        raise


def create_order(
    tenant_id: str,
    order_data: Dict[str, Any],
    logger: StructuredLogger
) -> Dict[str, Any]:
    """
    Create a new order with validation and tenant isolation.
    
    Args:
        tenant_id: Tenant identifier
        order_data: Order data from request
        logger: Structured logger instance
        
    Returns:
        Created order dictionary
        
    Requirements: 6.1, 6.2, 6.3, 6.4, 6.6, 2.4
    """
    # Validate order data
    validate_order(order_data)
    
    # Generate unique order ID
    order_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat() + 'Z'
    
    logger.debug(f'Creating order {order_id} for tenant {tenant_id}')
    
    # Fetch product to validate and get pricing
    product = get_product(tenant_id, order_data['productId'], logger)
    
    # Calculate total price
    total_price = product.get('price', 0) * order_data['quantity']
    
    # Build order item
    order = {
        'PK': f'TENANT#{tenant_id}#ORDER',
        'SK': f'ORDER#{order_id}',
        'tenantId': tenant_id,
        'entityType': 'ORDER',
        'orderId': order_id,
        'customerId': order_data['customerId'],
        'productId': order_data['productId'],
        'quantity': order_data['quantity'],
        'totalPrice': total_price,
        'currency': product.get('currency', 'USD'),
        'status': 'PENDING',
        'createdAt': timestamp,
        'updatedAt': timestamp
    }
    
    try:
        # Store order in DynamoDB
        table.put_item(Item=order)
        logger.info(f'Created order {order_id} for tenant {tenant_id}')
        
        # Return order without internal DynamoDB keys
        return transform_order(order)
        
    except Exception as e:
        logger.error(f'Failed to create order: {str(e)}')
        raise


def get_order(tenant_id: str, order_id: str, logger: StructuredLogger) -> Dict[str, Any]:
    """
    Retrieve a specific order for a tenant.
    
    Args:
        tenant_id: Tenant identifier
        order_id: Order identifier
        logger: Structured logger instance
        
    Returns:
        Order dictionary
        
    Raises:
        ValueError: If order is not found
        
    Requirements: 6.5, 2.4, 2.5
    """
    # Validate order_id
    if not order_id or not isinstance(order_id, str):
        raise ValueError('Invalid order ID format')
    
    logger.debug(f'Querying order {order_id} for tenant: {tenant_id}')
    
    try:
        # Get item from DynamoDB with tenant isolation
        response = table.get_item(
            Key={
                'PK': f'TENANT#{tenant_id}#ORDER',
                'SK': f'ORDER#{order_id}'
            }
        )
        
        if 'Item' not in response:
            logger.warning(f'Order {order_id} not found for tenant {tenant_id}')
            raise ValueError(f'Order {order_id} not found')
        
        item = response['Item']
        
        # Verify tenant isolation - ensure the order belongs to the same tenant
        data_tenant_id = item.get('tenantId', '')
        verify_tenant_access(tenant_id, data_tenant_id, 'order', order_id, logger)
        
        logger.info(f'Retrieved order {order_id} for tenant {tenant_id}')
        return transform_order(item)
        
    except ValueError:
        # Re-raise validation errors
        raise
    except Exception as e:
        logger.error(f'Failed to get order: {str(e)}')
        raise


def transform_order(item: Dict[str, Any]) -> Dict[str, Any]:
    """
    Transform DynamoDB item to API response format.
    
    Args:
        item: DynamoDB item
        
    Returns:
        Transformed order dictionary
    """
    return {
        'orderId': item.get('orderId'),
        'tenantId': item.get('tenantId'),
        'customerId': item.get('customerId'),
        'productId': item.get('productId'),
        'quantity': item.get('quantity'),
        'totalPrice': item.get('totalPrice'),
        'currency': item.get('currency', 'USD'),
        'status': item.get('status'),
        'createdAt': item.get('createdAt'),
        'updatedAt': item.get('updatedAt')
    }

def get_all_orders(tenant_id: str, logger: StructuredLogger) -> list:
    """
    Retrieve all orders for a tenant.

    Args:
        tenant_id: Tenant identifier
        logger: Structured logger instance

    Returns:
        List of order dictionaries
    """
    logger.debug(f'Querying all orders for tenant: {tenant_id}')

    try:
        response = table.query(
            KeyConditionExpression='PK = :pk',
            ExpressionAttributeValues={
                ':pk': f'TENANT#{tenant_id}#ORDER'
            }
        )

        orders = response.get('Items', [])
        logger.info(f'Retrieved {len(orders)} orders for tenant {tenant_id}')

        return [transform_order(item) for item in orders]

    except Exception as e:
        logger.error(f'Failed to query orders: {str(e)}')
        raise



@lambda_handler_wrapper
def lambda_handler(
    event: Dict[str, Any],
    context: Any,
    tenant_id: str,
    request_id: str,
    logger: StructuredLogger
) -> Dict[str, Any]:
    """
    Main Lambda handler for Order API.
    
    Handles:
    - POST /orders - Create a new order
    - GET /orders - List all orders for tenant
    - GET /orders/{orderId} - Get specific order
    
    Args:
        event: Lambda event object
        context: Lambda context object
        tenant_id: Tenant ID from authorizer context
        request_id: Request identifier
        logger: Structured logger instance
        
    Returns:
        Order data (wrapped by decorator)
        
    Requirements: 6.1, 6.4, 6.5, 2.4
    """
    http_method = event.get('httpMethod', 'GET')
    path_parameters = event.get('pathParameters') or {}
    
    logger.debug(f'Processing {http_method} request', path_parameters=path_parameters)
    
    # Handle POST /orders - Create new order
    if http_method == 'POST' and not path_parameters.get('orderId'):
        # Parse request body
        body = event.get('body', '{}')
        if isinstance(body, str):
            try:
                order_data = json.loads(body)
            except json.JSONDecodeError:
                raise ValueError('Invalid JSON in request body')
        else:
            order_data = body
        
        order = create_order(tenant_id, order_data, logger)
        return order
    
    # Handle GET /orders - List all orders
    elif http_method == 'GET' and not path_parameters.get('orderId'):
        orders = get_all_orders(tenant_id, logger)
        return {
            'orders': orders,
            'count': len(orders)
        }
    
    # Handle GET /orders/{orderId} - Get specific order
    elif http_method == 'GET' and path_parameters.get('orderId'):
        order_id = path_parameters['orderId']
        order = get_order(tenant_id, order_id, logger)
        return order
    
    # Unsupported method
    else:
        raise ValueError(f'Unsupported HTTP method: {http_method}')
