#!/bin/bash

# stop if some command fail
set -e

# update the ubuntu
apt-get update -y
apt-get upgrade -y

# install the nodejs 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# install to get secrets
apt-get install -y awscli

# fetch secrets from Secrets Manager ─────────────────────
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

# get this instance's private IP ─────────────────────────
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)


# create work folder
mkdir -p /opt/app
cd /opt/app

# copy app files ─────────────────────────────────────────
# You'll replace this with your actual app source
# For now we create a placeholder env file
cat > /opt/app/.env << EOF
PORT=3000
NODE_ENV=production
DB_INIT_SYNC=false

MYSQL_HOST=${db_host}
MYSQL_PORT=${db_port}
MYSQL_USER=${db_username}
MYSQL_PASSWORD=$DB_PASSWORD
MYSQL_DATABASE=${db_name}

REDIS_URL=${redis_url}
SESSION_SECRET=$SESSION_SECRET

SERVER_IP=$PRIVATE_IP
LOG_LEVEL=verbose
EOF

# install and start app ──────────────────────────────────
npm install --production
npm run build
npm run start:prod &

echo "App started successfully"
