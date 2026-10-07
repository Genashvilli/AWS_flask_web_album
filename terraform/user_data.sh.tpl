#!/bin/bash
set -e

APP_USER="ec2-user"
APP_HOME="/home/ec2-user"
APP_NAME="iiw_cpc_flask_photo_album"
APP_DIR="$APP_HOME/$APP_NAME"

REPO_URL_BASE="${gitlab_repo_url_base}"
GITLAB_SECRET_ID="${gitlab_pat_secret_id}"
REGION="${aws_region}"

dnf update -y

dnf install -y \
  git \
  python3.12 \
  python3.12-pip \
  gcc \
  python3.12-devel \
  mariadb105-devel \
  awscli

PAT=$(aws secretsmanager get-secret-value \
  --secret-id "$GITLAB_SECRET_ID" \
  --query SecretString \
  --output text \
  --region "$REGION")

cd "$APP_HOME"

if [ ! -d "$APP_DIR" ]; then
  git clone --branch abgabe6 --single-branch "https://oauth2:$${PAT}@$${REPO_URL_BASE}" "$APP_DIR"
fi

git -C "$APP_DIR" remote set-url origin "https://$${REPO_URL_BASE}"

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

cd "$APP_DIR"

curl -o global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

chown "$APP_USER:$APP_USER" "$APP_DIR/global-bundle.pem"
chmod 600 "$APP_DIR/global-bundle.pem"

cat > "$APP_DIR/.env" << EOF
S3_BUCKET_NAME=${s3_bucket_name}
AWS_REGION=${aws_region}

SECRET_ID=${db_secret_id}

DB_PRIMARY_HOST=${db_primary_host}
DB_REPLICA_HOST=${db_replica_host}
DB_PORT=3306
DB_NAME=${db_name}
DB_SSL_CA=./global-bundle.pem
EOF

chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
chmod 600 "$APP_DIR/.env"

sudo -u "$APP_USER" python3.12 -m venv "$APP_DIR/venv"

sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip

if [ -f "$APP_DIR/requirements.txt" ]; then
  sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"
fi

sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install gunicorn

cat > /etc/systemd/system/photoapp.service <<EOF
[Unit]
Description=Gunicorn service for Flask photo album
After=network.target

[Service]
User=ec2-user
Group=ec2-user
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin:/usr/local/bin:/usr/bin"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 0.0.0.0:${app_port} app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable photoapp
systemctl restart photoapp