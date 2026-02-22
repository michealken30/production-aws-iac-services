#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution..."
# Wait for network
sleep 20
# Update system
yum update -y
# Install nginx via Amazon Linux Extras (correct way for AL2)
amazon-linux-extras install nginx1 -y
# Install Node.js 16 (compatible with glibc 2.26 on Amazon Linux 2)
curl -fsSL https://rpm.nodesource.com/setup_16.x | bash -
yum install -y nodejs git
# Verify versions
node -v
npm -v
nginx -v
# Clone the repo
cd /home/ec2-user
git clone https://github.com/michealken30/spotify-clone.git
cd spotify-clone
# Install dependencies and build
npm install
npm run build
# Copy build output to nginx web root
cp -r dist/* /usr/share/nginx/html/
# Configure nginx
cat > /etc/nginx/conf.d/spotify-clone.conf <<'EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    # Handle React client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }
    # Health check endpoint for ALB
    location /health {
        return 200 '{"status":"healthy"}';
        add_header Content-Type application/json;
    }
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
# Remove default nginx config to avoid conflicts
rm -f /etc/nginx/conf.d/default.conf
# Get instance metadata
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
echo "export INSTANCE_ID=$INSTANCE_ID" >> /etc/environment
# Install CloudWatch agent
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
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/ec2/spotify-clone",
            "log_stream_name": "{instance_id}/nginx-access"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/ec2/spotify-clone",
            "log_stream_name": "{instance_id}/nginx-error"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/ec2/spotify-clone",
            "log_stream_name": "{instance_id}/user-data"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      }
    }
  }
}
EOF
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json -s
# Enable and start nginx
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx
systemctl status nginx --no-pager
echo "User data script completed successfully".   