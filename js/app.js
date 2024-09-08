import { config, layers } from './config.js';
import { topLeftControl } from './topLeftControl.js';

// Initialize the map
const map = new maplibregl.Map({
    container: 'map',
    style: {
        version: 8,
        sources: {},
        layers: [],
        glyphs: `${config.fontServer.url}${config.fontServer.path}`
    },
    center: config.usCenter,
    zoom: 4,
    antialias: true
});

// Handle the 'home' event to define behavior
map.on('home', () => {
    console.log('Home button clicked');
    home(config.usBounds);
});

function home(bounds) {
    map.fitBounds(bounds, {
        padding: 10,
        maxZoom: 4, // Fit the entire US within this zoom level
        duration: 1000
    });
};

// Update layers based on checkbox status
function updateLayers() {
    Object.keys(layers).forEach(key => {
        const checkbox = document.getElementById(key);
        if (checkbox.checked) {
            try {
                if (!map.getSource(layers[key].layer.source)) {
                    map.addSource(layers[key].layer.source, layers[key].source);
                }
                if (!map.getLayer(layers[key].layer.id)) {
                    map.addLayer(layers[key].layer);
                }
            } catch (error) {
                console.error(`Error adding ${key}:`, error);
            }
        } else {
            try {
                if (map.getLayer(layers[key].layer.id)) {
                    map.removeLayer(layers[key].layer.id);
                }
                if (map.getSource(layers[key].layer.source)) {
                    map.removeSource(layers[key].layer.source);
                }
            } catch (error) {
                console.error(`Error removing ${key}:`, error);
            }
        }
    });
}

// Attach event listeners to checkboxes
document.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
    checkbox.addEventListener('change', updateLayers);
});

// Initialize NavigationControl control
const navigateControl = new maplibregl.NavigationControl({
    visualizePitch: true,
    showZoom: true,
    showCompass: false,
});

// When the map is fully loaded, initialize geolocate control and add it to the map
map.on('load', () => {
    // Add top-left custom controls (Home, Geolocate, Search)
    map.addControl(topLeftControl, 'top-left');
    // Add the Navigation Control for zooming on the top-right
    map.addControl(navigateControl, 'top-right');
    updateLayers();
});

// Handle map errors
map.on('error', (e) => {
    console.error('Map error: ', e.error);
});
