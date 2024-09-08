let userLocation = null; // Variable to store user location

// Function to initialize the geolocate control with a passed map object
export const initGeolocateControl = (map) => {
    const geolocateControl = new maplibregl.GeolocateControl({
        positionOptions: {
            enableHighAccuracy: true
        },
        trackUserLocation: false, // Enable tracking to show user location
        showUserLocation: true, // Display user's location with default styling
        fitBoundsOptions: false // Disable automatic zoom
    });

    // Return the geolocate control so it can be added to the map
    return geolocateControl;
};

// Add event listener to trigger geolocation when the button is clicked
export const setupGeolocateEvent = (map, geolocateControl) => {
    geolocateControl.on('geolocate', function (position) {
        // Store the user location
        userLocation = [position.coords.longitude, position.coords.latitude];
        console.log('User coordinates: ', userLocation);

        // Check if map is loaded
        if (map.isStyleLoaded()) {
            // Query the source for the county that the user is located in
            const features = map.querySourceFeatures('us-counties', {
                sourceLayer: 'tl_2023_us_county'
            });

            let foundCounty = null;

            for (const feature of features) {
                if (turf.booleanPointInPolygon(turf.point(userLocation), feature)) {
                    foundCounty = feature;
                    break;
                }
            }

            if (foundCounty) {
                console.log('User is in county:', foundCounty.properties);

                // Zoom to the county by fitting the bounding box
                const countyBbox = turf.bbox(foundCounty);
                map.fitBounds(countyBbox, {
                    padding: 20,
                    maxZoom: 12, // Limit zoom level
                    duration: 1000
                });
            } else {
                console.log('No county found for this location.');
            }
        } else {
            console.error('Map style not loaded yet.');
        }
    });
};
