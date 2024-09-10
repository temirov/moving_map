#!/bin/bash

# Ensure the script stops if any command fails
set -e

# Check if input argument (Shapefile) is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <input_shapefile.shp>"
  exit 1
fi

# Input Shapefile
SHAPEFILE="$1"
BASENAME=$(basename "$SHAPEFILE" .shp)
GEOJSON="${BASENAME}.geojson"
MBTILES="${BASENAME}.mbtiles"

# Dockerized ogr2ogr command to convert Shapefile to GeoJSON
echo "Converting $SHAPEFILE to $GEOJSON using ogr2ogr..."
docker run --rm -v "$(pwd)":/data osgeo/gdal:ubuntu-full-3.6.2 ogr2ogr -f GeoJSON -t_srs EPSG:4326 "/data/$GEOJSON" "/data/$SHAPEFILE"

# Check if GeoJSON conversion was successful
if [ ! -f "$GEOJSON" ]; then
  echo "Error: GeoJSON conversion failed."
  exit 1
fi

echo "GeoJSON conversion successful: $GEOJSON"

# Dockerized tippecanoe command to convert GeoJSON to MBTiles with both minimum and maximum zoom levels
echo "Converting $GEOJSON to $MBTILES using tippecanoe..."
docker run --rm -v "$(pwd)":/data tippecanoe tippecanoe -o "/data/$MBTILES" --force -zg --layer="$BASENAME" --no-simplification "/data/$GEOJSON"

# Check if MBTiles conversion was successful
if [ ! -f "$MBTILES" ]; then
  echo "Error: MBTiles conversion failed."
  exit 1
fi

echo "MBTiles conversion successful: $MBTILES"
