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
STAGING_TABLE="weather_observations_staging"
MAIN_TABLE="weather_observations"
DOCKER_IMAGE="postgis:utils"

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
CREATE_STAGING_TABLE_SQL="
CREATE UNLOGGED TABLE IF NOT EXISTS $STAGING_TABLE (
    station_id VARCHAR(20),
    observation_date DATE,
    observation_type VARCHAR(10),
    value FLOAT,
    flag VARCHAR(1),
    time_of_observation VARCHAR(4)
);
"

CREATE_MAIN_TABLE_SQL="
CREATE TABLE IF NOT EXISTS $MAIN_TABLE (
    station_id VARCHAR(20),
    observation_date DATE,
    observation_type VARCHAR(10),
    value FLOAT,
    flag VARCHAR(1),
    time_of_observation VARCHAR(4),
    PRIMARY KEY (station_id, observation_date, observation_type)
);
"

UPSERT_SQL="
INSERT INTO $MAIN_TABLE (station_id, observation_date, observation_type, value, flag, time_of_observation)
SELECT station_id, observation_date, observation_type, value, flag, time_of_observation
FROM $STAGING_TABLE
ON CONFLICT (station_id, observation_date, observation_type) 
DO UPDATE SET 
    value = EXCLUDED.value, 
    flag = EXCLUDED.flag,
    time_of_observation = EXCLUDED.time_of_observation
;
"

# Check if data folder exists
if [ ! -d "$DATA_FOLDER" ]; then
    echo "Error: Data folder '$DATA_FOLDER' does not exist."
    exit 1
fi

# Step 1: Create Staging Table if it doesn't exist
echo "Creating staging table if not exists..."
execute_sql "$CREATE_STAGING_TABLE_SQL"
echo "Staging table '$STAGING_TABLE' is ready."

# Step 1a: Truncate staging table for the uploads
echo "Truncating staging table..."
execute_sql "TRUNCATE TABLE $STAGING_TABLE;"
echo "Staging table truncated."

# Step 2: Create Main Table if it doesn't exist
echo "Creating main table if not exists..."
execute_sql "$CREATE_MAIN_TABLE_SQL"
echo "Main table '$MAIN_TABLE' is ready."

# Step 3: Process Each .csv.gz File
for gz_file in "$DATA_FOLDER"/*.csv.gz; do
    # Check if the file exists
    if [ ! -e "$gz_file" ]; then
        echo "No .csv.gz files found in $DATA_FOLDER."
        break
    fi

    echo "Processing file: $gz_file"

    # Step 3a: Load data into staging table using COPY
    echo "Loading data into staging table..."

    docker run --rm \
        --env-file "$ENV_FILE" \
        -e STAGING_TABLE="$STAGING_TABLE" \
        -e gz_file=$gz_file \
        -e host_ip=$host_ip \
        -v "$DATA_FOLDER":/data \
        $DOCKER_IMAGE \
        sh -c 'gunzip -c /data/$(basename "$gz_file") | grep -i "^us" | cut -d',' -f1-6 |  PGPASSWORD=$POSTGRES_PASSWORD psql -h $host_ip -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c "\copy $STAGING_TABLE FROM STDIN WITH (FORMAT csv)"'

    echo "Data loaded into staging table."
    echo "Finished processing file: $gz_file"
   
done
echo "All files have been processed successfully."
echo "-------------------------------------------"

# Step 3b: Perform upsert from staging table to main table
echo "Performing upsert into main table..."
execute_sql "$UPSERT_SQL"
echo "Upsert completed."

# Step 3c: Truncate staging table for next file
echo "Truncating staging table..."
execute_sql "TRUNCATE TABLE $STAGING_TABLE;"
echo "Staging table truncated."
