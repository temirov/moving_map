#!/bin/bash

# Variables
CERT_FILE="certs/cert.pem"
KEY_FILE="certs/key.pem"
PORT=4443

# Check if directory is passed as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

DIRECTORY=$1
mkdir certs

# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout $KEY_FILE -out $CERT_FILE -days 1 -nodes -subj "/CN=localhost"

# Run the Python HTTPS server and pass the directory and cert files
python3 serve_https.py "$DIRECTORY" "$CERT_FILE" "$KEY_FILE"

# Cleanup generated certificate and key after serving
rm -f $CERT_FILE $KEY_FILE
