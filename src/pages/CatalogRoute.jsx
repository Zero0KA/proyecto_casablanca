import { Link, useParams } from 'react-router-dom'
import { routeCatalog } from '../data/routeCatalog'
import { coordinatesFor } from '../data/mapLocations'
export default function CatalogRoute() {
  const { id } = useParams()
  const route = /^\d+$/.test(id || '') ? routeCatalog.find(item => item.key === `catalogo-${Number(id)}`) : null
  if (!route) return <section className="page"><Link to="/routes">← Volver a rutas</Link><h1>Ruta no encontrada</h1><p>El recorrido solicitado no está disponible.</p></section>
  return <section className="page catalog-route-page"><Link className="home-link" to="/routes">← Volver a rutas</Link><header className="page-heading"><p className="page-eyebrow">RECORRIDO</p><h1>{route.name}</h1><p className="page-intro">{route.description}</p></header><h2>Lugares del recorrido</h2><ol className="catalog-itinerary">{route.places.map((place, index) => <li key={place.id}><span className="catalog-stop-number" aria-hidden="true">{index + 1}</span><div className="catalog-stop-copy"><h3>{place.name}</h3><p>{place.description}</p><div className="card-actions"><Link className="home-link" to={`/attractions/${place.id}`}>Ver lugar →</Link>{coordinatesFor(place) && <Link className="home-link" to={`/map?lugar=${place.id}`}>Ver ubicación →</Link>}</div></div><img src={place.image} alt="" loading="lazy" width="180" height="130" /></li>)}</ol></section>
}
