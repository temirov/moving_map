#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Load environment variables from the .env file
ENV_FILE="../../.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

# Define variables
DATA_FOLDER=$(realpath ..)  # Absolute path to data folder
ZIP_XLS_FILE="../src/ZIP_Locale_Detail.xls"
ZIP_CSV_FILE="/tmp/us_zip_codes.csv"
PYTHON_SCRIPT="convert_xls_to_csv.py"
DOCKER_IMAGE="postgis:utils"
PYTHON_DOCKER_IMAGE="python:3.9-alpine"  # Use the official Python Docker image
TABLE_NAME=us_zip_codes_data

# Determine the host machine's IP address
host_ip=$(hostname -I | awk '{print $1}')

# Function to execute SQL commands
execute_sql() {
    local sql_command="$1"
    docker run --rm \
        --env-file "$ENV_FILE" \
        -e SQL_COMMAND="$sql_command" \
        -e host_ip="$host_ip" \
        $DOCKER_IMAGE \
        sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -h $host_ip -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c "$SQL_COMMAND"'
}

# SQL statements stored as variables
CREATE_TABLE_SQL="
CREATE TABLE IF NOT EXISTS $TABLE_NAME (
    id SERIAL PRIMARY KEY,
    area_name VARCHAR(100),
    area_code VARCHAR(10),
    district_name VARCHAR(100),
    district_no VARCHAR(10),
    delivery_zipcode VARCHAR(10),
    locale_name VARCHAR(100),
    physical_delv_addr VARCHAR(200),
    physical_city VARCHAR(100),
    physical_state VARCHAR(2),
    physical_zip VARCHAR(10),
    physical_zip4 VARCHAR(10)
);
"

# Check if XLS file exists
if [ ! -f "$ZIP_XLS_FILE" ]; then
    echo "Error: XLS file '$ZIP_XLS_FILE' does not exist."
    exit 1
fi

# Step 1: Convert XLS to CSV using Python script inside Docker
echo "Converting XLS to CSV..."
docker run --rm \
    -v "$(pwd)/$PYTHON_SCRIPT":/scripts/convert_xls_to_csv.py \
    -v "$DATA_FOLDER":/data \
    $PYTHON_DOCKER_IMAGE \
    sh -c "pip install pandas openpyxl xlrd && python /scripts/convert_xls_to_csv.py /data/src/ZIP_Locale_Detail.xls /data/us_zip_codes.csv"
echo "CSV file generated at '$ZIP_CSV_FILE'."


# Step 2: Drop ZIP Codes Table if it exist
echo "Creating table '$TABLE_NAME' if not exists..."
execute_sql "DROP TABLE IF EXISTS $TABLE_NAME"
echo "Table '$TABLE_NAME' is dropped."

# Step 2a: Create ZIP Codes Table if it doesn't exist
echo "Creating table '$TABLE_NAME' if not exists..."
execute_sql "$CREATE_TABLE_SQL"
echo "Table '$TABLE_NAME' is ready."

# Step 3: Load data into the database using COPY
echo "Loading data into the database..."
docker run --rm \
    --env-file "$ENV_FILE" \
    -e host_ip="$host_ip" \
    -e TABLE_NAME="$TABLE_NAME" \
    -v "$DATA_FOLDER":/data \
    $DOCKER_IMAGE \
    sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -h $host_ip -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c "\copy $TABLE_NAME (area_name, area_code, district_name, district_no, delivery_zipcode, locale_name, physical_delv_addr, physical_city, physical_state, physical_zip, physical_zip4) FROM '/data/us_zip_codes.csv' WITH (FORMAT csv, HEADER true)"'
echo "Data loaded into the database."

echo "All steps completed successfully."
echo "-------------------------------------------"
