#!/bin/bash

echo "🚀 Smart Tech Backend Deploy Script"

# 1) Update server paketa
sudo apt update && sudo apt upgrade -y

# 2) Instaliraj potrebne pakete
sudo apt install -y python3-pip python3-venv python3-dev libmysqlclient-dev mysql-server nginx

# 3) Postavi projekt direktorij
PROJECT_NAME="smarttech_backend"
PROJECT_DIR="/root/$PROJECT_NAME"

# 4) Kreiraj virtualno okruženje
cd $PROJECT_DIR
python3 -m venv venv
source venv/bin/activate

# 5) Instaliraj Python pakete
pip install --upgrade pip
pip install -r requirements.txt

# 6) Pokreni migracije i collectstatic
python manage.py makemigrations
python manage.py migrate
python manage.py collectstatic --noinput

# 7) Kreiraj Gunicorn servis
sudo bash -c "cat > /etc/systemd/system/gunicorn.service" << EOL
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --workers 3 --bind unix:$PROJECT_DIR/gunicorn.sock your_project_name.wsgi:application

[Install]
WantedBy=multi-user.target
EOL

# 8) Pokreni i enable Gunicorn
sudo systemctl daemon-reload
sudo systemctl start gunicorn
sudo systemctl enable gunicorn

# 9) Konfiguriraj NGINX
sudo bash -c "cat > /etc/nginx/sites-available/$PROJECT_NAME" << EOL
server {
    listen 80;
    server_name YOUR_SERVER_IP;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root $PROJECT_DIR;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:$PROJECT_DIR/gunicorn.sock;
    }
}
EOL

sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled
sudo nginx -t
sudo systemctl restart nginx

# 10) Postavi firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "✅ Deploy završen! Posjeti: http://YOUR_SERVER_IP"
