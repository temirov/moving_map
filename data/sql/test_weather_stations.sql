CREATE OR REPLACE FUNCTION public.test_weather_stations(
    z integer,
    x integer,
    y integer
) 
RETURNS bytea AS $$
DECLARE 
    result bytea;
    bbox geometry;
    zp integer := pow(2, z);
BEGIN 
    IF y >= zp OR y < 0 OR x >= zp OR x < 0 THEN
        RAISE EXCEPTION 'invalid tile coordinate (%, %, %)', z, x, y;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS geom
    ),
    mvtgeom AS (
        SELECT ST_AsMVTGeom(ST_Transform(a.geom, 3857), b.geom) AS geom,
            a.station_id, a.state
        FROM weather_stations a, bounds b
    )
    SELECT ST_AsMVT(mvtgeom, 'weather_stations_layer')
    INTO result
    FROM mvtgeom;

    RETURN result;
END;
$$ LANGUAGE plpgsql 
STABLE 
PARALLEL SAFE;
