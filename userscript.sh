#!/bin/bash
set -e  #laesst das Skript sofort abbrechen, wenn ein Befehl fehlschlaegt

APP_USER="ec2-user"
APP_HOME="/home/ec2-user"
APP_NAME="iiw_cpc_flask_photo_album"
APP_DIR="$APP_HOME/$APP_NAME"

REPO_URL_BASE="gitlab.rz.htw-berlin.de/s0588307/iiw_cpc_flask_photo_album.git"
SECRET_ID="gitlab-pat"
REGION="us-east-1"

yum install -y git python3.12 python3.12-pip gcc python3.12-devel mariadb105-devel #gcc wird für den C-Compiler benötigt weil ein paar Paketteile in C sind

#holt den PAT fuer die git-authentifizierung
PAT=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --query SecretString \
  --output text \
  --region "$REGION")

cd "$APP_HOME"

git clone "https://oauth2:${PAT}@${REPO_URL_BASE}" "$APP_DIR"

#Uberschreibt die im .git/config gespeicherte URL mit dem PAT auf eine default URL ohne den PAT
git -C "$APP_DIR" remote set-url origin "https://${REPO_URL_BASE}" 

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

cd "$APP_DIR"

sudo curl -o global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

chown "$APP_USER:$APP_USER" "$APP_DIR/.global-bundle.pem"
chmod 600 "$APP_DIR/.global-bundle.pem"

cat > "$APP_DIR/.env" << EOF
S3_WEBSITE_URL=http://flask-photo-album.s3-website-us-east-1.amazonaws.com
S3_BUCKET_NAME=flask-photo-album
AWS_REGION=$REGION

DB_PRIMARY_HOST=dbphotoalb-1.cmx7c7xfbwkw.us-east-1.rds.amazonaws.com
DB_REPLICA_HOST=dbphotoalb-1-replica.cmx7c7xfbwkw.us-east-1.rds.amazonaws.com
DB_PORT=3306
DB_NAME=photoalbum
DB_SSL_CA=./global-bundle.pem
EOF

chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
chmod 600 "$APP_DIR/.env"

sudo -u "$APP_USER" python3.12 -m venv venv

sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip

#prueft ob die Datei requirements.txt ueberhaupt existiert
if [ -f requirements.txt ]; then 
    sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install -r requirements.txt
fi

sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install gunicorn

#Erstellung der systemd Unit-Datei, hier wurden auch die nötigen Umgebungsvariablen gesetzt
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
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 0.0.0.0:8000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable photoapp
systemctl start photoapp