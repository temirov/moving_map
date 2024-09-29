DROP TABLE IF EXISTS tmp_weather_test;
WITH weather_observations_denormalized_voronoi as (
    SELECT wod.*,
        uv.geom as geom_voronoi
    FROM weather_observations_denormalized wod
        LEFT JOIN us_weather_voronoi uv ON wod.station_id = uv.station_id
),
yearly_matching_days AS (
    -- Calculate the number of matching days per station per year
    SELECT station_id,
        state,
        county,
        geom_voronoi as geom,
        year,
        -- Use the year from the denormalized table
        COUNT(date) AS matching_days
    FROM weather_observations_denormalized_voronoi
    WHERE tmin BETWEEN 60 AND 300
        AND tmax BETWEEN 60 AND 300
    GROUP BY station_id,
        state,
        county,
        geom_voronoi,
        year -- Group by year directly
),
station_years AS (
    -- Calculate the number of distinct years each station has data for
    SELECT station_id,
        COUNT(DISTINCT year) AS num_years
    FROM yearly_matching_days
    GROUP BY station_id
),
avg_matching_days_per_station AS (
    -- Calculate the average number of matching days per station across all years
    SELECT ymd.station_id,
        ymd.state,
        ymd.county,
        ymd.geom,
        COALESCE(
            SUM(ymd.matching_days) / NULLIF(sy.num_years, 0),
            0
        ) AS avg_matching_days_per_year
    FROM yearly_matching_days ymd
        JOIN station_years sy ON ymd.station_id = sy.station_id
    GROUP BY ymd.station_id,
        ymd.state,
        ymd.county,
        ymd.geom,
        sy.num_years
) -- Select the final data to return in the MVT format
SELECT station_id,
    state,
    county,
    geom,
    FLOOR(avg_matching_days_per_year) AS avg_matching_days_per_year INTO tmp_weather_test
FROM avg_matching_days_per_station;
ALTER TABLE tmp_weather_test
ADD COLUMN IF NOT EXISTS id SERIAL PRIMARY KEY;