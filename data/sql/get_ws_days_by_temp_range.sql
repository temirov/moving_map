CREATE OR REPLACE FUNCTION get_ws_days_by_temp_range(
    z INTEGER DEFAULT 5, 
    x INTEGER DEFAULT 5, 
    y INTEGER DEFAULT 12, 
    min_temp NUMERIC DEFAULT -100, 
    max_temp NUMERIC DEFAULT 300
) 
RETURNS BYTEA AS $$
DECLARE
    bbox GEOMETRY;
    zp integer = pow(2, z);
BEGIN
    IF y >= zp OR y < 0 OR x >= zp OR x < 0 THEN
        RAISE EXCEPTION 'invalid tile coordinate (%, %, %)', z, x, y;
    END IF;

    -- Calculate the bounding box for the tile in SRID 4326 (WGS 84)
    bbox := ST_Transform(ST_TileEnvelope(z, x, y), 4326);

    -- Return the MVT tiles containing the filtered station geometries and attributes
    RETURN (
        SELECT ST_AsMVT(tile, 'ws_stations_layer', 4096, 'geom') 
        FROM (
            WITH yearly_matching_days AS (
                -- Calculate the number of matching days per station per year
                SELECT 
                    station_id,
                    state,
                    county,
                    geom,
                    year,  -- Use the year from the denormalized table
                    COUNT(date) AS matching_days
                FROM 
                    weather_observations_denormalized
                WHERE 
                    tmin BETWEEN min_temp AND max_temp
                    AND tmax BETWEEN min_temp AND max_temp
                    AND ST_Intersects(geom, bbox)  -- Ensure geometry is within the bounding box
                GROUP BY 
                    station_id, state, county, geom, year  -- Group by year directly
            ),
            station_years AS (
                -- Calculate the number of distinct years each station has data for
                SELECT 
                    station_id,
                    COUNT(DISTINCT year) AS num_years
                FROM 
                    yearly_matching_days
                GROUP BY 
                    station_id
            ),
            avg_matching_days_per_station AS (
                -- Calculate the average number of matching days per station across all years
                SELECT 
                    ymd.station_id,
                    ymd.state,
                    ymd.county,
                    ymd.geom,
                    COALESCE(SUM(ymd.matching_days) / NULLIF(sy.num_years, 0), 0) AS avg_matching_days_per_year
                FROM 
                    yearly_matching_days ymd
                JOIN 
                    station_years sy ON ymd.station_id = sy.station_id
                GROUP BY 
                    ymd.station_id, ymd.state, ymd.county, ymd.geom, sy.num_years
            )
            -- Select the final data to return in the MVT format
            SELECT 
                station_id,
                state,
                county,
                geom,
                FLOOR(avg_matching_days_per_year) AS avg_matching_days_per_year
            FROM 
                avg_matching_days_per_station
        ) AS tile
    );
END;
$$ LANGUAGE plpgsql
STABLE
PARALLEL SAFE;
