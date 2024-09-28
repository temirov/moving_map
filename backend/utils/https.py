import http.server
import ssl

# Choose the handler (this is similar to using `python3 -m http.server`)
handler = http.server.SimpleHTTPRequestHandler

# Create the HTTP server, binding to the IP address of eth1 (192.168.1.100 in this case)
httpd = http.server.HTTPServer(('192.168.1.100', 8084), handler)

# Wrap the HTTP server socket with SSL
httpd.socket = ssl.wrap_socket(httpd.socket, 
                               keyfile="key.pem", 
                               certfile="cert.pem", 
                               server_side=True)

print("Serving on https://192.168.1.100:8084")
httpd.serve_forever()
