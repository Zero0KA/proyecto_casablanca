import { Link } from 'react-router-dom'
import { publicImage } from '../components/SessionContext'
import CatalogStatus, { PreviewNotice } from '../components/CatalogStatus'
import { useCatalog } from '../hooks/useCatalog'
import { routeMapUrl } from '../services/catalogModel.js'
import './MapPage.css'

export default function InteractiveMaps() {
  const state = useCatalog()
  return <section className="page interactive-maps-page"><header className="page-heading"><p className="page-eyebrow">EXPLORA LOS RECORRIDOS</p><h1>Mapas interactivos</h1><p className="page-intro">Consulta el mapa de cada recorrido y sus paradas.</p></header>
    <PreviewNotice preview={state.preview} /><CatalogStatus {...state} />
    {state.catalog && !state.catalog.routes.length && <p>No hay mapas de rutas disponibles en este momento.</p>}
    {state.catalog?.routes.map(route => <article className="interactive-map-card" key={route.id}>
      {publicImage(route.image) && <Link className="interactive-map-image" to={routeMapUrl(route.id, state.preview)} aria-label={`Abrir mapa de ${route.name}`}><img src={publicImage(route.image)} alt={route.imageAlt || ''} loading="lazy" /></Link>}
      <div><p className="page-eyebrow">MAPA DEL RECORRIDO</p><h2>{route.name}</h2><p>{route.description}</p><p>{route.stops.length} {route.stops.length === 1 ? 'parada' : 'paradas'}</p><p className="interactive-map-types">{route.illustrated ? 'Vista ilustrada · Vista geográfica' : 'Vista geográfica'}</p><Link className="btn btn-primary" to={routeMapUrl(route.id, state.preview)}>Abrir mapa</Link></div>
    </article>)}
  </section>
}
