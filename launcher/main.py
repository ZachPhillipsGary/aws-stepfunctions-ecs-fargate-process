import boto3
import os


def lambda_handler(event, context):
    client = boto3.client('ecs')
    response = client.run_task(
        cluster=os.getenv('CLUSTER'),
        launchType=os.getenv('LAUNCH_TYPE', 'FARGATE'),
        taskDefinition=os.getenv('TASK_DEFINITION'),
        count=int(os.getenv('COUNT', 1)),
        platformVersion='LATEST',
        networkConfiguration={
            'awsvpcConfiguration': {
                'subnets': os.getenv('SUBNETS').split(','),
                'assignPublicIp': os.getenv('ASSIGN_PUBLIC_IP', 'ENABLED'),
                'securityGroups': os.getenv('SECURITY_GROUPS').split(','),
            },
        }
    )
    return str(response)
