#!/bin/bash
apt-get update
apt-get install -y docker.io git curl cron
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
cd /home
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
docker-compose up -d
crontab cron/crontab.txt