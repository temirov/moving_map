class GeolocationControl {
  constructor() {
    this.eventHandlers = {}; // Store event handlers
  }

  onAdd(map) {
    this.map = map;
    this._container = document.createElement("div");
    this._container.className = "maplibregl-ctrl maplibregl-ctrl-group";
    this._container.innerHTML = `
          <button class="maplibre-gl-home">
              <i class="fas fa-location-arrow"></i>
          </button>`;
    this._container.querySelector("button").onclick = () => {
      this.map.fire("click", this._container); // Emit a click event for button styling (optional)
      this.getUserLocation();
    };

    return this._container;
  }

  onRemove() {
    this._container.parentNode.removeChild(this._container);
    this.map = undefined;
  }

  // Method to add event listeners
  on(event, callback) {
    this.eventHandlers[event] = callback;
  }

  // Method to remove event listeners
  off(event) {
    delete this.eventHandlers[event];
  }

  getUserLocation() {
    const button = this._container.querySelector("button");
    button.disabled = true; // Disable button while retrieving location

    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const userLat = position.coords.latitude;
          const userLng = position.coords.longitude;
          console.log(`User's Location: Lat: ${userLat}, Lng: ${userLng}`);

          this.map.fire("geolocationSuccess", position);

          // Execute any custom handler if defined
          if (this.eventHandlers["geolocationSuccess"]) {
            this.eventHandlers["geolocationSuccess"](position);
          }

          button.disabled = false; // Re-enable the button
        },
        (error) => {
          console.error("Error retrieving location:", error.message);
          this.map.fire("geolocationError", { error: error.message });

          // Execute any custom handler if defined
          if (this.eventHandlers["geolocationError"]) {
            this.eventHandlers["geolocationError"](error);
          }

          button.disabled = false; // Re-enable the button
        },
        { timeout: 30000, enableHighAccuracy: true, maximumAge: 75000 }
      );
    } else {
      console.error("Geolocation is not available in this browser.");
      this.map.fire("geolocationError", { error: "Geolocation not supported" });

      // Execute any custom handler if defined
      if (this.eventHandlers["geolocationError"]) {
        this.eventHandlers["geolocationError"]({
          error: "Geolocation not supported",
        });
      }
      button.disabled = false; // Re-enable the button
    }
  }
}

// Export the custom controls
export const geolocationControl = new GeolocationControl();
