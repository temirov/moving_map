CREATE OR REPLACE FUNCTION public.test_voronoi_weather_stations(
        z integer,
        x integer,
        y integer
    ) 
RETURNS bytea AS $$
DECLARE 
    zp integer := pow(2, z);
    result bytea;
BEGIN 
    IF y >= zp OR y < 0 OR x >= zp OR x < 0 THEN
        RAISE EXCEPTION 'invalid tile coordinate (%, %, %)', z, x, y;
    END IF;

    WITH
    -- Tile bounds in Web Mercator (SRID 3857)
    bounds AS (
      SELECT ST_TileEnvelope(z, x, y) AS geom -- SRID 3857
    ),
    -- Transform counties to SRID 3857 and select those intersecting the tile
    counties_in_tile AS (
      SELECT c.*,
             ST_Transform(c.geom, 3857) AS geom_3857
      FROM counties c
      JOIN bounds b ON ST_Intersects(ST_Transform(c.geom, 3857), b.geom)
    ),
    -- Transform weather stations to SRID 3857 and associate them with counties
    stations AS (
      SELECT ST_Transform(w.geom, 3857) AS geom,
             c.county_name,
             c.geom_3857 AS county_geom
      FROM weather_stations w
      JOIN counties_in_tile c ON ST_Contains(c.geom_3857, ST_Transform(w.geom, 3857))
    ),
    -- Generate Voronoi polygons per county in SRID 3857
    voronoi_polygons AS (
      SELECT
        s.county_name,
        -- Generate Voronoi polygons from the weather station points within each county
        ST_CollectionExtract(
          ST_VoronoiPolygons(
            ST_Collect(s.geom),
            0,  -- 0 means no tolerance, adjust if necessary
            ARRAY[
              ST_ExteriorRing(s.county_geom)  -- Limit the Voronoi diagram to the county boundary
            ]
          ), 3  -- Extract polygons
        ) AS geom,
        s.county_geom
      FROM stations s
      GROUP BY s.county_name, s.county_geom
    ),
    -- Prepare geometries for MVT output
    mvtgeom AS (
      SELECT
        ST_AsMVTGeom(
          vp.geom,
          bounds.geom -- Already in SRID 3857
        ) AS geom,
        vp.county_name
      FROM voronoi_polygons vp
      JOIN bounds b ON ST_Intersects(vp.geom, b.geom)
    )
    SELECT ST_AsMVT(mvtgeom, 'weather_stations_layer')
    INTO result
    FROM mvtgeom;

    RETURN result;
END;
$$ LANGUAGE plpgsql 
STABLE 
PARALLEL SAFE;
