import json
import boto3

# Initialize the DynamoDB resource client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-counter')

def lambda_handler(event, context):
    try:
        # Atomic update statement to safely increment counter by 1
        response = table.update_item(
            Key={'id': 'visitors'},
            UpdateExpression='ADD #c :val',
            ExpressionAttributeNames={'#c': 'count'},
            ExpressionAttributeValues={':val': 1},
            ReturnValues='UPDATED_NEW'
        )
        
        # Pull out the new count number value
        new_count = response['Attributes']['count']
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*', # Required for CORS connectivity later
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps({'count': int(new_count)})
        }
        
    except Exception as e:
        print(f"Error updating item: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error tracking visitor metrics.'})
        }