#!/bin/bash
BACKUP_DIR="/home/pallavi/app/backup/data"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +"%F_%H-%M")
mongodump --host mongo1 --port 27017 --archive="$BACKUP_DIR/mongo-$TIMESTAMP.archive"
echo "Backup completed at $TIMESTAMP" >> /var/log/backup.log