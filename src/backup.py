import psycopg2
import base64
import boto3
import json
import os


def get_tables(connection):
    cursor = connection.cursor()
    cursor.execute("""SELECT table_name FROM information_schema.tables
            WHERE table_schema = 'public'""")
    for table in cursor.fetchall():
        yield table


def get_secrets():

    secret_name = os.environ.get("PG_CREDS_SECRET", "dev/postgres/creds")
    region_name = os.environ.get("AWS_REGION", "us-east-1")

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name="secretsmanager", region_name=region_name)

    # In this sample we only handle the specific exceptions for the 'GetSecretValue' API.
    # See https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
    # We rethrow the exception by default.

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name)
    except Exception as e:
        if e.response["Error"]["Code"] == "DecryptionFailureException":
            # Secrets Manager can't decrypt the protected secret text using the provided KMS key.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response["Error"]["Code"] == "InternalServiceErrorException":
            # An error occurred on the server side.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response["Error"]["Code"] == "InvalidParameterException":
            # You provided an invalid value for a parameter.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response["Error"]["Code"] == "InvalidRequestException":
            # You provided a parameter value that is not valid for the current state of the resource.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response["Error"]["Code"] == "ResourceNotFoundException":
            # We can't find the resource that you asked for.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        else:
            raise e
    else:
        # Decrypts secret using the associated KMS CMK.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if "SecretString" in get_secret_value_response:
            secret = get_secret_value_response["SecretString"]
            return json.loads(secret)
        else:
            decoded_binary_secret = base64.b64decode(
                get_secret_value_response["SecretBinary"]
            )
            return decoded_binary_secret


def backup(connection_string, table_to_backup):
    table_formatted = table_to_backup[0]
    assert len(table_formatted) > 1
    s = f"""pg_dump "{connection_string.replace("'","")}" {table_formatted} > {table_formatted}.bak"""
    print(s)
    os.system(s)


def make_connection_string(aws_secrets):
    return f"""host='{aws_secrets["DB_HOSTNAME"]}' dbname='{aws_secrets["DB_NAME"]}' user='{aws_secrets["DB_USER"]}' password='{aws_secrets["DB_PASSWORD"]}' port=5432"""


def start(params=get_secrets()):
    connection_string = make_connection_string(params)
    conn = psycopg2.connect(connection_string)
    for table in get_tables(conn):
        try:
            backup(connection_string, table)
        except Exception as e:
            print(e)


if __name__ == '__main__':
    start()
