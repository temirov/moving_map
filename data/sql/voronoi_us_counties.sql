-- Step 0: Ensure PostGIS Extension is Enabled
CREATE EXTENSION IF NOT EXISTS postgis;
-- Step 1: Prepare the US Boundary
-- Assuming you have a table 'country' with a single geometry representing the US contour.
WITH us_boundary_transformed AS (
    SELECT ST_Transform(a.geom, 3857) AS geom_3857
    FROM country a
    WHERE a.name = 'United States of America'
),
-- Step 2: Filter and Prepare Weather Stations
temperature_weather_stations AS (
    SELECT DISTINCT a.station_id,
        a.geom
    FROM weather_observations_denormalized a
    WHERE a.geom IS NOT NULL
        AND a.tmin IS NOT NULL
        AND a.tmax IS NOT NULL
),
weather_stations_3857 AS (
    SELECT a.station_id,
        ST_Transform(a.geom, 3857) AS geom_3857
    FROM temperature_weather_stations a
),
-- Step 3: Generate a Single Voronoi Diagram for All Weather Stations
voronoi_all AS (
    SELECT (
            ST_Dump(
                ST_VoronoiPolygons(ST_Collect(ws.geom_3857), 0.0001)
            )
        ).geom AS voronoi_geom
    FROM weather_stations_3857 ws
),
-- Step 4: Associate Each Voronoi Polygon with Its Corresponding Weather Station
voronoi_with_station AS (
    SELECT ws.station_id,
        ST_Intersection(va.voronoi_geom, ub.geom_3857) AS voronoi_clipped_geom
    FROM voronoi_all va
        JOIN weather_stations_3857 ws ON ST_Contains(va.voronoi_geom, ws.geom_3857)
        CROSS JOIN us_boundary_transformed ub
    WHERE ST_Intersects(va.voronoi_geom, ub.geom_3857)
),
-- Step 5: Transform Clipped Voronoi Polygons Back to SRID 4326
voronoi_4326 AS (
    SELECT station_id,
        ST_SetSRID(ST_Transform(voronoi_clipped_geom, 4326), 4326) AS geom
    FROM voronoi_with_station
    WHERE NOT ST_IsEmpty(voronoi_clipped_geom)
) -- Step 6: Create the Final Voronoi Table
SELECT station_id,
    geom INTO us_weather_voronoi
FROM voronoi_4326;
CREATE INDEX IF NOT EXISTS idx_us_weather_voronoi_geom ON us_weather_voronoi USING GIST (geom);