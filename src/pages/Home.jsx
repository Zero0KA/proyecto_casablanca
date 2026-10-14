import { Link } from 'react-router-dom'
import heroImage from '../assets/casablanca-hero.jpg'

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

function Home() {
  return (
    <div className="home">
      <section
        className="hero"
        aria-labelledby="hero-title"
        style={{ '--hero-image': `url(${heroImage})` }}
      >
        <div className="hero-overlay" aria-hidden="true" />

        <div className="section-inner hero-grid">
          <div className="hero-copy">
            <p className="hero-kicker">DESCUBRE CASABLANCA</p>

            <h1 id="hero-title">
              Casablanca: El brindis de Chile con el Pacífico
            </h1>

            <p className="hero-subtitle">
              Explora la cultura, el patrimonio y los atractivos de nuestra comuna.
            </p>

            <div className="hero-actions">
              <Link className="btn btn-primary" to="/routes">
                Ver rutas
              </Link>

              <Link className="btn btn-secondary" to="/map">
                Abrir el mapa
              </Link>
            </div>
          </div>
        </div>
      </section>

      <section className="section access-section" aria-labelledby="access-title">
        <div className="section-inner">
          <h2 id="access-title">¡Buenas, sibarita!</h2>
          <p className="section-ornament" aria-hidden="true" />
          <p className="section-lead">
            Encuentra lugares de interés y descubre nuevas formas de recorrer Casablanca
          </p>
          <div className="access-grid">
            <Link className="access-card" to="/map">
              <span className="access-icon-wrap earth" aria-hidden="true">
                <MapIcon />
              </span>
              <h3>Mapa</h3>
              <p>Ubica los lugares de interés de Casablanca en el mapa.</p>
            </Link>
            <Link className="access-card" to="/routes">
              <span className="access-icon-wrap olive" aria-hidden="true">
                <PathIcon />
              </span>
              <h3>Rutas</h3>
              <p>Elige un recorrido y sigue sus paradas en orden.</p>
            </Link>
            <Link className="access-card" to="/attractions">
              <span className="access-icon-wrap" aria-hidden="true">
                <LeafIcon />
              </span>
              <h3>Atractivos</h3>
              <p>Descubre lugares de interés cultural, histórico y turístico de la comuna.</p>
            </Link>
          </div>
        </div>
      </section>
    </div>
  )
}

export default Home