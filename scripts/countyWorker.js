self.onmessage = function() {
    fetch('https://raw.githubusercontent.com/plotly/datasets/master/geojson-counties-fips.json')
        .then(response => response.json())
        .then(countiesData => {
            self.postMessage({ type: 'counties', data: countiesData });
        })
        .catch(error => {
            console.error('Error loading counties data:', error);
        });
};
