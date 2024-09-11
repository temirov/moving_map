#!/bin/bash

# Ensure the script stops if any command fails
set -e

# Step 1: Create a dedicated folder for unzipped files
UNZIP_DIR=$(realpath "../src/tl_2023_us_state")  # Get the absolute path
ZIP_FILE="../src/tl_2023_us_state.zip"
ENV_FILE="../../.env"
DOCKER_IMAGE="postgis:utils"
host_ip=$(hostname -I | awk '{print $1}')
TABLE_NAME=us_states

# Ensure the unzip directory exists
mkdir -p $UNZIP_DIR

# Unzip the file into the dedicated folder and overwrite existing files
unzip -o $ZIP_FILE -d $UNZIP_DIR

# Step 2: Capture shp2pgsql output
docker run --rm --env-file $ENV_FILE -e TABLE_NAME=$TABLE_NAME -v $UNZIP_DIR:/data $DOCKER_IMAGE \
sh -c '/usr/bin/shp2pgsql -I -s 4326 /data/tl_2023_us_state.shp $TABLE_NAME > /data/shp2pgsql_output.sql'

# Step 3: Import the SQL file into PostGIS using psql
docker run --rm --env-file $ENV_FILE -e HOST_IP=$host_ip -v $UNZIP_DIR:/data $DOCKER_IMAGE \
sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -h $HOST_IP < /data/shp2pgsql_output.sql'

# Step 4: Clean up - delete the unzipped files
rm -rf $UNZIP_DIR

echo "Shapefile imported and unzipped files deleted."
