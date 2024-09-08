import { initGeolocateControl, setupGeolocateEvent } from './geolocateControl.js';
import { config } from './config.js';  // Import config to use nominatimServer

// Create and Add Home Button with a Font Awesome Home Icon
class HomeControl {
    onAdd(map) {
        this.map = map;
        this._container = document.createElement('div');
        this._container.className = 'maplibregl-ctrl maplibregl-ctrl-group';
        this._container.innerHTML = `
        <button class="maplibre-gl-home">
            <i class="fas fa-home"></i>
        </button>`;
        this._container.querySelector('button').onclick = () => {
            this.map.fire('home'); // Emit 'home' event when clicked
        };
        return this._container;
    }

    onRemove() {
        this._container.parentNode.removeChild(this._container);
        this.map = undefined;
    }
}

// Initialize HomeControl control
const homeControl = new HomeControl();

// Initialize Geocoder control
const geocoderControl = new MaplibreGeocoder({
    forwardGeocode: async (queryConfig) => {
        const features = [];
        try {
            const request = `${config.nominatimServer.url}search?q=${queryConfig.query}&format=geojson&polygon_geojson=1&addressdetails=1`;
            const response = await fetch(request);
            const geojson = await response.json();

            geojson.features.forEach((feature) => {
                const center = [
                    feature.bbox[0] + (feature.bbox[2] - feature.bbox[0]) / 2,
                    feature.bbox[1] + (feature.bbox[3] - feature.bbox[1]) / 2
                ];

                features.push({
                    type: 'Feature',
                    geometry: {
                        type: 'Point',
                        coordinates: center
                    },
                    place_name: feature.properties.display_name,
                    properties: feature.properties,
                    text: feature.properties.display_name,
                    place_type: ['place'],
                    center
                });
            });
        } catch (e) {
            console.error(`Failed to forwardGeocode with error: ${e}`);
        }

        return { features };
    }
}, { maplibregl });

// Add custom control container for top-left grouping
class TopLeftControls {
    onAdd(map) {
        this.map = map;
        const container = document.createElement('div');
        container.className = 'maplibregl-ctrl maplibregl-ctrl-group';
        container.style.display = 'flex'; // Make sure controls are aligned horizontally

        // Add Home control
        container.appendChild(homeControl.onAdd(map));

        // Add Geolocate control
        const geolocateControl = initGeolocateControl(map);
        container.appendChild(geolocateControl.onAdd(map));

        // Set up the geolocate event handling
        setupGeolocateEvent(map, geolocateControl);

        // Add Geocoder control
        container.appendChild(geocoderControl.onAdd(map));

        return container;
    }

    onRemove() {
        this._container.parentNode.removeChild(this._container);
        this.map = undefined;
    }
}

// Add top-left custom controls (Home, Geolocate, Search)
export const topLeftControl = new TopLeftControls();
