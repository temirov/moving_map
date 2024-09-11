# Use the official PostGIS image as the base
FROM postgis/postgis:latest

# Install required utilities, including shp2pgsql
RUN apt-get update && apt-get install -y postgis

# Ensure the image has the latest updates and clean up to reduce size
RUN apt-get upgrade -y && apt-get autoremove -y && apt-get clean
