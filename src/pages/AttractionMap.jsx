import { lazy, Suspense } from 'react'
import { Link, useParams } from 'react-router-dom'
import CatalogStatus, { PreviewNotice } from '../components/CatalogStatus'
import { useCatalog } from '../hooks/useCatalog'
import { canonicalAttractionId, withPreview } from '../services/catalogModel.js'
import './MapPage.css'

const GeographicMap = lazy(() => import('../components/GeographicMap'))
export default function AttractionMap() {
  const { id } = useParams(), state = useCatalog()
  const place = state.catalog?.places.find(item => item.id === canonicalAttractionId(id))
  const route = place ? { name: place.name, stops: [{ ...place, key: place.id, order: 1, attractionId: place.id }] } : null
  return <section className="page map-page"><Link className="historic-breadcrumb" to={withPreview(`/attractions/${canonicalAttractionId(id) || ''}`, state.preview)}>Volver al atractivo</Link><PreviewNotice preview={state.preview} /><CatalogStatus {...state} />
    {state.catalog && !place && <><h1>Atractivo no disponible</h1><p>El lugar solicitado no está disponible para consulta.</p></>}
    {place && <><header className="page-heading"><h1>{place.name}</h1><p>{place.description}</p></header><Suspense fallback={<p role="status">Cargando mapa…</p>}><GeographicMap route={route} preview={state.preview} selectedKey={place.id} onSelect={() => {}} /></Suspense></>}
  </section>
}
