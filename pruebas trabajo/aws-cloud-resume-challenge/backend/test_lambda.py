import unittest
import boto3
from moto import mock_aws
from lambda_function import lambda_handler

class TestResumeCounter(unittest.TestCase):
    @mock_aws
    def test_lambda_handler_increments(self):
        # 1. Setup Mock DynamoDB
        dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
        table = dynamodb.create_table(
            TableName='cloud-resume-counter',
            KeySchema=[{'AttributeName': 'id', 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': 'id', 'AttributeType': 'S'}],
            BillingMode='PAY_PER_REQUEST'
        )
        table.put_item(Item={'id': 'view-count', 'count': 10})

        # 2. Invoke Handler
        event = {}
        response = lambda_handler(event, {})

        # 3. Assert Results
        self.assertEqual(response['statusCode'], 200)
        
        # Verify increment
        updated_item = table.get_item(Key={'id': 'view-count'})['Item']
        self.assertEqual(updated_item['count'], 11)

if __name__ == '__main__':
    unittest.main()
