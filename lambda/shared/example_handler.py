"""
Example Lambda handler demonstrating usage of the base handler template.

This example shows how to use the lambda_handler_wrapper decorator
and the common functionality provided by lambda_base.py.
"""

from lambda_base import lambda_handler_wrapper


@lambda_handler_wrapper
def lambda_handler(event, context, tenant_id, request_id, logger):
    """
    Example Lambda handler function.
    
    The wrapper provides:
    - tenant_id: Extracted from JWT claims
    - request_id: Extracted from request context
    - logger: StructuredLogger instance for JSON logging
    
    Args:
        event: Lambda event object
        context: Lambda context object
        tenant_id: Tenant identifier (provided by wrapper)
        request_id: Request identifier (provided by wrapper)
        logger: Structured logger instance (provided by wrapper)
        
    Returns:
        Response data (wrapper will format as proper Lambda response)
    """
    # Log some information
    logger.info('Processing example request')
    
    # Your business logic here
    result = {
        'message': 'Hello from Lambda!',
        'tenant': tenant_id,
        'request': request_id
    }
    
    # Return data (wrapper will format the response)
    return result
