#!/usr/bin/env bash

set -euo pipefail

REPO="h4rldev/petring"
REF="${PETRING_REF:-main}"

if ! command -v docker &> /dev/null; then
  echo "docker is not installed"
  exit 1
fi

echo "Downloading docker-compose files"
for file in docker-compose.yml docker-compose.override.yml; do
  curl -fsSL "https://raw.githubusercontent.com/${REPO}/${REF}/${file}" -o "${file}"
done

mkdir -p data

echo "Pulling the petRing image"
docker compose pull

echo "Starting petRing"
docker compose up -d

echo "petRing is now running on http://localhost:8080"
echo "Its database, config and secrets live in ./data"
echo "IMPORTANT: the superadmin defaults to superadmin/superadmin until you first modify the account."
echo "Cheers!"
exit 0
