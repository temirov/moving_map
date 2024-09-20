self.onmessage = function() {
    fetch('https://raw.githubusercontent.com/plotly/datasets/master/geojson-counties-fips.json')
        .then(response => response.json())
        .then(countiesData => {
            let batchSize = 100; // Define a batch size for chunked processing
            for (let i = 0; i < countiesData.features.length; i += batchSize) {
                // Slice the batch and send it to the main thread
                let batch = countiesData.features.slice(i, i + batchSize);
                batch.forEach(feature => {
                    self.postMessage({ type: 'county', data: feature });
                });
            }
            self.postMessage({ type: 'complete' });
        })
        .catch(error => {
            self.postMessage({ type: 'error', message: error.message });
        });
};
