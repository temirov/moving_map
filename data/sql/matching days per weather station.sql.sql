WITH end_prev_year AS (
    -- Determine December 31 of the previous year
    SELECT MAKE_DATE(
            EXTRACT(
                YEAR
                FROM CURRENT_DATE
            )::int - 1,
            12,
            31
        ) AS end_of_previous_year
),
stations_by_state AS (
    -- Filter stations by specified states using spatial joins
    SELECT ws.station_id,
        ws.geom,
        us.stusps AS us_state,
        uc.namelsad AS county_name
    FROM weather_stations ws
        JOIN us_states us ON ws.geom && us.geom
        AND ST_Within(ws.geom, us.geom)
        JOIN us_counties uc ON ws.geom && uc.geom
        AND ST_Within(ws.geom, uc.geom)
    WHERE us.name IN (
            'Washington',
            'Nevada',
            'Florida',
            'Texas',
            'Alaska',
            'South Dakota',
            'Wyoming',
            'Tennessee',
            'New Hampshire'
        )
),
filtered_weather AS (
    -- Filter weather data by temperature using the stations from the first CTE
    SELECT wo.station_id,
        wo.date,
        sw.us_state,
        sw.county_name
    FROM weather_observations_pivoted wo
        JOIN stations_by_state sw ON wo.station_id = sw.station_id
    WHERE wo.tmin between 50 and 260
        AND wo.tmax between 50 and 260
),
filtered_by_year_weather AS (
    -- Restrict observations to dates up to the end of the previous year
    SELECT fw.*
    FROM filtered_weather fw
        CROSS JOIN end_prev_year ep
    WHERE fw.date <= ep.end_of_previous_year
),
station_matching_days AS (
    -- Calculate the total number of matching days for each station
    SELECT station_id,
        county_name,
        us_state,
        COUNT(DISTINCT date) AS matching_days
    FROM filtered_by_year_weather
    GROUP BY station_id,
        county_name,
        us_state
),
station_years AS (
    -- Calculate the number of distinct years each station has data for
    SELECT station_id,
        COUNT(
            DISTINCT EXTRACT(
                YEAR
                FROM date
            )
        ) AS num_years
    FROM filtered_by_year_weather
    GROUP BY station_id
),
station_matching_days_per_year AS (
    -- Compute the average matching days per year for each station
    SELECT smd.station_id,
        smd.county_name,
        smd.us_state,
        smd.matching_days / sy.num_years AS matching_days_per_year
    FROM station_matching_days smd
        JOIN station_years sy ON smd.station_id = sy.station_id
) -- Final Query: Calculate the floored average matching days per county
SELECT us_state,
    county_name,
    FLOOR(AVG(matching_days_per_year)) AS avg_matching_days_per_year
FROM station_matching_days_per_year
GROUP BY us_state,
    county_name
ORDER BY avg_matching_days_per_year DESC,
    us_state ASC,
    county_name ASC;