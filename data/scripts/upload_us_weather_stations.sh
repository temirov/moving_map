#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Load environment variables from the .env file using Docker's --env-file
ENV_FILE="../../.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

# Define variables
DATA_FOLDER=$(realpath "../src")  # Absolute path to data folder
STATIONS_FILE="$DATA_FOLDER/ghcnd-stations.txt"
CSV_FILE="$DATA_FOLDER/ghcnd-stations.csv"
DOCKER_IMAGE="postgis:utils"
PYTHON_DOCKER_IMAGE="python:3.9-alpine"  # Use the official Python Docker image
TABLE_NAME=weather_stations

# Determine the host machine's IP address
host_ip=$(hostname -I | awk '{print $1}')

# Function to execute SQL commands
execute_sql() {
    local sql_command="$1"
    docker run --rm \
        --env-file "$ENV_FILE" \
        -e SQL_COMMAND="$sql_command" \
        -e host_ip=$host_ip \
        $DOCKER_IMAGE \
        sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -h $host_ip -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c "$SQL_COMMAND"'
}

# SQL statements stored as variables
CREATE_TABLE_SQL="
CREATE TABLE IF NOT EXISTS $TABLE_NAME (
    station_id VARCHAR(11) PRIMARY KEY,
    latitude FLOAT,
    longitude FLOAT,
    elevation FLOAT,
    state VARCHAR(2),
    location_description VARCHAR(100),
    distance FLOAT,
    direction VARCHAR(3),
    geom GEOMETRY(Point, 4326)
);
"

CREATE_INDEX_SQL="
CREATE INDEX IF NOT EXISTS idx_weather_stations_geom ON $TABLE_NAME USING GIST (geom);
"

UPDATE_GEOM_SQL="
UPDATE $TABLE_NAME SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326) WHERE geom IS NULL;
"

# Check if stations file exists
if [ ! -f "$STATIONS_FILE" ]; then
    echo "Error: Stations file '$STATIONS_FILE' does not exist."
    exit 1
fi

# Step 1: Create Main Table if it doesn't exist
echo "Creating main table if not exists..."
execute_sql "$CREATE_TABLE_SQL"
echo "Main table 'weather_stations' is ready."

# Step 1a: Create Index on geom column
echo "Creating index on geom column..."
execute_sql "$CREATE_INDEX_SQL"
echo "Index 'idx_weather_stations_geom' is ready."

# Step 2: Run the Python script inside Docker to parse the stations file
echo "Running Python script inside Docker to parse the stations file..."
docker run --rm \
    -v "$DATA_FOLDER":/data \
    -v "$(pwd)/parse_stations.py":/parse_stations.py \
    $PYTHON_DOCKER_IMAGE \
    sh -c 'python /parse_stations.py /data/ghcnd-stations.txt /data/ghcnd-stations.csv'
echo "CSV file generated at '$CSV_FILE'."

# Step 3: Load data into the database using COPY
echo "Loading data into the database..."
docker run --rm \
    --env-file "$ENV_FILE" \
    -e host_ip="$host_ip" \
    -e TABLE_NAME=$TABLE_NAME \
    -v "$DATA_FOLDER":/data \
    $DOCKER_IMAGE \
    sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -h $host_ip -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c "\copy $TABLE_NAME (station_id, latitude, longitude, elevation, state, location_description, distance, direction) FROM /data/ghcnd-stations.csv WITH (FORMAT csv)"'
echo "Data loaded into the database."

# Step 4: Update the geom column
echo "Updating geom column..."
execute_sql "$UPDATE_GEOM_SQL"
echo "Geom column updated."

echo "All steps completed successfully."
echo "-------------------------------------------"
