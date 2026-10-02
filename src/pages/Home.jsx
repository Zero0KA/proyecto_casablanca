import { useEffect } from 'react'
import { Link } from 'react-router-dom'
import { attractions } from '../data/attractions'
import { routes } from '../data/routes'


function LeafIcon() {
  return (
    <svg className="access-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill="currentColor"
        d="M5 19c8-1 13-8 14-16-8 1-15 6-16 14 2-1 4-1 6 0-3 1-4 2-4 2z"
      />
    </svg>
  )
}

function MapIcon() {
  return (
    <svg className="access-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill="currentColor"
        d="M9 4 3 6.5V20l6-2.5 6 2.5 6-2.5V4l-6 2.5L9 4zm0 2.2 6 2.5V18l-6-2.5V6.2z"
      />
    </svg>
  )
}

function PathIcon() {
  return (
    <svg className="access-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path
        d="M7 5a3 3 0 1 1 0 6 3 3 0 0 1 0-6zm10 8a3 3 0 1 1 0 6 3 3 0 0 1 0-6z"
        fill="currentColor"
      />
      <path
        d="M8.5 11.5l7 5"
        stroke="currentColor"
        strokeWidth="1.8"
        fill="none"
      />
    </svg>
  )
}

function VineWave({ className }) {
  return (
    <div className={className} aria-hidden="true">
      <svg viewBox="0 0 1440 90" preserveAspectRatio="none">
        <path d="M0 48c180 32 320-36 520-20 210 18 280 58 470 18 150-32 290-18 450 16V90H0z" />
      </svg>
    </div>
  )
}

function RouteSketch() {
  return (
    <svg className="route-sketch" viewBox="0 0 200 120" aria-hidden="true">
      <path
        d="M18 88c22-28 38-46 62-48 28-2 36 22 58 20 18-2 32-18 46-32"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.2"
        strokeLinecap="round"
      />
      <circle cx="18" cy="88" r="5" />
      <circle cx="80" cy="40" r="4" />
      <circle cx="184" cy="28" r="5" />
    </svg>
  )
}

function Home() {
  useEffect(() => {
    const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)')
    const mobileQuery = window.matchMedia('(max-width: 800px)')
    const root = document.querySelector('.home')

    if (!root || motionQuery.matches || mobileQuery.matches) {
      return undefined
    }

    const onMove = (event) => {
      const x = (event.clientX / window.innerWidth - 0.5) * 12
      const y = (event.clientY / window.innerHeight - 0.5) * 8
      root.style.setProperty('--parallax-x', `${x}px`)
      root.style.setProperty('--parallax-y', `${y}px`)
    }

    window.addEventListener('mousemove', onMove)
    return () => window.removeEventListener('mousemove', onMove)
  }, [])

  return (
    <div className="home">
      <section className="hero" aria-labelledby="hero-title">
        <div className="hero-layers" aria-hidden="true">
          <div className="hero-glow" />
          <div className="hero-vines" />
          <div className="hero-mist" />
          <span className="drift-leaf leaf-a" />
          <span className="drift-leaf leaf-b" />
          <span className="drift-leaf leaf-c" />
        </div>
        <div className="section-inner hero-grid">
          <div className="hero-copy">
            <p className="hero-kicker">Casablanca</p>
            <h1 id="hero-title">Título principal</h1>
            <p className="hero-subtitle">Subtítulo placeholder</p>
            <div className="hero-actions">
              <Link className="btn btn-primary" to="/attractions">
                Explorar atractivos
              </Link>
              <Link className="btn btn-secondary" to="/routes">
                Explorar rutas
              </Link>
            </div>
          </div>
          <div className="hero-stage">
            <div
              className="media-placeholder hero-visual"
              role="img"
              aria-label="Espacio reservado para una imagen de Casablanca"
            >
              <span>Imagen de naturaleza y patrimonio</span>
            </div>
            <div
              className="hero-character"
              role="img"
              aria-label="Espacio reservado para una ilustración de personaje turístico"
            >
              <span>Ilustración del personaje</span>
            </div>
          </div>
        </div>
        <VineWave className="wave wave-cream" />
      </section>

      <section className="section access-section" aria-labelledby="access-title">
        <div className="section-inner">
          <h2 id="access-title">Accesos principales</h2>
          <p className="section-ornament" aria-hidden="true" />
          <p className="section-lead">Descripción placeholder de esta sección.</p>
          <div className="access-grid">
            <Link className="access-card" to="/attractions">
              <span className="access-icon-wrap" aria-hidden="true">
                <LeafIcon />
              </span>
              <h3>Atractivos</h3>
              <p>Descripción placeholder.</p>
            </Link>
            <a className="access-card" href="#mapa">
              <span className="access-icon-wrap earth" aria-hidden="true">
                <MapIcon />
              </span>
              <h3>Mapa</h3>
              <p>Descripción placeholder.</p>
            </a>
            <Link className="access-card" to="/routes">
              <span className="access-icon-wrap olive" aria-hidden="true">
                <PathIcon />
              </span>
              <h3>Rutas</h3>
              <p>Descripción placeholder.</p>
            </Link>
          </div>
        </div>
      </section>

      <section className="section section-alt" aria-labelledby="attractions-title">
        <VineWave className="wave wave-top wave-alt" />
        <div className="section-inner">
          <h2 id="attractions-title">Atractivos</h2>
          <p className="section-ornament" aria-hidden="true" />
          <p className="section-lead">Descripción placeholder de esta sección.</p>
          <div className="card-grid">
            {attractions.map((attraction) => (
              <article className="content-card ticket-card" key={attraction.id}>
                <div
                  className="media-placeholder card-media"
                  role="img"
                  aria-label={`Imagen de ${attraction.name}`}
                >
                  {attraction.image ? (
                    <img src={attraction.image} alt={attraction.name} />
                  ) : (
                    <span>Imagen</span>
                  )}
                </div>
                <div className="card-body">
                  <h3>{attraction.name}</h3>
                  <p>{attraction.description}</p>
                  <Link className="btn btn-text" to="/attractions">
                    Consultar detalle
                  </Link>
                </div>
              </article>
            ))}
          </div>
          <div className="section-cta">
            <Link className="btn btn-primary" to="/attractions">
              Ver todos los atractivos
            </Link>
          </div>
        </div>
      </section>

      <section className="section map-section" id="mapa" aria-labelledby="map-title">
        <VineWave className="wave wave-top wave-forest" />
        <div className="section-inner">
          <h2 id="map-title">Mapa</h2>
          <p className="section-ornament gold" aria-hidden="true" />
          <p className="section-lead">
            Espacio reservado para el mapa interactivo, sus marcadores y la
            interacción futura.
          </p>
          <div className="map-frame">
            <span className="map-pin pin-a" aria-hidden="true" />
            <span className="map-pin pin-b" aria-hidden="true" />
            <span className="map-pin pin-c" aria-hidden="true" />
            <div
              className="media-placeholder map-placeholder"
              role="img"
              aria-label="Contenedor reservado para el mapa interactivo de Casablanca"
            >
              <span>Mapa interactivo — próximo</span>
            </div>
          </div>
          <div className="section-cta">
            <a className="btn btn-primary" href="#mapa">
              Explorar el mapa
            </a>
          </div>
        </div>
      </section>

      <section className="section routes-section" aria-labelledby="routes-title">
        <VineWave className="wave wave-top wave-cream" />
        <div className="section-inner">
          <h2 id="routes-title">Rutas autoguiadas</h2>
          <p className="section-ornament" aria-hidden="true" />
          <p className="section-lead">Descripción placeholder de esta sección.</p>
          <div className="card-grid routes-grid">
            {routes.map((route) => (
              <article className="content-card route-card" key={route.id}>
                <div
                  className="media-placeholder card-media earth-media"
                  role="img"
                  aria-label={`Espacio reservado para la imagen de la ruta ${route.name}`}
                >
                  <RouteSketch />
                  <span>Imagen</span>
                </div>
                <div className="card-body">
                  <h3>Ruta {route.name}</h3>
                  <p>Ruta turistica autoguiada de Casablanca</p>
                  <p className="card-meta">
                    {route.attractionIds.length} atractivos
                  </p>
                  <Link className="btn btn-text" to="/routes">
                    Explorar la ruta
                  </Link>
                </div>
              </article>
            ))}
          </div>
          <div className="section-cta">
            <Link className="btn btn-primary" to="/routes">
              Ver todas las rutas
            </Link>
          </div>
        </div>
      </section>
    </div>
  )
}

export default Home
