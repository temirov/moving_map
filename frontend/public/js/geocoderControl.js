import { config } from "./mapConfig.js";

const geocoderConfig = {
  forwardGeocode: async (queryConfig) => {
    const features = [];
    try {
      const request = `${config.nominatimServer.url}search?q=${queryConfig.query}&format=geojson&polygon_geojson=1&addressdetails=1`;
      const response = await fetch(request);
      const geojson = await response.json();

      geojson.features.forEach((feature) => {
        const center = [
          feature.bbox[0] + (feature.bbox[2] - feature.bbox[0]) / 2,
          feature.bbox[1] + (feature.bbox[3] - feature.bbox[1]) / 2,
        ];

        features.push({
          type: "Feature",
          geometry: {
            type: "Point",
            coordinates: center,
          },
          place_name: feature.properties.display_name,
          properties: feature.properties,
          text: feature.properties.display_name,
          place_type: ["place"],
          center,
        });
      });
    } catch (e) {
      console.error(`Failed to forwardGeocode with error: ${e}`);
    }

    return { features };
  },
  getSuggestions: async (queryConfig) => {
    const suggestions = [];
    try {
      const request = `${config.nominatimServer.url}search?q=${queryConfig.query}&format=json&addressdetails=1&limit=5`;
      const response = await fetch(request);
      const data = await response.json();

      data.forEach((result) => {
        suggestions.push({
          type: "Feature",
          geometry: {
            type: "Point",
            coordinates: [parseFloat(result.lon), parseFloat(result.lat)],
          },
          place_name: result.display_name,
          properties: result,
          text: result.display_name,
          place_type: ["place"],
          center: [parseFloat(result.lon), parseFloat(result.lat)],
        });
      });
    } catch (e) {
      console.error(`Failed to get suggestions with error: ${e}`);
    }
    return { features: suggestions };
  },
};

export const geocoderControl = new MaplibreGeocoder(geocoderConfig, {
  maplibregl: maplibregl,
  minLength: 3, // Minimum characters before triggering suggestions
  limit: 5, // Maximum number of suggestions to show
  debounce: 300, // Delay in ms between keystrokes and suggestions
  flyTo: true, // Fly to location when selected
  placeholder: "Search for a place", // Placeholder text
  zoom: 12, // Initial zoom when selected
  maxResults: 5, // Limit number of results shown
  enableEventLogging: false, // Disable logging
});
