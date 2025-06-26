# app.py
from flask import Flask, jsonify
import os
import psycopg2
import json  # For parsing secret string
import boto3  # For AWS SDK (to get secret)

app = Flask(__name__)

# --- Database Setup (Function to connect to DB) ---
def get_db_connection():
    # Use Boto3 Secrets Manager client
    secrets_client = boto3.client('secretsmanager', region_name=os.environ.get('AWS_REGION'))

    try:
        # Retrieve the secret from Secrets Manager
        secret_name = os.environ.get('DB_SECRET_NAME')  # This ENV var will be set in ECS Task Definition
        get_secret_value_response = secrets_client.get_secret_value(SecretId=secret_name)

        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
            db_credentials = json.loads(secret)  # Parse the JSON secret string
        else:
            # For binary secret, decode it
            # secret = base64.b64decode(get_secret_value_response['SecretBinary'])
            # db_credentials = json.loads(secret.decode('utf-8'))
            raise Exception("Binary secrets not supported in this example.")

        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=db_credentials['host'],
            database=db_credentials['dbname'],
            user=db_credentials['username'],
            password=db_credentials['password'],
            port=db_credentials['port']
        )
        return conn

    except Exception as e:
        print(f"Error connecting to database or retrieving secret: {e}")
        return None

# --- Flask Routes ---
@app.route('/')
def hello_world():
    return 'Hello, DevOps World from a Flask App with a Database!'

@app.route('/db_test')
def db_test():
    conn = get_db_connection()
    if conn is None:
        return jsonify({"status": "error", "message": "Could not connect to database"}), 500

    try:
        cur = conn.cursor()
        cur.execute("SELECT 1")  # A simple query to test connection
        result = cur.fetchone()
        cur.close()
        conn.close()
        return jsonify({"status": "success", "message": "Successfully connected to database", "result": result}), 200
    except Exception as e:
        print(f"Database query error: {e}")
        return jsonify({"status": "error", "message": f"Database query failed: {e}"}), 500
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    # Ensure environment variables are set for local testing
    # For local testing: export DB_SECRET_NAME="my-flask-app/rds-credentials"
    # Note: Local testing with Secrets Manager requires AWS credentials configured locally.
    app.run(debug=True, host='0.0.0.0', port=5000)
