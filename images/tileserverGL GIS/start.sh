#!/bin/bash

# Ensure the script stops if any command fails
set -e

ENV_FILE="../../.env"

docker compose --env-file $ENV_FILE up -d
