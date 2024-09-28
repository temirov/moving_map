import { mapConfig, config } from "./mapConfig.js";
import { homeControl } from "./homeControl.js";
import { geolocationControl } from "./geolocationControl.js";
import { geocoderControl } from "./geocoderControl.js";

const map = new maplibregl.Map(mapConfig);

// Handle the 'home' event to define behavior
map.on("home", () => {
  console.log("Home button clicked");
  home(config.usBounds);
});

function home(bounds) {
  map.fitBounds(bounds, {
    padding: 10,
    maxZoom: 4, // Fit the entire US within this zoom level
    duration: 1000,
  });
}

// Initialize NavigationControl control
const navigateControl = new maplibregl.NavigationControl({
  visualizePitch: true,
  showZoom: true,
  showCompass: false,
});

map.on("geolocationError", (e) => {
  console.error("Error obtaining location:", e.error);
});

// Handle the 'geolocationSuccess' event
geolocationControl.on("geolocationSuccess", (position) => {
  // Get user location directly from the event
  const userLocation = [position.coords.longitude, position.coords.latitude];
  console.log("User coordinates: ", userLocation);

  // Ensure the map style has loaded before querying for features
  if (!map.isStyleLoaded()) {
    console.error("Map style not loaded yet.");
    return;
  }

  // Query the map for features (counties) that intersect with user location
  const features = map.querySourceFeatures(config.sourceNames.counties, {
    sourceLayer: config.sourceLayers.usCounties,
  });

  // Look for the county where the user is located
  const foundCounty = features.find((feature) =>
    turf.booleanPointInPolygon(turf.point(userLocation), feature)
  );

  if (foundCounty) {
    console.log("User is in county:", foundCounty.properties);

    // Get the bounding box of the found county
    const countyBbox = turf.bbox(foundCounty);

    // Zoom to the county by fitting the bounding box
    map.fitBounds(countyBbox, {
      padding: 20,
      maxZoom: 12, // Limit zoom level
      duration: 1000, // Set zoom duration
    });
  } else {
    console.log("No county found for this location.");
  }
});

map.on("load", () => {
  if (
    !map.getSource("us_counties") ||
    !map.getSource("us_counties_centroids")
  ) {
    console.error("Vector source not found or failed to load");
  }

  // Add top-left custom controls (Home, Geolocate, Search)
  map.addControl(homeControl, "top-left");
  // Add GeolocationControl to the map
  map.addControl(geolocationControl, "top-left");
  // Add the Navigation Control for zooming on the top-right
  map.addControl(navigateControl, "top-right");
  map.addControl(geocoderControl, "top-right");

  home(config.usBounds);
});

// Handle map errors
map.on("error", (e) => {
  console.error("Map error: ", e.error);
});
