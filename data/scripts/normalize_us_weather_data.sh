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
PIVOT_TABLE="weather_observations_pivoted"
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

UPSERT_PIVOT_SQL="""
INSERT INTO weather_observations_pivoted (station_id, date, tmax, tmin, hmin, hmax)
SELECT 
    station_id,
    wo.observation_date,  -- Replace 'date' with the correct column name
    -- Use COALESCE to prioritize TMAX, then MXPN, then TOBS for max temperature
    COALESCE(
        MAX(CASE WHEN observation_type = 'TMAX' THEN value END),
        MAX(CASE WHEN observation_type = 'MXPN' THEN value END),
        MAX(CASE WHEN observation_type = 'TOBS' THEN value END),
        MAX(CASE WHEN observation_type = 'TAVG' THEN value END)
    ) AS tmax,
    
    -- Use COALESCE to prioritize TMIN, then MNPN, then TOBS for min temperature
    COALESCE(
        MIN(CASE WHEN observation_type = 'TMIN' THEN value END),
        MIN(CASE WHEN observation_type = 'MNPN' THEN value END),
        MIN(CASE WHEN observation_type = 'TOBS' THEN value END),
        MIN(CASE WHEN observation_type = 'TAVG' THEN value END)
    ) AS tmin,
    
    -- Use MIN for hmin (previously rhmn) as it's the minimum relative humidity
    COALESCE(
	    MIN(CASE WHEN observation_type = 'RHMN' THEN value END),
	    MIN(CASE WHEN observation_type = 'RHAV' THEN value END)
    )
     AS hmin,
    
    -- Use MAX for hmax (previously rhmx) as it's the maximum relative humidity
    COALESCE(
	    MAX(CASE WHEN observation_type = 'RHMX' THEN value END),
	    MAX(CASE WHEN observation_type = 'RHAV' THEN value END)
	) AS hmax
FROM 
    weather_observations wo
WHERE
    observation_type IN ('TMAX', 'TMIN', 'RHMN', 'RHMX', 'MXPN', 'MNPN', 'TOBS', 'TAVG', 'RHAV')
GROUP BY 
    station_id, wo.observation_date  -- Ensure you use the correct date column
ON CONFLICT (station_id, date)
DO UPDATE SET
	tmax = EXCLUDED.tmax,
	tmin = EXCLUDED.tmin,
	hmin = EXCLUDED.hmin,
	hmax = EXCLUDED.hmax
;
"""

CREATE_PIVOT_TABLE_SQL="
CREATE TABLE IF NOT EXISTS weather_observations_pivoted (
    station_id VARCHAR(255),
    date DATE,
    tmax NUMERIC,
    tmin NUMERIC,
    hmax NUMERIC,
    hmin NUMERIC,
    PRIMARY KEY (station_id, date) -- Composite primary key
);
"

# Step 1: Create Pivot Table if it doesn't exist
echo "Creating pivot table if not exists..."
execute_sql "$CREATE_PIVOT_TABLE_SQL"
echo "Pivot table '$PIVOT_TABLE' is ready."

# Step 3b: Perform upsert from staging table to main table
echo "Performing upsert into the pivot table table..."
execute_sql "$UPSERT_PIVOT_SQL"
echo "Upsert completed."
