import { useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { apiFetch, publicImage, useSession } from '../components/SessionContext'
import CatalogStatus, { PreviewNotice } from '../components/CatalogStatus'
import { useCatalog } from '../hooks/useCatalog'
import { canonicalRouteId, routeMapUrl, withPreview } from '../services/catalogModel.js'
import './CatalogRoute.css'

export default function StartRoute({ start = false }) {
  const { id } = useParams(), { usuario } = useSession()
  const state = useCatalog()
  const route = state.catalog?.routes.find(item => item.id === canonicalRouteId(id))
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [journey, setJourney] = useState(null)
  const submitting = useRef(false)
  async function begin() {
    if (submitting.current || state.preview || !route) return
    submitting.current = true; setBusy(true); setError('')
    try {
      const result = await apiFetch(`/rutas/${route.id}/recorridos`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
      setJourney({ routeId: route.id, id: result.recorrido_id })
    } catch (failure) { setError(failure.message) }
    finally { submitting.current = false; setBusy(false) }
  }
  return <section className="page catalog-route-page">
    <Link className="home-link" to={withPreview('/routes', state.preview)}>Volver a rutas</Link>
    <PreviewNotice preview={state.preview} /><CatalogStatus {...state} />
    {state.catalog && !route && <><h1>Ruta no disponible</h1><p>El recorrido solicitado no está disponible para consulta.</p></>}
    {route && <><header className="page-heading"><p className="page-eyebrow">{start ? 'Prepara tu recorrido' : 'RECORRIDO'}</p><h1>{route.name}</h1><p className="page-intro catalog-description">{route.description}</p><p>{route.minutes != null && <>{route.minutes} minutos estimados · </>}{route.stops.length} {route.stops.length === 1 ? 'parada' : 'paradas'}</p></header>
      <div className="catalog-route-actions"><Link className="btn btn-outline" to={routeMapUrl(route.id, state.preview)}>Abrir mapa del recorrido</Link>{state.preview ? <Link className="btn btn-outline" to={`/admin/rutas/${route.id}/paradas`}>Editar paradas</Link> : !start && <Link className="btn btn-primary" to={`/routes/${route.id}/start`}>{usuario ? 'Iniciar recorrido' : 'Iniciar sesión para recorrer'}</Link>}</div>
      <h2>Paradas del recorrido</h2>
      {!route.stops.length && <p>Esta ruta todavía no tiene paradas.</p>}
      <ol className="catalog-itinerary">{route.stops.map(stop => {
        const linkedPlace = state.catalog.places.find(place => place.id === stop.attractionId)
        return <li key={stop.id}><span className="catalog-stop-number" aria-hidden="true">{stop.order}</span><div className="catalog-stop-copy"><h3>{stop.name}</h3><p className="catalog-description">{stop.description}</p><div className="card-actions">{linkedPlace && <Link className="home-link" to={withPreview(`/attractions/${linkedPlace.id}`, state.preview)}>Ver lugar</Link>}<Link className="home-link" to={`${routeMapUrl(route.id, state.preview)}${state.preview ? '&' : '?'}parada=${stop.id}`}>Ver en el mapa</Link></div></div>{publicImage(stop.image) && <img src={publicImage(stop.image)} alt={stop.imageAlt || ''} loading="lazy" width="180" height="130" />}</li>
      })}</ol>
      {error && <p className="cuenta-error" role="alert">{error}</p>}
      {journey?.routeId === route.id ? <div className="success-notice" role="status"><h2>Recorrido iniciado</h2><Link className="btn btn-primary" to="/profile">Ver mis recorridos</Link></div> : start && !state.preview && <div className="route-start"><button className="btn btn-primary" type="button" disabled={busy} onClick={begin}>{busy ? 'Iniciando…' : 'Confirmar inicio del recorrido'}</button></div>}
    </>}
  </section>
}
