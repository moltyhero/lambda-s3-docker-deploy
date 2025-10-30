import json
import boto3

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # Get parameters from query string
    params = event.get('queryStringParameters', {})
    bucket_name = params.get('bucket')
    file_key = params.get('file_key')
    
    if not bucket_name:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'bucket parameter is required'})
        }
    
    if not file_key:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'file_key parameter is required'})
        }

    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
        file_content = response['Body'].read().decode('utf-8')
        
        return {
            'statusCode': 200,
            'body': json.dumps(file_content)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(str(e))
        }
