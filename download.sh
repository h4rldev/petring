#!/usr/bin/env bash

NO_JUST=false

if ! command -v git &> /dev/null; then
	echo "git is not installed"
	exit 1
fi

if ! command -v cargo &> /dev/null; then
	echo "cargo is not installed"
	echo "cargo is required to run migrations"
	exit 1
fi

if ! command -v sqlite3 &> /dev/null; then
	echo "sqlite3 is not installed"
	exit 1
fi

if ! command -v just &> /dev/null; then
	echo "just is not installed, trying without it"
	NO_JUST=true
fi

echo "Cloning repo"
git clone https://github.com/h4rldev/petring.git ./buf

echo "Getting relevant files"
mv -t ./ ./buf/migration ./buf/frontend ./buf/petring-api.toml ./buf/petring-web.toml ./buf/docker-compose.yml ./buf/docker-compose.override.yml
mv -t ./.env ./buf/.env.example
if ${NO_JUST} == false; then
	mv ./buf/justfile ./
fi

echo "Removing cloned repo"
rm -fr ./buf

echo "Generating empty database"
sqlite3 petring.db "VACUUM;"

echo "Running migrations"
if ${NO_JUST}; then
	pushd ./migration/ >/dev/null
	mv ../petring.db .
	cargo run --release -- up
	mv petring.db ../
	popd >/dev/null
else
	just migrations up
fi

echo "Petring is now ready to be configured"
echo "Check out the docker-compose files, petring-api.toml and petring-web.toml"
echo "IMPORTANT: Don't forget about your .env file, This script has pre-copied the .env.example file to .env for you."
echo "Cheers!"
exit 0
