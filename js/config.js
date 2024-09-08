export const config = {
    fontServer: {
        url: 'http://computercat.tyemirov.lan:8080/',
        path: "fonts/{fontstack}/{range}.pbf"
    },
    tileServer: {
        url: 'http://computercat.tyemirov.lan:8080/data/'
    },
    nominatimServer: {
        url: 'http://computercat.tyemirov.lan:8081/'
    },
    usCenter: [-98.5, 39.5], // Center over the US
    usBounds: [
        [-125.0, 24.396308], // Southwest coordinates [longitude, latitude]
        [-66.93457, 49.384358]  // Northeast coordinates [longitude, latitude]
    ], // Define the bounds as southwest and northeast coordinates for the US
};

// Define tile layers
export const layers = {
    'us-border': {
        source: {
            type: 'vector',
            url: `${config.tileServer.url}us-border.json`
        },
        layer: {
            id: 'us-border-layer',
            type: 'line',
            source: 'us-border',
            'source-layer': 'tl_2023_us_border',
            paint: { 'line-color': '#ff0000', 'line-width': 2 }
        }
    },
    'us-states': {
        source: {
            type: 'vector',
            url: `${config.tileServer.url}us-states.json`
        },
        layer: {
            id: 'us-states-layer',
            type: 'line',
            source: 'us-states',
            'source-layer': 'tl_2023_us_state',
            paint: { 'line-color': '#FF0000', 'line-width': 2, 'line-opacity': 1 }
        }
    },
    'us-states-symbols': {
        source: {
            type: 'vector',
            url: `${config.tileServer.url}us-states.json`
        },
        layer: {
            id: 'us-states-symbols-layer',
            type: 'symbol',
            source: 'us-states',
            'source-layer': 'tl_2023_us_state',
            layout: {
                'text-field': ['get', 'STUSPS'],  // Use state abbreviation
                'text-font': ['Noto Sans Regular'],
                'text-size': 14,
            },
            paint: {
                'text-color': '#000000',
                'text-opacity': 1
            }
        }
    },
    'us-counties': {
        source: {
            type: 'vector',
            url: `${config.tileServer.url}us-counties.json`
        },
        layer: {
            id: 'us-counties-layer',
            type: 'fill',
            source: 'us-counties',
            'source-layer': 'tl_2023_us_county',
            paint: { 'fill-color': '#0000ff', 'fill-opacity': 0.2 }
        }
    }
};
