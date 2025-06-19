#!/bin/bash

# Update system
sudo apt-get update -y
sudo apt-get install -y docker.io git curl apache2

# Install Docker Compose
sudo curl -SL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone project
if [ ! -d "/home/gcp-fullstack-template" ]; then
  git clone https://github.com/yourusername/gcp-fullstack-template.git /home/gcp-fullstack-template
fi
cd /home/gcp-fullstack-template

# Add default HTML to keep health check happy
echo "<h1>Booting...</h1>" | sudo tee /var/www/html/index.html
sudo systemctl start apache2

# Fix exporter version
sed -i 's|percona/mongodb_exporter|percona/mongodb_exporter:0.40.0|' docker-compose.yml

# Wait before starting Docker
sleep 20

# Start containers
sudo docker-compose pull
sudo docker-compose up -d

# Wait for MongoDB
sleep 20

# Init replica set (safely skip if already exists)
sudo docker exec mongo1 mongosh --eval 'rs.initiate({_id: "rs0", members: [{_id: 0, host: "mongo1:27017"}, {_id: 1, host: "mongo2:27017"}]})' || true

# Set up cron job
(crontab -l 2>/dev/null; echo "0 3 * * * /home/gcp-fullstack-template/backup/backup.sh >> /var/log/backup.log 2>&1") | crontab -
