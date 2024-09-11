import psycopg2
import csv
import gzip
import logging
import os

logging.basicConfig(
    filename="error_log.log", level=logging.ERROR, format="%(asctime)s %(message)s"
)


def create_table_if_not_exists(conn):
    """Create the weather_observations table if it doesn't exist."""
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS weather_observations (
                station_id VARCHAR(20),
                observation_date DATE,
                observation_type VARCHAR(10),
                value FLOAT,
                flag VARCHAR(1),
                time_of_observation VARCHAR(4),
                PRIMARY KEY (station_id, observation_date, observation_type)
            );
        """
        )
        conn.commit()
        print("Table 'weather_stations' is ready.")


def is_valid_us_station(station_id):
    """Check if the station ID belongs to a U.S. station."""
    return station_id.lower().startswith("us")


def load_weather_data(conn, data_file):
    """Load weather data into the weather_observations table from the given .csv.gz file."""
    with conn.cursor() as cur:
        with gzip.open(
            data_file, "rt"
        ) as f:  # 'rt' opens the file in text mode (after decompression)
            reader = csv.reader(f)
            for line_number, row in enumerate(reader, start=1):
                try:
                    # Parse the row based on the format: station_id, date, observation_type, value, flag, time
                    station_id = row[0]
                    if not is_valid_us_station(station_id):
                        continue
                    observation_date = row[1]
                    observation_type = row[2]
                    value = float(row[3]) if row[3] else None
                    flag = row[6] if len(row) > 6 else None
                    time_of_observation = row[7] if len(row) > 7 else None

                    # Insert data into the table
                    cur.execute(
                        """
                        INSERT INTO weather_observations (station_id, observation_date, observation_type, value, flag, time_of_observation)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (station_id, observation_date, observation_type) 
                        DO UPDATE SET value = EXCLUDED.value, flag = EXCLUDED.flag, time_of_observation = EXCLUDED.time_of_observation;
                    """,
                        (
                            station_id,
                            observation_date,
                            observation_type,
                            value,
                            flag,
                            time_of_observation,
                        ),
                    )

                except ValueError as ve:
                    logging.error(f"ValueError on line {line_number}: {row} - {ve}")
                except psycopg2.DatabaseError as de:
                    logging.error(f"DatabaseError on line {line_number}: {row} - {de}")
                    conn.rollback()
                except Exception as e:
                    logging.error(
                        f"Unexpected error on line {line_number}: {row} - {e}"
                    )
                    conn.rollback()

        # Commit all successful inserts
        conn.commit()


def main():
    # Database connection details
    DB_HOST = "localhost"
    DB_PORT = 5432
    DB_NAME = "us_weather"
    DB_USER = "pguser"
    DB_PASSWORD = "mysecretpassword"

    conn = None
    try:
        # Connect to the PostgreSQL database
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
        )
        print("Connected to the database.")

        # Create the table if it doesn't exist
        create_table_if_not_exists(conn)

        # Folder containing data files
        data_folder = "../src/"

        # Load weather data from all .csv.gz files in the folder
        for filename in os.listdir(data_folder):
            if filename.endswith(".csv.gz"):
                data_file = os.path.join(data_folder, filename)
                print(f"Loading data from {data_file}")
                load_weather_data(conn, data_file)

    except psycopg2.OperationalError as oe:
        logging.error(f"Database connection error: {oe}")
        print(f"Database connection error: {oe}")
    except Exception as e:
        logging.error(f"Error: {e}")
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")


if __name__ == "__main__":
    main()
