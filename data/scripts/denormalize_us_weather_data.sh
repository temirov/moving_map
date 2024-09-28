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
PIVOT_TABLE="weather_observations_denormalized"
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

# SQL commands for creating the table and indexes
CREATE_PIVOT_TABLE_SQL="
CREATE TABLE IF NOT EXISTS $PIVOT_TABLE (
    station_id VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    year INTEGER NOT NULL,                      -- Added year column
    tmax NUMERIC,
    tmin NUMERIC,
    hmax NUMERIC,
    hmin NUMERIC,
    state VARCHAR(100),
    county VARCHAR(255),
    geom GEOMETRY(Point, 4326),
    PRIMARY KEY (station_id, date)
);
"

# SQL command to insert/update data in the pivot table
UPSERT_PIVOT_SQL="
INSERT INTO $PIVOT_TABLE 
(station_id, date, year, tmax, tmin, hmin, hmax, state, county, geom)
SELECT 
    wo.station_id,
    wo.observation_date,
    EXTRACT(YEAR FROM wo.observation_date) AS year,  -- Extract year
    COALESCE(
        MAX(CASE WHEN wo.observation_type = 'TMAX' THEN wo.value END),
        MAX(CASE WHEN wo.observation_type = 'MXPN' THEN wo.value END),
        MAX(CASE WHEN wo.observation_type = 'TOBS' THEN wo.value END),
        MAX(CASE WHEN wo.observation_type = 'TAVG' THEN wo.value END)
    ) AS tmax,
    COALESCE(
        MIN(CASE WHEN wo.observation_type = 'TMIN' THEN wo.value END),
        MIN(CASE WHEN wo.observation_type = 'MNPN' THEN wo.value END),
        MIN(CASE WHEN wo.observation_type = 'TOBS' THEN wo.value END),
        MIN(CASE WHEN wo.observation_type = 'TAVG' THEN wo.value END)
    ) AS tmin,
    COALESCE(
        MIN(CASE WHEN wo.observation_type = 'RHMN' THEN wo.value END),
        MIN(CASE WHEN wo.observation_type = 'RHAV' THEN wo.value END)
    ) AS hmin,
    COALESCE(
        MAX(CASE WHEN wo.observation_type = 'RHMX' THEN wo.value END),
        MAX(CASE WHEN wo.observation_type = 'RHAV' THEN wo.value END)
    ) AS hmax,
    ws.state,
    uc.namelsad AS county,
    ws.geom
FROM 
    weather_observations wo
JOIN 
    weather_stations ws ON wo.station_id = ws.station_id
JOIN 
    us_counties uc ON ST_Within(ws.geom, uc.geom)
WHERE
    wo.observation_type IN ('TMAX', 'TMIN', 'RHMN', 'RHMX', 'MXPN', 'MNPN', 'TOBS', 'TAVG', 'RHAV')
GROUP BY 
    wo.station_id, 
    wo.observation_date,
    ws.state,
    uc.namelsad,
    ws.geom
ON CONFLICT (station_id, date)
DO UPDATE SET
    year = EXCLUDED.year,
    tmax = EXCLUDED.tmax,
    tmin = EXCLUDED.tmin,
    hmin = EXCLUDED.hmin,
    hmax = EXCLUDED.hmax,
    state = EXCLUDED.state,
    county = EXCLUDED.county,
    geom = EXCLUDED.geom
;
"

# SQL commands to create indexes for optimization
CREATE_INDICES="
CREATE INDEX IF NOT EXISTS idx_weather_geom ON $PIVOT_TABLE USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_weather_temp_date ON $PIVOT_TABLE (tmin, tmax, date);
CREATE INDEX IF NOT EXISTS idx_weather_station_state_county_geom ON $PIVOT_TABLE (station_id, state, county, year);
CREATE INDEX IF NOT EXISTS idx_weather_temp_geom ON $PIVOT_TABLE (tmin, tmax, geom);
CREATE INDEX IF NOT EXISTS idx_weather_temp_year ON $PIVOT_TABLE (tmin, tmax, year);
"

# Step 1: Create the pivot table if it doesn't exist
echo "Creating pivot table if not exists..."
execute_sql "$CREATE_PIVOT_TABLE_SQL"
echo "Pivot table '$PIVOT_TABLE' is ready."

# Step 1a: Truncate staging table for next file
echo "Truncating '$PIVOT_TABLE' table..."
execute_sql "TRUNCATE TABLE $PIVOT_TABLE;"
echo "Staging '$PIVOT_TABLE' truncated."

# Step 2: Upsert data into the pivot table
echo "Inserting or updating data into the pivot table..."
execute_sql "$UPSERT_PIVOT_SQL"
echo "Data upsert completed."

# Step 3: Create necessary indexes for the pivot table
echo "Creating indexes on the pivot table..."
execute_sql "$CREATE_INDICES"
echo "Indexes created successfully."
