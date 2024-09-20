#!/usr/bin/env python3

import os
import csv
import re
import sys


def parse_stations_file(input_file, output_file):
    with open(input_file, "r") as infile, open(output_file, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        for line in infile:
            if line.lower().startswith("us"):
                station_id = line[0:11].strip()
                latitude = line[12:20].strip()
                longitude = line[21:30].strip()
                elevation = line[31:37].strip()
                state = line[38:40].strip()
                rest_of_line = line[41:].strip()

                # Skip if any of the mandatory fields are missing
                if not (station_id and latitude and longitude and elevation and state):
                    continue

                # Process rest_of_line to extract location_description, distance, direction
                parts = rest_of_line.split()
                location_description = ""
                distance = ""
                direction = ""

                # Check if the last two parts could be distance and direction
                if (
                    len(parts) >= 2
                    and re.match(r"^\d+(\.\d+)?$", parts[-2])
                    and re.match(r"^[NESW]{1,3}$", parts[-1])
                ):
                    distance = parts[-2]
                    direction = parts[-1]
                    location_description = " ".join(parts[:-2])
                else:
                    location_description = " ".join(parts)

                # Truncate location_description to 100 characters and remove problematic characters
                location_description = (
                    location_description.replace(",", "").replace('"', "").strip()
                )
                location_description = location_description[:100]

                # Write the row to CSV
                writer.writerow(
                    [
                        station_id,
                        latitude,
                        longitude,
                        elevation,
                        state,
                        location_description,
                        distance if distance else "",
                        direction if direction else "",
                    ]
                )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: parse_stations.py <input_file> <output_file>")
        sys.exit(1)

    INPUT_FILE = sys.argv[1]
    OUTPUT_FILE = sys.argv[2]

    if not os.path.exists(INPUT_FILE):
        print(f"Error: Input file '{INPUT_FILE}' does not exist.")
        sys.exit(1)

    parse_stations_file(INPUT_FILE, OUTPUT_FILE)
    print(f"CSV file generated at '{OUTPUT_FILE}'.")
