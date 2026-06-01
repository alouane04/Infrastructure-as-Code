#!/bin/bash
set -e

apt-get update -y
apt-get upgrade -y

# install nodejs 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# install awscli for secrets
apt-get install -y awscli

# fetch secrets
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id ${db_password_secret_name} \
  --region ${aws_region} \
  --query SecretString \
  --output text)

SESSION_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id ${session_secret_name} \
  --region ${aws_region} \
  --query SecretString \
  --output text)

PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# clone repo
git clone https://github.com/alouane04/Infrastructure-as-Code.git /opt/repo
cd /opt/repo/web-app

# write .env in the RIGHT place (next to package.json)
cat > /opt/repo/web-app/.env << EOF
PORT=3000
NODE_ENV=production
DB_INIT_SYNC=false

MYSQL_HOST=${db_host}
MYSQL_PORT=${db_port}
MYSQL_USER=${db_username}
MYSQL_PASSWORD=$DB_PASSWORD
MYSQL_DATABASE=${db_name}

REDIS_HOST=${redis_host}
REDIS_PORT=${redis_port}
SESSION_SECRET=$SESSION_SECRET

SERVER_IP=$PRIVATE_IP
LOG_LEVEL=verbose
EOF

# install ALL deps (need devDeps to build), then build, then prune
npm install --legacy-peer-deps
npm run build
npm prune --omit=dev

# create a systemd service so it survives reboots and can be managed
cat > /etc/systemd/system/iac1-app.service << EOF
[Unit]
Description=IAC1 Web App
After=network.target

[Service]
WorkingDirectory=/opt/repo/web-app
ExecStart=/usr/bin/node dist/main
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/opt/repo/web-app/.env
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable iac1-app
systemctl start iac1-app

echo "App started successfully"