function MapPage() {
  return (
    <section className="page map-page">
      <header className="page-heading">
        <p className="page-eyebrow">Ubica los lugares</p>
        <h1>Mapa</h1>
        <p className="page-intro">
          Aquí verás dónde está cada atractivo de Casablanca.
        </p>
      </header>

      <div className="map-frame">
        <div
          className="media-placeholder map-placeholder"
          role="img"
          aria-label="Espacio reservado para el mapa interactivo de Casablanca"
        >
          <span>Mapa interactivo: próximamente</span>
        </div>
      </div>
    </section>
  )
}

export default MapPage