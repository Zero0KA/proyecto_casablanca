import { Link } from 'react-router-dom'
import heroImage from '../assets/casablanca-hero.jpg'
import { publicImage, useSession } from '../components/SessionContext'
import RouteOverview from '../components/RouteOverview'
import { routeSummary, withPreview } from '../services/catalogModel.js'
import { useCatalog } from '../hooks/useCatalog'
import CatalogStatus, { PreviewNotice } from '../components/CatalogStatus'
import './Home.css'

export default function Home() {
  const { usuario, error: sessionError } = useSession()
  const state = useCatalog()
  const { catalog, preview } = state
  const highlights = (catalog?.places || []).slice(0, 3)
  const summaries = (catalog?.routes || []).slice(0, 3).map(route => routeSummary(route, preview))
  function showSteps() {
    document.getElementById('como-funciona')?.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
    document.getElementById('steps-title')?.focus({ preventScroll: true })
  }

  return <div className="home home-refresh">
    <section className="welcome-hero" aria-labelledby="hero-title" style={{ '--welcome-photo': `url(${heroImage})` }}>
      <div className="welcome-inner">
        <p className="welcome-eyebrow">CULTURA Y TURISMO</p>
        <h1 id="hero-title">Casablanca</h1>
        <p className="welcome-description">Descubre lugares, recorre rutas y explora Casablanca como prefieras.</p>
        <button className="welcome-secondary" type="button" onClick={showSteps}>Cómo funciona <span aria-hidden="true">↓</span></button>
      </div>
    </section>

    {usuario && !sessionError && <aside className="home-account home-container" aria-label="Tu cuenta">
      <div><p className="home-eyebrow">TU CUENTA</p><h2>Hola, {usuario.nombre}</h2></div>
      <Link className="home-link" to="/profile">Mis recorridos <span aria-hidden="true">→</span></Link>
    </aside>}

    <div className="home-container"><PreviewNotice preview={preview} /><CatalogStatus {...state} /></div>
    <section className="home-discover home-container" aria-labelledby="places-title">
      <div className="home-section-heading"><div><p className="home-eyebrow">CULTURA Y PATRIMONIO</p><h2 id="places-title">Atractivos</h2></div><Link className="home-link" to={withPreview('/attractions', preview)}>Todos los atractivos</Link></div>
      {catalog && !highlights.length && <p>No hay atractivos disponibles en este momento.</p>}
      <div className="home-places">{highlights.map((place, index) => <article className="home-place" key={place.id}>
        <Link to={withPreview(`/attractions/${place.id}`, preview)} className="home-place-link">
          <div className="home-place-image">{publicImage(place.image) && <img src={publicImage(place.image)} alt="" loading="lazy" decoding="async" width="640" height="480" />}<span className="home-place-number" aria-hidden="true">0{index + 1}</span></div>
          <div className="home-place-copy"><h3>{place.name}</h3><p>{place.description}</p><span className="home-link">Ver detalle <span aria-hidden="true">↗</span></span></div>
        </Link>
      </article>)}</div>
    </section>

    <section className="home-route-section" aria-labelledby="route-title"><div className="home-container home-routes-summary">
      <div className="home-section-heading"><div><p className="home-eyebrow">RECORRIDOS</p><h2 id="route-title">Rutas</h2></div><Link className="home-link" to={withPreview('/routes', preview)}>Todas las rutas</Link></div>
      {catalog && !summaries.length && <p>No hay rutas disponibles en este momento.</p>}
      <div className="route-overview-list">{summaries.map((route, index) => <RouteOverview key={route.key} route={route} position={index} />)}</div>
    </div></section>

    <section id="como-funciona" className="home-steps home-container" aria-labelledby="steps-title">
      <div className="home-section-heading"><h2 id="steps-title" tabIndex={-1}>De la curiosidad al recorrido</h2></div>
      <ol className="home-step-list"><li><span className="home-step-number" aria-hidden="true">01</span><h3>Descubre un lugar</h3><p>Consulta las fichas de los lugares y el mapa.</p></li><li><span className="home-step-number" aria-hidden="true">02</span><h3>Elige tu ruta</h3><p>Revisa sus paradas y su duración estimada.</p></li><li><span className="home-step-number" aria-hidden="true">03</span><h3>Comienza el recorrido</h3><p>Inicia tu recorrido y consulta el historial en tu cuenta.</p></li></ol>
    </section>
  </div>
}
