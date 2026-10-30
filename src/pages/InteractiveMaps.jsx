import { Link } from 'react-router-dom'
import './MapPage.css'

export default function InteractiveMaps() {
  return <section className="page interactive-maps-page"><header className="page-heading"><p className="page-eyebrow">EXPLORA LOS RECORRIDOS</p><h1>Mapas interactivos</h1><p className="page-intro">Consulta el mapa de cada recorrido y sus paradas.</p></header>
    <article className="interactive-map-card"><Link className="interactive-map-image" to="/mapas/casco-historico" aria-label="Abrir mapa del Casco Histórico"><img src={`${import.meta.env.BASE_URL}maps/casco-historico.svg`} alt="Ilustración del centro de Casablanca" /></Link><div><p className="page-eyebrow">CIRCUITO PATRIMONIAL</p><h2>Casco Histórico</h2><p>Doce paradas por las plazas, casas y espacios culturales del centro de Casablanca.</p><p className="interactive-map-types">Vista ilustrada · Vista geográfica</p><Link className="btn btn-primary" to="/mapas/casco-historico">Abrir mapa <span aria-hidden="true">↗</span></Link></div></article>
  </section>
}
