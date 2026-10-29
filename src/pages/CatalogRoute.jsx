import { Link, useParams } from 'react-router-dom'
import { routeCatalog } from '../data/routeCatalog'
import { attractions } from '../data/attractions'
import { coordinatesFor } from '../data/mapLocations'
import { historicMapUrl } from '../data/historicRoute'
import { useHistoricRoute } from '../hooks/useHistoricRoute'
import { LandmarkIcon } from '../components/HistoricMap'
import './CatalogRoute.css'

export default function CatalogRoute() {
  const { id } = useParams()
  const { route: historic, error, retry } = useHistoricRoute()
  const route = /^\d+$/.test(id || '') ? routeCatalog.find(item => item.key === `catalogo-${Number(id)}`) : null
  if (!route) return <section className="page"><Link to="/routes">← Volver a rutas</Link><h1>Ruta no encontrada</h1><p>El recorrido solicitado no está disponible.</p></section>
  const illustrated = route.illustrated
  const places = illustrated ? historic?.stops || [] : route.places
  return <section className={`page catalog-route-page${illustrated ? ' historic-catalog' : ''}`}>
    <Link className="home-link" to="/routes">← Volver a rutas</Link>
    <header className="page-heading"><p className="page-eyebrow">RECORRIDO</p><h1>{illustrated ? historic?.name || route.name : route.name}</h1><p className="page-intro">{illustrated ? historic?.description || route.description : route.description}</p></header>
    {illustrated && <div className="historic-catalog-banner"><div><p>MAPA DEL RECORRIDO</p><h2>El circuito del Casco Histórico</h2><span>Consulta el orden de las doce paradas en el mapa ilustrado.</span><Link to="/map">Abrir mapa interactivo <span aria-hidden="true">↗</span></Link></div><Link className="historic-catalog-preview" to="/map" aria-label="Abrir mapa ilustrado del Casco Histórico"><img src={`${import.meta.env.BASE_URL}maps/casco-historico.svg`} alt="Ilustración del centro de Casablanca" /></Link></div>}
    {illustrated && error ? <p role="alert">No se pudo cargar el recorrido. <button type="button" onClick={retry}>Reintentar</button></p> : illustrated && !historic ? <p role="status">Cargando paradas…</p> : <><h2>{illustrated ? 'Las doce paradas del recorrido' : 'Lugares del recorrido'}</h2><ol className="catalog-itinerary">{places.map((place, index) => {
      const attraction = illustrated ? attractions.find(item => item.id === place.attractionId) : place
      const image = attraction?.image
      return <li key={place.key || place.id}><span className="catalog-stop-number" aria-hidden="true">{place.order || index + 1}</span><div className="catalog-stop-copy">{illustrated && <p className="catalog-stop-kind">{place.kind}</p>}<h3>{place.name}</h3><p>{place.description}</p><div className="card-actions">{attraction && <Link className="home-link" to={`/attractions/${attraction.id}`}>Ver lugar →</Link>}{illustrated ? <Link className="home-link" to={historicMapUrl(place.key)}>Ver en el mapa →</Link> : coordinatesFor(place) && <Link className="home-link" to={`/map?lugar=${place.id}`}>Ver ubicación →</Link>}</div></div>{image ? <img src={image} alt="" loading="lazy" width="180" height="130" /> : <div className="catalog-landmark-art"><LandmarkIcon symbol={place.symbol} /></div>}</li>
    })}</ol></>}
  </section>
}
