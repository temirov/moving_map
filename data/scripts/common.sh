# Exit immediately if a command exits with a non-zero status
set -e

# Function to check if a file exists
check_file_exists() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        echo "Error: Required file not found at $file_path"
        exit 1
    fi
}

check_folder_exists() {
    local folder_path="$1"
    # Check if data folder exists
    if [ ! -d "$folder_path" ]; then
        echo "Error: folder '$folder_path' does not exist."
        exit 1
    fi
}

# Function to execute SQL commands
execute_sql() {
    local sql_command="$1"
    docker run --rm \
        --env-file "$ENV_FILE" \
        -e SQL_COMMAND="$sql_command" \
        -e host_ip="$host_ip" \
        $DOCKER_IMAGE \
        sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -h $host_ip -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c "$SQL_COMMAND"'
}

# Define common variables
ENV_FILE="../../.env"
DOCKER_IMAGE="postgis:utils"  # You can also define this here if it's common across scripts
# Determine the host machine's IP address
host_ip=$(hostname -I | awk '{print $1}')

# Check if the .env file exists
check_file_exists "$ENV_FILE"
