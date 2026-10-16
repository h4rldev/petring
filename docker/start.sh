#!/bin/sh
set -e
cd /app
mkdir -p /app/data
ln -sf /app/data/petring-config.json /app/petring-config.json
ln -sf /app/data/petring.env /app/petring.env

if [ ! -f /app/data/petring-config.json ]; then
  printf '%s' '{
  "port": 8080,
  "internal_log_level": "info",
  "db_path": "/app/data/petring.db",
  "server_name": "petring",
  "cors_origins": ["*"],
  "cors_credentials": false,
  "url_reachability": false,
  "log_access": true,
  "access_log_file": "/app/data/access.log"
}' > /app/data/petring-config.json
fi

./migrator migrate /app/data/petring.db migrations

exec ./petring
