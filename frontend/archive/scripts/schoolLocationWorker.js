importScripts('https://unpkg.com/topojson-client@3'); // Import the TopoJSON client library

self.onmessage = function() {
    fetch('../data/public-school-locations-08-24.topojson')  // Update the path to the TopoJSON file
        .then(response => response.json())
        .then(topoData => {
            // Convert TopoJSON to GeoJSON using the topojson.feature method
            const schoolGeoJSON = topojson.feature(topoData, topoData.objects['public-school-locations-08-24']);
            self.postMessage({ type: 'locations', data: schoolGeoJSON });
        })
        .catch(error => {
            console.error('Error loading school locations:', error);
        });
};
