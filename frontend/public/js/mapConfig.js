// Define common paths to avoid repetition
const vectorServer = "https://computercat:8443/pg_tileserv/";
const fontServer = "https://computercat:8443/tileserver/";

// Define the source layers and source names
const sourceNames = {
  counties: "us_counties", // Source name for counties in the map
  countiesCentroids: "us_counties_centroids", // Source name for centroids
};

const sourceLayers = {
  usCounties: "public.us_counties", // Actual source-layer name for counties
  usCountiesCentroids: "public.us_counties_centroids", // Actual source-layer name for centroids
};

// Build the URLs dynamically
const buildTileUrl = (sourceLayer, props) =>
  `${vectorServer}/${sourceLayer}/{z}/{x}/{y}.pbf${props}`;

// URL configurations
const vectorUrls = {
  usCounties: buildTileUrl(
    sourceLayers.usCounties,
    "?properties=namelsad,aland,awater"
  ),
  usCountiesCentroids: buildTileUrl(
    sourceLayers.usCountiesCentroids,
    "?properties=county_name"
  ),
};

// Configuration for map and sources
export const config = {
  fontServer: `${fontServer}/fonts/{fontstack}/{range}.pbf`,
  vectorSources: {
    usCounties: vectorUrls.usCounties,
    usCountiesCentroids: vectorUrls.usCountiesCentroids,
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
    sources: {
      [sourceNames.counties]: {
        type: "vector",
        tiles: [config.vectorSources.usCounties],
        minzoom: 0,
        maxzoom: 22,
      },
      [sourceNames.countiesCentroids]: {
        type: "vector",
        tiles: [config.vectorSources.usCountiesCentroids],
        minzoom: 0,
        maxzoom: 22,
      },
      'carto-light': {
        'type': 'raster',
        'tiles': [
          "https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
          "https://b.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
          "https://c.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
          "https://d.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png"
        ]
      },
    },
    glyphs: config.fontServer,
    layers: [
      {
        'id': 'carto-light-layer',
        'source': 'carto-light',
        'type': 'raster',
        'minzoom': 0,
        'maxzoom': 22
      },
      {
        id: "us-counties-layer",
        type: "fill",
        source: sourceNames.counties, // Use the dynamic source name
        "source-layer": sourceLayers.usCounties, // Use the source layer from config
        paint: { "fill-color": "#0000ff", "fill-opacity": 0.2 },
      },
      {
        id: "us-counties-label",
        type: "symbol",
        source: sourceNames.countiesCentroids, // Use the dynamic source name
        "source-layer": sourceLayers.usCountiesCentroids, // Use the source layer from config
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
    ],
  },
  center: config.usCenter,
  zoom: 4,
  antialias: true,
  attributionControl: false,
};
