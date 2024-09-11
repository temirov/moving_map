import psycopg2
import logging
import re

logging.basicConfig(
    filename="error_log.log", level=logging.ERROR, format="%(asctime)s %(message)s"
)


def create_table_if_not_exists(conn):
    """Create the weather_stations table if it doesn't exist."""
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS weather_stations (
                station_id VARCHAR(11) PRIMARY KEY,
                latitude FLOAT,
                longitude FLOAT,
                elevation FLOAT,
                state VARCHAR(2),
                location_description VARCHAR(100),
                distance FLOAT,
                direction VARCHAR(3),
                geom GEOMETRY(Point, 4326)
            );
        """
        )
        conn.commit()
        print("Table 'weather_stations' is ready.")


def parse_location_distance_direction(parts):
    """Extract the location description, distance, and direction from the parts."""
    location_parts = []
    distance = None
    direction = None

    # Check if the last two parts could be distance and direction
    if len(parts) > 6:
        last_part = parts[-1]
        second_last_part = parts[-2]

        # Regex for detecting distance and direction
        distance_match = re.match(r"^\d+(\.\d+)?$", second_last_part)
        direction_match = re.match(r"^[NESW]{1,3}$", last_part)

        if distance_match and direction_match:
            distance = float(second_last_part)
            direction = last_part
            location_parts = parts[4:-2]
        else:
            location_parts = parts[4:]
    else:
        location_parts = parts[4:]

    location_description = " ".join(location_parts).strip()
    return location_description, distance, direction


def is_valid_float(value):
    """Check if the value can be converted to a float."""
    try:
        float(value)
        return True
    except ValueError:
        return False


def is_valid_state(value):
    """Check if the state is a valid 2-character state abbreviation."""
    return len(value) == 2


def is_valid_us_station(station_id):
    """Check if the station ID belongs to a U.S. station."""
    return station_id.startswith("US")


def populate_weather_stations(conn, stations_file):
    """Populate the weather_stations table with U.S. stations data from the given file."""
    with conn.cursor() as cur:
        with open(stations_file, "r") as f:
            for line_number, line in enumerate(f, start=1):
                try:
                    # Split the line into parts by spaces
                    parts = line.split()

                    # Extract the station ID and check if it's a U.S. station
                    station_id = parts[0]
                    if not is_valid_us_station(station_id):
                        # print(f"Skipping non-U.S. station at line {line_number}: {station_id}")
                        continue

                    # Extract first four parts: station_id, latitude, longitude, elevation
                    latitude = float(parts[1])
                    longitude = float(parts[2])
                    elevation = float(parts[3])

                    # Extract the state, location description, distance, and direction
                    state = parts[4]
                    if not is_valid_state(state):
                        raise ValueError(
                            f"Invalid state value '{state}' at line {line_number}"
                        )

                    location_description, distance, direction = (
                        parse_location_distance_direction(parts)
                    )

                    # Insert into the database, avoiding duplicates
                    cur.execute(
                        """
                        INSERT INTO weather_stations (station_id, latitude, longitude, elevation, state, location_description, distance, direction, geom)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326))
                        ON CONFLICT (station_id) 
                        DO UPDATE SET 
                            latitude = EXCLUDED.latitude,
                            longitude = EXCLUDED.longitude,
                            elevation = EXCLUDED.elevation,
                            state = EXCLUDED.state,
                            location_description = EXCLUDED.location_description,
                            distance = EXCLUDED.distance,
                            direction = EXCLUDED.direction,
                            geom = ST_SetSRID(ST_MakePoint(EXCLUDED.longitude, EXCLUDED.latitude), 4326)
                    """,
                        (
                            station_id,
                            latitude,
                            longitude,
                            elevation,
                            state,
                            location_description,
                            distance,
                            direction,
                            longitude,
                            latitude,
                        ),
                    )

                except ValueError as ve:
                    # Handle parsing errors, e.g., invalid float conversion, invalid state, etc.
                    logging.error(
                        f"ValueError on line {line_number}: {line.strip()} - {ve}"
                    )
                    print(f"Skipping line {line_number} due to value error: {ve}")

                except psycopg2.DatabaseError as de:
                    # Handle database insertion errors, including length constraints
                    logging.error(
                        f"DatabaseError on line {line_number}: {line.strip()} - {de}"
                    )
                    print(f"Skipping line {line_number} due to database error: {de}")
                    conn.rollback()  # Rollback the transaction if there's a database error

                except Exception as e:
                    # Handle any other errors
                    logging.error(
                        f"Unexpected error on line {line_number}: {line.strip()} - {e}"
                    )
                    print(f"Skipping line {line_number} due to unexpected error: {e}")
                    conn.rollback()

        # Commit all successful inserts
        conn.commit()
        print(f"Weather stations data from {stations_file} has been uploaded.")


def main(drop_table=False):
    # Database connection details
    DB_HOST = "localhost"  # Replace with 'postgis' if running inside another container
    DB_PORT = 5432
    DB_NAME = "us_weather"  # From your .env file
    DB_USER = "pguser"  # From your .env file
    DB_PASSWORD = "mysecretpassword"  # From your .env file

    # Path to your weather stations file
    STATIONS_FILE = "../src/ghcnd-stations.txt"

    """Main function to create the table and upload data."""
    try:
        # Connect to the PostGIS database
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
        )
        print("Connected to the PostGIS database.")

        # Optionally drop the table
        if drop_table:
            with conn.cursor() as cur:
                cur.execute("DROP TABLE IF EXISTS weather_stations;")
                conn.commit()
                print("Table 'weather_stations' dropped.")

        # Create the table if it doesn't exist
        create_table_if_not_exists(conn)

        # Populate the table with data
        populate_weather_stations(conn, STATIONS_FILE)

    except Exception as e:
        print(f"Error: {e}")

    finally:
        # Close the connection
        if conn:
            conn.close()
            print("Database connection closed.")


if __name__ == "__main__":
    main(drop_table=True)  # Set to True if you want to drop the table first
