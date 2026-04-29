import boto3
import json

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-stats')

def lambda_handler(event, context):
    """
    Increments the visitor count in DynamoDB and returns the updated count.
    """
    try:
        # Update the visitor count
        response = table.update_item(
            Key={'id': '0'},
            UpdateExpression='ADD visitors :inc',
            ExpressionAttributeValues={':inc': 1},
            ReturnValues='ALL_NEW'
        )
        
        visitor_count = response['Attributes']['visitors']
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'visitors': int(visitor_count)
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
