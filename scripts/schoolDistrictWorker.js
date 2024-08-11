// schoolDistrictWorker.js

// Import the TopoJSON library
importScripts('https://unpkg.com/topojson-client@3');

// Now you can use topojson in this worker
self.onmessage = function() {
    fetch('/data/school_boundaries.topojson')
        .then(response => response.json())
        .then(topoData => {
            // Use TopoJSON to convert it to GeoJSON
            const schoolGeoJSON = topojson.feature(topoData, topoData.objects['school_boundaries']);
            self.postMessage({ type: 'districts', data: schoolGeoJSON });
        })
        .catch(error => {
            console.error('Error loading school districts:', error);
            self.postMessage({ type: 'error', error: error.message });
        });
};
