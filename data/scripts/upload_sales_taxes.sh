#!/bin/bash

# Source the shared functions and variables
# Adjust the path to common.sh based on your directory structure
source "$(dirname "$0")/common.sh"

DATA_FOLDER=$(realpath "../src/TAXRATES_ZIP5")  # Absolute path to data folder
MAIN_TABLE="sales_taxes"

check_folder_exists "$DATA_FOLDER"

# SQL statement to create the main sales_taxes table if it doesn't exist
CREATE_MAIN_TABLE_SQL="
CREATE TABLE IF NOT EXISTS sales_taxes (
    id SERIAL PRIMARY KEY,
    state VARCHAR(2) NOT NULL,
    zipcode VARCHAR(5) NOT NULL,
    tax_region_name VARCHAR(255),
    estimated_combined_rate FLOAT,
    state_rate FLOAT,
    estimated_county_rate FLOAT,
    estimated_city_rate FLOAT,
    estimated_special_rate FLOAT,
    risk_level INTEGER,
    geom GEOMETRY(MultiPolygon, 4326),
    CONSTRAINT sales_taxes_unique UNIQUE (zipcode, tax_region_name)
);
"

# SQL statement for upserting data into the main table
UPSERT_SQL="
INSERT INTO $MAIN_TABLE (
    state, zipcode, tax_region_name, estimated_combined_rate, 
    state_rate, estimated_county_rate, estimated_city_rate, 
    estimated_special_rate, risk_level
)
SELECT 
    state, zipcode, tax_region_name, estimated_combined_rate, 
    state_rate, estimated_county_rate, estimated_city_rate, 
    estimated_special_rate, risk_level
FROM $MAIN_TABLE
ON CONFLICT (zipcode, tax_region_name) 
DO UPDATE SET 
    state = EXCLUDED.state,
    estimated_combined_rate = EXCLUDED.estimated_combined_rate,
    state_rate = EXCLUDED.state_rate,
    estimated_county_rate = EXCLUDED.estimated_county_rate,
    estimated_city_rate = EXCLUDED.estimated_city_rate,
    estimated_special_rate = EXCLUDED.estimated_special_rate,
    risk_level = EXCLUDED.risk_level;
"

# SQL statement to add geometry by joining with us_zipcode table
ADD_GEOM_SQL="
UPDATE $MAIN_TABLE mt
SET geom = uz.geom
FROM us_zipcode uz
WHERE mt.zipcode = uz.zcta5ce20;
"

# SQL statements to create indexes
CREATE_INDEXES_SQL="
CREATE INDEX IF NOT EXISTS idx_sales_taxes_zipcode ON $MAIN_TABLE(zipcode);
CREATE INDEX IF NOT EXISTS idx_sales_taxes_tax_region_name ON $MAIN_TABLE(tax_region_name);
CREATE INDEX IF NOT EXISTS idx_sales_taxes_geom ON $MAIN_TABLE USING GIST (geom);
"

# Step 0: Drop main table
echo "Creating main table if not exists..."
execute_sql "DROP TABLE IF EXISTS $MAIN_TABLE"
echo "Main table '$MAIN_TABLE' is ready."

# Step 1: Create Main Table if it doesn't exist
echo "Creating main table if not exists..."
execute_sql "$CREATE_MAIN_TABLE_SQL"
echo "Main table '$MAIN_TABLE' is ready."

# Step 1a: Create Indexes
echo "Creating indexes..."
execute_sql "$CREATE_INDEXES_SQL"
echo "Indexes created successfully."

# Step 2: Process Each .csv File
for csv_file in "$DATA_FOLDER"/*.csv; do
    # Check if the file exists
    check_file_exists "$csv_file"

    echo "Processing file: $csv_file"

    # Extract basename for Docker volume
    csv_filename=$(basename "$csv_file")

    # Step 2a: Load data directly into main table using COPY with upsert
    echo "Loading data into main table..."

    # Use a temporary variable to hold the SQL COPY command
    COPY_SQL="\copy $MAIN_TABLE (state, zipcode, tax_region_name, estimated_combined_rate, state_rate, estimated_county_rate, estimated_city_rate, estimated_special_rate, risk_level) FROM '/data/$csv_filename' WITH (FORMAT csv, HEADER true)"

    # Execute the COPY command within Docker
    docker run --rm \
        --env-file "$ENV_FILE" \
        -e csv_file="$csv_file" \
        -e COPY_SQL="$COPY_SQL" \
        -e host_ip="$host_ip" \
        -v "$DATA_FOLDER":/data \
        $DOCKER_IMAGE \
        sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -h $host_ip -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c "$COPY_SQL"'

    echo "Data loaded into main table."

    # Step 2b: Perform upsert from main table to handle conflicts
    echo "Performing upsert into main table..."
    execute_sql "$UPSERT_SQL"
    echo "Upsert completed."

    echo "Finished processing file: $csv_file"
    echo "-------------------------------------------"
done

echo "All files have been processed successfully."

# Step 3: Add Geometry to Main Table
echo "Adding geometry to main table..."
execute_sql "$ADD_GEOM_SQL"
echo "Geometry added successfully."

echo "-------------------------------------------"
echo "Sales taxes data upload completed."
