#!/usr/bin/env python3
"""
DynamoDB Seed Script for AWS API Gateway Demo

This script seeds the DynamoDB table with sample products and orders
for multiple tenants, demonstrating proper tenant isolation.

Usage:
    python seed_dynamodb.py --table-name <table-name> --region <region>
    python seed_dynamodb.py --table-name api-gateway-demo --region us-east-1
"""

import argparse
import boto3
import json
import sys
from datetime import datetime, timedelta
from decimal import Decimal
import uuid


class DynamoDBSeeder:
    """Seeds DynamoDB with sample multi-tenant data"""
    
    def __init__(self, table_name, region='us-east-1'):
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table = self.dynamodb.Table(table_name)
        self.table_name = table_name
        self.region = region
        
    def seed_all(self, tenants):
        """Seed data for all tenants"""
        print(f"Starting data seeding for table: {self.table_name}")
        print(f"Region: {self.region}")
        print(f"Tenants: {', '.join(tenants)}")
        print("-" * 60)
        
        total_items = 0
        
        for tenant_id in tenants:
            print(f"\nSeeding data for tenant: {tenant_id}")
            products_count = self.seed_products(tenant_id)
            orders_count = self.seed_orders(tenant_id)
            
            tenant_total = products_count + orders_count
            total_items += tenant_total
            print(f"  ✓ Created {products_count} products and {orders_count} orders")
        
        print("\n" + "=" * 60)
        print(f"✓ Seeding complete! Total items created: {total_items}")
        print("=" * 60)
        
        return total_items
    
    def seed_products(self, tenant_id):
        """Seed sample products for a tenant"""
        products = self._generate_products(tenant_id)
        
        for product in products:
            self.table.put_item(Item=product)
        
        return len(products)
    
    def seed_orders(self, tenant_id):
        """Seed sample orders for a tenant"""
        # Get products for this tenant to create valid orders
        products = self._generate_products(tenant_id)
        orders = self._generate_orders(tenant_id, products)
        
        for order in orders:
            self.table.put_item(Item=order)
        
        return len(orders)
    
    def _generate_products(self, tenant_id):
        """Generate sample product data for a tenant"""
        timestamp = datetime.utcnow().isoformat() + 'Z'
        
        products = [
            {
                'PK': f'TENANT#{tenant_id}#PRODUCT',
                'SK': 'PRODUCT#prod-001',
                'tenantId': tenant_id,
                'entityType': 'PRODUCT',
                'productId': 'prod-001',
                'name': 'Widget Pro',
                'description': 'Professional grade widget with advanced features',
                'price': Decimal('99.99'),
                'currency': 'USD',
                'category': 'Electronics',
                'inStock': True,
                'stockQuantity': 150,
                'createdAt': timestamp,
                'updatedAt': timestamp
            },
            {
                'PK': f'TENANT#{tenant_id}#PRODUCT',
                'SK': 'PRODUCT#prod-002',
                'tenantId': tenant_id,
                'entityType': 'PRODUCT',
                'productId': 'prod-002',
                'name': 'Gadget Plus',
                'description': 'Enhanced gadget for everyday use',
                'price': Decimal('49.99'),
                'currency': 'USD',
                'category': 'Electronics',
                'inStock': True,
                'stockQuantity': 200,
                'createdAt': timestamp,
                'updatedAt': timestamp
            },
            {
                'PK': f'TENANT#{tenant_id}#PRODUCT',
                'SK': 'PRODUCT#prod-003',
                'tenantId': tenant_id,
                'entityType': 'PRODUCT',
                'productId': 'prod-003',
                'name': 'Device Ultra',
                'description': 'Ultra-modern device with cutting-edge technology',
                'price': Decimal('199.99'),
                'currency': 'USD',
                'category': 'Electronics',
                'inStock': True,
                'stockQuantity': 75,
                'createdAt': timestamp,
                'updatedAt': timestamp
            },
            {
                'PK': f'TENANT#{tenant_id}#PRODUCT',
                'SK': 'PRODUCT#prod-004',
                'tenantId': tenant_id,
                'entityType': 'PRODUCT',
                'productId': 'prod-004',
                'name': 'Tool Master',
                'description': 'Master tool for professionals',
                'price': Decimal('149.99'),
                'currency': 'USD',
                'category': 'Tools',
                'inStock': True,
                'stockQuantity': 100,
                'createdAt': timestamp,
                'updatedAt': timestamp
            },
            {
                'PK': f'TENANT#{tenant_id}#PRODUCT',
                'SK': 'PRODUCT#prod-005',
                'tenantId': tenant_id,
                'entityType': 'PRODUCT',
                'productId': 'prod-005',
                'name': 'Accessory Kit',
                'description': 'Complete accessory kit with all essentials',
                'price': Decimal('29.99'),
                'currency': 'USD',
                'category': 'Accessories',
                'inStock': False,
                'stockQuantity': 0,
                'createdAt': timestamp,
                'updatedAt': timestamp
            }
        ]
        
        return products
    
    def _generate_orders(self, tenant_id, products):
        """Generate sample order data for a tenant"""
        base_time = datetime.utcnow()
        
        orders = []
        
        # Create 3 sample orders with different statuses
        order_configs = [
            {
                'product_idx': 0,  # Widget Pro
                'quantity': 2,
                'status': 'PENDING',
                'customer_id': 'cust-001',
                'days_ago': 0
            },
            {
                'product_idx': 1,  # Gadget Plus
                'quantity': 5,
                'status': 'CONFIRMED',
                'customer_id': 'cust-002',
                'days_ago': 1
            },
            {
                'product_idx': 2,  # Device Ultra
                'quantity': 1,
                'status': 'SHIPPED',
                'customer_id': 'cust-001',
                'days_ago': 3
            }
        ]
        
        for idx, config in enumerate(order_configs, start=1):
            product = products[config['product_idx']]
            order_id = f'order-{str(uuid.uuid4())[:8]}'
            created_at = (base_time - timedelta(days=config['days_ago'])).isoformat() + 'Z'
            
            order = {
                'PK': f'TENANT#{tenant_id}#ORDER',
                'SK': f'ORDER#{order_id}',
                'tenantId': tenant_id,
                'entityType': 'ORDER',
                'orderId': order_id,
                'customerId': config['customer_id'],
                'productId': product['productId'],
                'productName': product['name'],
                'quantity': config['quantity'],
                'unitPrice': product['price'],
                'totalPrice': product['price'] * config['quantity'],
                'currency': 'USD',
                'status': config['status'],
                'createdAt': created_at,
                'updatedAt': created_at
            }
            
            orders.append(order)
        
        return orders
    
    def clear_tenant_data(self, tenant_id):
        """Clear all data for a specific tenant (useful for re-seeding)"""
        print(f"Clearing data for tenant: {tenant_id}")
        
        # Query all items for this tenant
        items_deleted = 0
        
        # Clear products
        response = self.table.query(
            KeyConditionExpression='PK = :pk',
            ExpressionAttributeValues={':pk': f'TENANT#{tenant_id}#PRODUCT'}
        )
        
        for item in response.get('Items', []):
            self.table.delete_item(Key={'PK': item['PK'], 'SK': item['SK']})
            items_deleted += 1
        
        # Clear orders
        response = self.table.query(
            KeyConditionExpression='PK = :pk',
            ExpressionAttributeValues={':pk': f'TENANT#{tenant_id}#ORDER'}
        )
        
        for item in response.get('Items', []):
            self.table.delete_item(Key={'PK': item['PK'], 'SK': item['SK']})
            items_deleted += 1
        
        print(f"  ✓ Deleted {items_deleted} items")
        return items_deleted


def main():
    parser = argparse.ArgumentParser(
        description='Seed DynamoDB table with sample multi-tenant data'
    )
    parser.add_argument(
        '--table-name',
        required=True,
        help='DynamoDB table name'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region (default: us-east-1)'
    )
    parser.add_argument(
        '--tenants',
        nargs='+',
        default=['tenant-basic-001', 'tenant-standard-001', 'tenant-premium-001'],
        help='List of tenant IDs to seed (default: tenant-basic-001 tenant-standard-001 tenant-premium-001)'
    )
    parser.add_argument(
        '--clear',
        action='store_true',
        help='Clear existing data before seeding'
    )
    
    args = parser.parse_args()
    
    try:
        seeder = DynamoDBSeeder(args.table_name, args.region)
        
        # Clear existing data if requested
        if args.clear:
            print("Clearing existing data...")
            for tenant_id in args.tenants:
                seeder.clear_tenant_data(tenant_id)
            print()
        
        # Seed data
        total_items = seeder.seed_all(args.tenants)
        
        return 0
        
    except Exception as e:
        print(f"\n✗ Error: {str(e)}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
