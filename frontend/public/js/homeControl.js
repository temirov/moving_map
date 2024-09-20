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
            this.map.fire('click', this._container); // Emit a click event for button styling (optional)
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
export const homeControl = new HomeControl();
