import http.server
import ssl
import socketserver
import sys
import os

# Check for sufficient arguments
if len(sys.argv) < 4:
    print("Usage: python3 serve_https.py <directory> <cert.pem> <key.pem>")
    sys.exit(1)

DIRECTORY = sys.argv[1]
CERT_FILE = sys.argv[2]
KEY_FILE = sys.argv[3]

# Check if directory exists
if not os.path.isdir(DIRECTORY):
    print(f"Error: {DIRECTORY} is not a valid directory")
    sys.exit(1)

# Check if cert and key files exist
if not os.path.isfile(CERT_FILE) or not os.path.isfile(KEY_FILE):
    print(f"Error: Certificate or key file not found.")
    sys.exit(1)

PORT = 4443

# Define custom request handler
class SimpleHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

# Set up the server
httpd = socketserver.TCPServer(('0.0.0.0', PORT), SimpleHTTPRequestHandler)

# Create an SSL context
ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ssl_context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)

# Wrap the server socket with SSL
httpd.socket = ssl_context.wrap_socket(httpd.socket, server_side=True)

# Start serving files over HTTPS
print(f"Serving directory '{DIRECTORY}' on https://0.0.0.0:{PORT}")
httpd.serve_forever()
