SELECT 
    station_id,
    GeometryType(geom) AS geom_type,
    ST_IsValid(geom) AS is_valid,
    ST_IsClosed(geom) AS is_closed,
    ST_IsSimple(geom) AS is_simple
FROM tmp_weather_test;
