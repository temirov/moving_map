// Define common paths to avoid repetition
const vectorServer = "https://computercat:8443/pg_tileserv/";
const fontServer = "https://computercat:8443/tileserver/";
const nominatimServer = "https://computercat:8443/nominatim/";

const sourceNames = {
  usCounties: "public.us_counties", // Actual source-layer name for counties
  usCountiesCentroids: "public.us_counties_centroids", // Actual source-layer name for centroids
  weatherStations: "public.test_weather_stations",
  weatherStationsDaysByTempRange: "public.get_ws_days_by_temp_range",
};

const sourceLayers = {
  usCounties: "public.us_counties",
  usCountiesCentroids: "public.us_counties_centroids",
  weatherStations: "weather_stations_layer",
  weatherStationsDaysByTempRange: "ws_stations_layer",
};

// Build the URLs dynamically
const buildTileUrl = (sourceName, props) =>
  `${vectorServer}/${sourceName}/{z}/{x}/{y}.pbf${props}`;

// URL configurations
const vectorUrls = {
  usCounties: buildTileUrl(
    sourceNames.usCounties,
    "?properties=namelsad,aland,awater"
  ),
  usCountiesCentroids: buildTileUrl(
    sourceNames.usCountiesCentroids,
    "?properties=county_name"
  ),
  weatherStations: buildTileUrl(sourceNames.weatherStations, ""),
  weatherStationsDaysByTempRange: buildTileUrl(
    sourceNames.weatherStationsDaysByTempRange,
    ""
  ),
};

// Configuration for map and sources
export const config = {
  fontServer: `${fontServer}/fonts/{fontstack}/{range}.pbf`,
  vectorSources: {
    usCounties: vectorUrls.usCounties,
    usCountiesCentroids: vectorUrls.usCountiesCentroids,
    weatherStations: vectorUrls.weatherStations,
    weatherStationsDaysByTempRange: vectorUrls.weatherStationsDaysByTempRange,
  },
  nominatimServer: {
    url: nominatimServer,
  },
  sourceNames, // Add source names to the config for later use
  sourceLayers, // Add source layers to the config for later use
  usCenter: [-98.5, 39.5],
  usBounds: [
    [-125.0, 24.396308], // Southwest
    [-66.93457, 49.384358], // Northeast
  ],
};

// Map initialization configuration
export const mapConfig = {
  container: "map",
  style: {
    version: 8,
    glyphs: config.fontServer,
    sources: {
      [config.sourceNames.usCounties]: {
        type: "vector",
        tiles: [config.vectorSources.usCounties],
        minzoom: 4,
        maxzoom: 22,
      },
      [config.sourceNames.usCountiesCentroids]: {
        type: "vector",
        tiles: [config.vectorSources.usCountiesCentroids],
        minzoom: 4,
        maxzoom: 22,
      },
      [config.sourceNames.weatherStations]: {
        type: "vector",
        tiles: [config.vectorSources.weatherStations],
        minzoom: 4,
        maxzoom: 22,
      },
      // [config.sourceNames.weatherStationsDaysByTempRange]: {
      //   type: "vector",
      //   tiles: [config.vectorSources.weatherStationsDaysByTempRange],
      //   minzoom: 4,
      //   maxzoom: 22,
      // },
      "carto-light": {
        type: "raster",
        tiles: [
          "https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
          "https://b.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
          "https://c.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
          "https://d.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
        ],
      },
    },
    layers: [
      {
        id: "carto-light-layer",
        source: "carto-light",
        type: "raster",
        minzoom: 4,
        maxzoom: 22,
      },
      {
        id: "us-counties-layer",
        type: "fill",
        source: config.sourceNames.usCounties, // Use the dynamic source name
        "source-layer": config.sourceLayers.usCounties, // Use the source layer from config
        paint: { "fill-color": "#0000ff", "fill-opacity": 0.2 },
      },
      {
        id: "us-counties-label",
        type: "symbol",
        source: config.sourceNames.usCountiesCentroids, // Use the dynamic source name
        "source-layer": config.sourceLayers.usCountiesCentroids, // Use the source layer from config
        minzoom: 8,
        layout: {
          "text-field": ["get", "county_name"],
          "text-font": ["Noto Sans Regular"],
          "text-size": 12,
          "symbol-placement": "point",
          "text-anchor": "center",
        },
        paint: {
          "text-color": "#000000",
          "text-halo-color": "#ffffff",
          "text-halo-width": 1,
        },
      },
      {
        id: "public.test_weather_stations",
        source: config.sourceNames.weatherStations,
        type: "circle",
        "source-layer": config.sourceLayers.weatherStations,
        paint: {
          "circle-radius": 6,
          "circle-color": "red",
        },
        minzoom: 4,
        maxzoom: 22,
      },
      // {
      //   id: "public.get_ws_days_by_temp_range",
      //   source: config.sourceNames.weatherStationsDaysByTempRange,
      //   type: "circle",
      //   "source-layer": config.sourceLayers.weatherStationsDaysByTempRange,
      //   paint: {
      //     "circle-radius": 10,
      //     "circle-color": "red",
      //   },
      //   minzoom: 4,
      //   maxzoom: 22,
      // },
    ],
  },
  center: config.usCenter,
  zoom: 4,
  antialias: true,
  attributionControl: false,
};
