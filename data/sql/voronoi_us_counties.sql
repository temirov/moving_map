-- Create the new table and populate it with the results
CREATE TABLE us_county_weather_stations AS
WITH
-- Transform counties to SRID 3857
counties_3857 AS (
    SELECT a.*,
        ST_Transform(a.geom, 3857) AS geom_3857
    FROM us_counties a
),
-- Transform weather stations to SRID 3857
weather_stations_3857 AS (
    SELECT
        ST_Transform(w.geom, 3857) AS geom,
        w.station_id
    FROM weather_stations w
),
-- Associate transformed weather stations with counties
stations AS (
    SELECT
        ws.geom,
        ws.station_id,
        c.namelsad AS county_name,
        c.geom_3857 AS county_geom
    FROM weather_stations_3857 ws
    JOIN counties_3857 c ON ST_Contains(c.geom_3857, ws.geom)
),
-- Generate Voronoi polygons per county without clipping
voronoi_polygons AS (
    SELECT
        s.county_name,
        s.county_geom,
        CASE
            WHEN COUNT(s.geom) > 1 THEN
                -- Generate Voronoi polygons without clipping
                ST_VoronoiPolygons(
                    ST_Collect(s.geom),
                    0.0
                )
            ELSE
                s.county_geom
        END AS geom_collection
    FROM stations s
    GROUP BY s.county_name, s.county_geom
),
-- Explode the geometry collection into individual polygons
voronoi_polygons_exploded AS (
    SELECT
        vp.county_name,
        (ST_Dump(vp.geom_collection)).geom AS voronoi_geom
    FROM voronoi_polygons vp
),
-- Intersect Voronoi polygons with the county geometry to clip them
clipped_voronoi AS (
    SELECT
        sub.county_name,
        sub.intersection AS geom
    FROM (
        SELECT
            vpe.county_name,
            ST_Intersection(vpe.voronoi_geom, c.geom_3857) AS intersection
        FROM voronoi_polygons_exploded vpe
        JOIN counties_3857 c ON vpe.county_name = c.namelsad
    ) sub
    WHERE NOT ST_IsEmpty(sub.intersection)
),
-- Associate each clipped Voronoi polygon with its weather station
voronoi_with_station AS (
    SELECT
        cv.county_name,
        cv.geom,
        s.station_id
    FROM clipped_voronoi cv
    JOIN stations s ON ST_Intersects(cv.geom, s.geom)
)
SELECT
    county_name,
    geom::geometry(MultiPolygon, 3857) AS geom,  -- Cast as MultiPolygon
    station_id
FROM voronoi_with_station;

-- Add primary key
ALTER TABLE us_county_weather_stations
ADD COLUMN id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY;

-- Create spatial index
CREATE INDEX idx_us_county_weather_stations_geom ON us_county_weather_stations USING GIST (geom);
