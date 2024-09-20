// scripts/stateWorker.js

self.onmessage = function() {
    fetch('https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json')
        .then(response => response.json())
        .then(statesData => {
            self.postMessage({ type: 'states', data: statesData });
        })
        .catch(error => {
            console.error('Error loading states:', error);
        });
};
