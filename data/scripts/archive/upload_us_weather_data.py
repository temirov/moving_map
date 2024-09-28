import csv
import gzip
import logging
import os
import time
from pathlib import Path
from typing import List, Optional

import psycopg2
from dotenv import load_dotenv
from psycopg2.extensions import connection as Connection
from psycopg2.extras import execute_values


def setup_logging(log_file: str) -> None:
    """
    Configure logging settings to log to both file and console.

    Args:
        log_file (str): Path to the log file.
    """
    logger = logging.getLogger()
    logger.setLevel(logging.ERROR)

    # File handler
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(logging.ERROR)
    file_formatter = logging.Formatter(
        "%(asctime)s %(levelname)s: %(message)s", "%Y-%m-%d %H:%M:%S"
    )
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.ERROR)
    console_formatter = logging.Formatter("%(levelname)s: %(message)s")
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)


def validate_env_vars(required_vars: List[str]) -> None:
    """
    Ensure all required environment variables are set and valid.

    Args:
        required_vars (List[str]): List of required environment variable names.

    Raises:
        EnvironmentError: If any required environment variable is missing or invalid.
    """
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    if missing_vars:
        missing = ", ".join(missing_vars)
        logging.error(f"Missing required environment variables: {missing}")
        raise EnvironmentError(f"Missing required environment variables: {missing}")

    # Optional: Validate specific variable formats
    db_port = os.getenv("DB_PORT")
    if db_port and not db_port.isdigit():
        logging.error(f"Invalid DB_PORT: {db_port}. Must be an integer.")
        raise EnvironmentError(f"Invalid DB_PORT: {db_port}. Must be an integer.")


def create_table_if_not_exists(conn: Connection, table_name: str, sql_string: str) -> None:
    """
    Create the specified table in the database if it doesn't exist.

    Args:
        conn (Connection): The PostgreSQL database connection.
        table_name (str): The name of the table to create.
        sql_string (str): The SQL statement to create the table.
    """
    with conn.cursor() as cur:
        cur.execute(sql_string)
        conn.commit()
        print(f"Table '{table_name}' is ready.")


def is_valid_us_station(station_id: str) -> bool:
    """
    Check if the station ID belongs to a U.S. station.

    Args:
        station_id (str): The station ID to validate.

    Returns:
        bool: True if valid, False otherwise.
    """
    return station_id.lower().startswith("us")


def load_weather_data(conn: Connection, data_file: Path, batch_size: int = 1000) -> None:
    """
    Load weather data into the weather_observations table from the given .csv.gz file using batch inserts.

    Args:
        conn (Connection): The PostgreSQL database connection.
        data_file (Path): The path to the compressed CSV data file.
        batch_size (int, optional): Number of rows per batch. Defaults to 1000.
    """
    insert_query = """
        INSERT INTO weather_observations (station_id, observation_date, observation_type, value, flag, time_of_observation)
        VALUES %s
        ON CONFLICT (station_id, observation_date, observation_type) 
        DO UPDATE SET 
            value = EXCLUDED.value, 
            flag = EXCLUDED.flag, 
            time_of_observation = EXCLUDED.time_of_observation;
    """

    with conn.cursor() as cur, gzip.open(data_file, "rt") as f:
        reader = csv.reader(f)
        batch = []
        for line_number, row in enumerate(reader, start=1):
            try:
                if len(row) < 4:
                    raise ValueError("Insufficient columns in row.")

                station_id = row[0]
                if not is_valid_us_station(station_id):
                    continue

                observation_date = row[1]
                observation_type = row[2]
                value = float(row[3]) if row[3] else None
                flag = row[6] if len(row) > 6 else None
                time_of_observation = row[7] if len(row) > 7 else None

                batch.append((
                    station_id,
                    observation_date,
                    observation_type,
                    value,
                    flag,
                    time_of_observation,
                ))

                if len(batch) >= batch_size:
                    execute_values(cur, insert_query, batch)
                    conn.commit()
                    batch.clear()

            except ValueError as ve:
                logging.error(f"ValueError on line {line_number}: {row} - {ve}")
            except psycopg2.DatabaseError as de:
                logging.error(f"DatabaseError on line {line_number}: {row} - {de}")
                conn.rollback()
            except Exception as e:
                logging.error(f"Unexpected error on line {line_number}: {row} - {e}")
                conn.rollback()

        # Insert any remaining rows in the batch
        if batch:
            execute_values(cur, insert_query, batch)
            conn.commit()



def connect_with_retries(host: str, port: int, database: str, user: str, password: str, retries: int = 5, delay: int = 5) -> Connection:
    """
    Attempt to connect to the PostgreSQL database with retries.

    Args:
        host (str): Database host.
        port (int): Database port.
        database (str): Database name.
        user (str): Database user.
        password (str): Database password.
        retries (int, optional): Number of retry attempts. Defaults to 5.
        delay (int, optional): Delay between retries in seconds. Defaults to 5.

    Raises:
        psycopg2.OperationalError: If connection fails after all retries.

    Returns:
        Connection: Established PostgreSQL database connection.
    """
    attempt = 0
    while attempt < retries:
        try:
            conn = psycopg2.connect(
                host=host,
                port=port,
                database=database,
                user=user,
                password=password,
            )
            return conn
        except psycopg2.OperationalError as oe:
            logging.error(f"Attempt {attempt + 1} - Database connection failed: {oe}")
            print(f"Attempt {attempt + 1} - Database connection failed: {oe}")
            attempt += 1
            if attempt < retries:
                print(f"Retrying in {delay} seconds...")
                time.sleep(delay)
    raise psycopg2.OperationalError("Exceeded maximum retries for database connection.")


def main() -> None:
    """
    Main function to orchestrate the loading of weather data into the database.
    """
    # Determine the path to the .env file in the parent directory

    dotenv_path = "../../.env"

    # Load environment variables from the .env file
    loaded = load_dotenv(dotenv_path)

    # Debug: Print whether the .env file was found and loaded
    if not loaded:
        print(f"Failed to load .env file from {dotenv_path}")


    # Retrieve configuration from environment variables
    db_host = os.getenv("POSTGRES_HOST")
    db_port = int(os.getenv("POSTGRES_PORT"))
    db_name = os.getenv("POSTGRES_DB")
    db_user = os.getenv("POSTGRES_USER")
    db_password = os.getenv("POSTGRES_PASSWORD")
    log_file = os.getenv("LOG_FILE")


    # Debug: Print the loaded environment variables (excluding sensitive ones)
    print(f"DB_HOST: {db_host}")
    print(f"DB_PORT: {db_port}")
    print(f"DB_NAME: {db_name}")
    print(f"DB_USER: {db_user}")
    print(f"LOG_FILE: {log_file}")

    # Setup logging
    setup_logging(log_file)

    table_name = "weather_observations"
    create_weather_observations_table_sql = """
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

    conn: Optional[Connection] = None
    try:
        # Connect to the PostgreSQL database with retries
        conn = connect_with_retries(
            host=db_host,
            port=db_port,
            database=db_name,
            user=db_user,
            password=db_password,
        )
        print("Connected to the database.")

        # Create the table if it doesn't exist
        create_table_if_not_exists(conn, table_name, create_weather_observations_table_sql)
        # Data Directory
        data_folder='../src/'

        # Resolve the data folder path
        data_folder_path = Path(data_folder).resolve()

        if not data_folder_path.exists() or not data_folder_path.is_dir():
            raise FileNotFoundError(f"Data folder '{data_folder_path}' does not exist or is not a directory.")

        # Load weather data from all .csv.gz files in the folder
        for data_file in data_folder_path.glob("*.csv.gz"):
            print(f"Loading data from {data_file}")
            load_weather_data(conn, data_file, 10_000)

    except psycopg2.OperationalError as oe:
        logging.error(f"Database connection error: {oe}")
        print(f"Database connection error: {oe}")
    except FileNotFoundError as fe:
        logging.error(f"File error: {fe}")
        print(f"File error: {fe}")
    except EnvironmentError as ee:
        logging.error(f"Environment error: {ee}")
        print(f"Environment error: {ee}")
    except Exception as e:
        logging.error(f"Error: {e}")
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")


if __name__ == "__main__":
    main()
