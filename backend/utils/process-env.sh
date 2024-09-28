#!/bin/bash

# Function to check if a file exists
check_file_exists() {
    if [ ! -f "$1" ]; then
        echo "File '$1' not found. Exiting."
        exit 1
    fi
}

# Check if the right number of arguments is provided (2 or 3)
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <input_file> <output_file> [env_file]"
    exit 1
fi

# Assign arguments to variables
INPUT_FILE="$1"
OUTPUT_FILE="$2"
ENV_FILE="${3:-.env}"  # If the third argument is not provided, default to .env

# Check if the input and environment files exist
check_file_exists "$INPUT_FILE"
check_file_exists "$ENV_FILE"

# Load environment variables from the env file and run envsubst
$(grep -v '^#' "$ENV_FILE" | xargs) && envsubst < "$INPUT_FILE" > "$OUTPUT_FILE"

# Check if the output file was created successfully
if [ $? -eq 0 ]; then
    echo "File processed successfully. Output saved to '$OUTPUT_FILE'."
else
    echo "Error processing file."
    exit 1
fi
