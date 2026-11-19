import { Link, useParams } from 'react-router-dom'
import { publicImage } from '../components/SessionContext'
import CatalogStatus, { PreviewNotice } from '../components/CatalogStatus'
import CategoryIcon from '../components/CategoryIcon'
import { useCatalog } from '../hooks/useCatalog'
import { canonicalAttractionId, routeMapUrl, withPreview } from '../services/catalogModel.js'
import './MapPage.css'

export default function AttractionDetail() {
  const { id } = useParams()
  const state = useCatalog()
  const placeId = canonicalAttractionId(id)
  const place = state.catalog?.places.find(item => item.id === placeId)
  const routes = state.catalog?.routes.filter(route => route.stops.some(stop => stop.attractionId === placeId)) || []
  return <section className="page map-detail-page">
    <Link className="map-detail-back" to={withPreview('/attractions', state.preview)}>Volver a Atractivos</Link>
    <PreviewNotice preview={state.preview} /><CatalogStatus {...state} />
    {state.catalog && !place && <><h1>Atractivo no disponible</h1><p>El lugar solicitado no está disponible para consulta.</p></>}
    {place && <><article className="map-detail-article">
      {publicImage(place.image) && <img className="map-detail-photo" src={publicImage(place.image)} alt={place.imageAlt || place.name} />}
      <div className="map-detail-copy"><h1>{place.name}</h1><p className="catalog-description">{place.description}</p>{place.categories.length > 0 && <ul className="catalog-category-list" aria-label="Categorías">{place.categories.map(item => <li key={item.id}><CategoryIcon code={item.icon} />{item.name}</li>)}</ul>}{place.coordinates && <Link className="btn btn-primary" to={withPreview(`/mapas/atractivos/${place.id}`, state.preview)}>Ver ubicación en el mapa</Link>}</div>
    </article>{routes.length > 0 && <section className="catalog-related"><h2>Rutas que incluyen este lugar</h2><ul>{routes.map(route => <li key={route.id}><Link to={withPreview(`/routes/${route.id}`, state.preview)}>{route.name}</Link><Link to={routeMapUrl(route.id, state.preview)}>Ver mapa</Link></li>)}</ul></section>}</>}
  </section>
}
