WITH start_date AS (
    SELECT
        TO_DATE(
            MIN(EXTRACT(YEAR FROM observation_date)) || '-' ||
            EXTRACT(MONTH FROM CURRENT_DATE) || '-' ||
            EXTRACT(DAY FROM CURRENT_DATE),
            'YYYY-MM-DD'
        ) AS start_date
    FROM
        weather_observations
),
stations_per_state AS (
    SELECT
        ws.station_id,
        ws.latitude,
        ws.longitude,
        ws.elevation,
        ws.location_description,
        uc.namelsad AS county_name
    FROM
        weather_stations ws
        JOIN us_states us ON ST_Within(ws.geom, us.geom)
        JOIN us_counties uc ON ST_Within(ws.geom, uc.geom)
    WHERE
        us.name = 'Washington'
),
weather_observations_truncated AS (
    SELECT
        w.*
    FROM
        weather_observations w
        CROSS JOIN start_date sd
    WHERE
        w.observation_date >= sd.start_date
),
qualifying_days AS (
    SELECT DISTINCT
        w.station_id,
        w.observation_date,
        s.county_name,
        EXTRACT(YEAR FROM w.observation_date) AS year
    FROM
        weather_observations_truncated w
        JOIN stations_per_state s ON w.station_id = s.station_id
    WHERE
        EXISTS (
            SELECT 1 FROM weather_observations_truncated w2
            WHERE w2.station_id = w.station_id
              AND w2.observation_date = w.observation_date
              AND w2.observation_type = 'TMAX'
              AND w2.value BETWEEN 60 AND 320
        )
        AND EXISTS (
            SELECT 1 FROM weather_observations_truncated w3
            WHERE w3.station_id = w.station_id
              AND w3.observation_date = w.observation_date
              AND w3.observation_type = 'TMIN'
              AND w3.value BETWEEN 60 AND 320
        )
),
county_yearly_totals AS (
    SELECT
        county_name,
        year,
        COUNT(DISTINCT observation_date) AS total_num_days
    FROM
        qualifying_days
    GROUP BY
        county_name,
        year
),
county_average_days AS (
    SELECT
        county_name,
        AVG(total_num_days) AS avg_num_days_per_year
    FROM
        county_yearly_totals
    GROUP BY
        county_name
)
SELECT
    county_name,
    FLOOR(avg_num_days_per_year) AS avg_num_days
FROM
    county_average_days
ORDER BY
    avg_num_days DESC;
