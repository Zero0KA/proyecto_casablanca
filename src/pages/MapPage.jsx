import { lazy, Suspense } from 'react'
import { Link, useParams, useSearchParams } from 'react-router-dom'
import { historicDatabaseRouteId } from '../data/catalogBindings.js'
import { useCatalog } from '../hooks/useCatalog'
import { canonicalRouteId, selectedStopKey, withPreview } from '../services/catalogModel.js'
import CatalogStatus, { PreviewNotice } from '../components/CatalogStatus'
import './MapPage.css'

const HistoricMap = lazy(() => import('../components/HistoricMap'))
const GeographicMap = lazy(() => import('../components/GeographicMap'))

export default function MapPage() {
  const { id } = useParams(), [params, setParams] = useSearchParams()
  const state = useCatalog()
  const route = state.catalog?.routes.find(item => item.id === (id ? canonicalRouteId(id) : historicDatabaseRouteId))
  const geographical = !route?.illustrated || params.get('vista') === 'geografico'
  const selectedKey = route ? selectedStopKey(route, params.get('parada')) : null
  function update(view, key) {
    const next = { ...(state.preview ? { vista_previa: '1' } : {}), ...(view === 'geografico' ? { vista: 'geografico' } : {}), ...(key ? { parada: key } : {}) }
    setParams(next, { replace: true, preventScrollReset: true })
  }
  return <section className="page map-page">
    <Link className="historic-breadcrumb" to={withPreview('/mapas', state.preview)}>Mapas interactivos</Link>
    <PreviewNotice preview={state.preview} /><CatalogStatus {...state} />
    {state.catalog && !route && <><h1>Mapa no disponible</h1><p>El recorrido solicitado no está disponible para consulta.</p></>}
    {route && <><header className="historic-page-heading"><div><p className="page-eyebrow">MAPA DEL RECORRIDO</p><h1>{route.name}</h1><p className="page-intro">{route.description}</p></div>{route.illustrated && <div className="historic-view-switch" role="group" aria-label="Tipo de mapa"><button type="button" aria-pressed={!geographical} onClick={() => update('ilustrado', selectedKey)}>Ilustrado</button><button type="button" aria-pressed={geographical} onClick={() => update('geografico', selectedKey)}>Geográfico</button></div>}</header>
    <Suspense fallback={<p role="status">Cargando mapa…</p>}>{geographical ? <GeographicMap route={route} preview={state.preview} selectedKey={selectedKey} onSelect={key => update('geografico', key)} /> : <HistoricMap route={route} preview={state.preview} selectedKey={selectedKey} onSelect={key => update('ilustrado', key)} />}</Suspense>
    <div className="catalog-map-actions"><Link className="home-link" to={withPreview(`/routes/${route.id}`, state.preview)}>Ver detalle del recorrido</Link>{state.preview && <Link className="home-link" to={`/admin/rutas/${route.id}/paradas`}>Editar paradas</Link>}</div></>}
  </section>
}
