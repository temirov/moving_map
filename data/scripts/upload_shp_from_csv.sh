#!/bin/bash

# Source the shared functions and variables
# Adjust the path to common.sh based on your directory structure
source "$(dirname "$0")/common.sh"

# Define the path to the CSV file
CSV_FILE="input_files.csv"
# Check if the CSV file exists
check_file_exists "$CSV_FILE"

# Read the CSV file line by line, skipping the header
tail -n +2 "$CSV_FILE" | while IFS=, read -r zip_file table_name; do
    echo "Processing ZIP file: $zip_file for table: $table_name"

    # Trim possible whitespace
    zip_file=$(echo "$zip_file" | xargs)
    table_name=$(echo "$table_name" | xargs)

    # Check if the ZIP file exists
    check_file_exists "$zip_file"

    # Extract basename without .zip
    ZIP_BASENAME=$(basename "$zip_file" .zip)
    UNZIP_DIR=$(realpath "../src/$ZIP_BASENAME")

    # Define SQL commands
    DROP_TABLE_SQL="DROP TABLE IF EXISTS $table_name;"
    CREATE_INDEX_SQL="CREATE INDEX idx_${table_name}_geom ON $table_name USING GIST (geom);"

    # Step 1: Create a dedicated folder for unzipped files
    mkdir -p "$UNZIP_DIR"

    # Unzip the file into the dedicated folder and overwrite existing files
    echo "Unzipping $zip_file to $UNZIP_DIR..."
    unzip -o "$zip_file" -d "$UNZIP_DIR"

    # Step 2: Capture shp2pgsql output
    echo "Generating SQL from shapefile..."
    docker run --rm --env-file $ENV_FILE -e TABLE_NAME=$table_name -e SHAPE_FILE_BASE=$ZIP_BASENAME -v $UNZIP_DIR:/data $DOCKER_IMAGE \
    sh -c '/usr/bin/shp2pgsql -I -s 4326 /data/${SHAPE_FILE_BASE}.shp $TABLE_NAME > /data/shp2pgsql_output.sql'

    # Step 3: Execute DROP TABLE if exists
    echo "Dropping table if exists..."
    execute_sql "$DROP_TABLE_SQL"
    echo "Drop table completed."

    # Step 4: Import the SQL file into PostGIS using psql
    echo "Importing SQL into PostGIS database..."
    docker run --rm --env-file $ENV_FILE -e HOST_IP=$host_ip -v $UNZIP_DIR:/data $DOCKER_IMAGE \
    sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -h $HOST_IP < /data/shp2pgsql_output.sql'

    # Step 5: Create GIST INDEX
    echo "Creating GIST index on table $table_name..."
    execute_sql "$CREATE_INDEX_SQL"
    echo "Indexing completed."

    # Step 6: Clean up - delete the unzipped files
    echo "Cleaning up unzipped files..."
    rm -rf "$UNZIP_DIR"

    echo "Shapefile for table '$table_name' imported and unzipped files deleted successfully."
    echo "--------------------------------------------"
done

echo "All files processed successfully."
