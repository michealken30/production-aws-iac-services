#!/bin/bash
# EC2 User Data Script - Sets up a simple HTTP server

set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user data script execution..."

# Update system
yum update -y

# Install dependencies
yum install -y python3 curl jq

# Create a simple HTTP server application
cat > /home/ec2-user/app.py <<'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import socket
import datetime
import os

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            health_status = {
                'status': 'healthy',
                'timestamp': str(datetime.datetime.now()),
                'hostname': socket.gethostname(),
                'instance_id': os.getenv('INSTANCE_ID', 'unknown'),
                'version': '1.0.0'
            }
            
            self.wfile.write(json.dumps(health_status).encode())
        
        elif self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            html = f"""
            <html>
                <head><title>EC2 HTTP Server</title></head>
                <body>
                    <h1>Hello from EC2!</h1>
                    <p>Hostname: {socket.gethostname()}</p>
                    <p>Instance ID: {os.getenv('INSTANCE_ID', 'unknown')}</p>
                    <p>Time: {datetime.datetime.now()}</p>
                    <p><a href="/health">Health Check</a></p>
                </body>
            </html>
            """
            self.wfile.write(html.encode())
        
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'404 Not Found')
    
    def log_message(self, format, *args):
        # Suppress log messages
        pass

def run_server():
    port = 80
    server_address = ('', port)
    httpd = HTTPServer(server_address, HealthHandler)
    print(f'Starting HTTP server on port {port}...')
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()
EOF

# Get instance ID from metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Set environment variable
echo "export INSTANCE_ID=$INSTANCE_ID" >> /etc/environment

# Make the script executable
chmod +x /home/ec2-user/app.py

# Create systemd service
# NOTE: Running as root to allow binding to privileged port 80
cat > /etc/systemd/system/http-server.service <<EOF
[Unit]
Description=Simple HTTP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ec2-user
Environment=INSTANCE_ID=$INSTANCE_ID
ExecStart=/usr/bin/python3 /home/ec2-user/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Install and configure CloudWatch agent
yum install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/ec2/http-server",
            "log_stream_name": "{instance_id}/messages",
            "timestamp_format": "%b %d %H:%M:%S"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/ec2/http-server",
            "log_stream_name": "{instance_id}/user-data",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json -s

# Enable and start the HTTP server
systemctl daemon-reload
systemctl enable http-server
systemctl start http-server

# Verify service is running
systemctl status http-server --no-pager

echo "User data script completed successfully"