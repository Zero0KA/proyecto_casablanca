import { useEffect, useState } from 'react'
import RouteOverview from '../components/RouteOverview'
import { routeCatalog, publishedRoute } from '../data/routeCatalog'
import { apiFetch } from '../components/SessionContext'

export default function Routes() {
  const [rutas, setRutas] = useState([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState(false)
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    const controller = new AbortController()
    async function cargar() {
      setCargando(true); setError(false)
      try {
        const lista = await apiFetch('/rutas', { signal: controller.signal })
        if (!Array.isArray(lista)) throw new Error('Respuesta inesperada')
        if (!controller.signal.aborted) setRutas(lista)
      } catch (fallo) {
        if (!controller.signal.aborted && fallo.name !== 'AbortError') { setRutas([]); setError(true) }
      } finally { if (!controller.signal.aborted) setCargando(false) }
    }
    cargar()
    return () => controller.abort()
  }, [revision])
  return <section className="page routes-page">
    <header className="page-heading"><h1>Rutas</h1><p className="page-intro">Consulta los recorridos y sus paradas.</p></header>
    {cargando && <p role="status">Cargando rutas…</p>}
    {error && <p className="cuenta-error" role="alert">No se pudieron actualizar las rutas. <button type="button" onClick={() => setRevision(value => value + 1)}>Reintentar</button></p>}
    <div className="route-overview-list">{[...rutas.map(publishedRoute), ...routeCatalog].map((route, index) => <RouteOverview key={route.key} route={route} position={index} headingLevel={2} />)}</div>
  </section>
}
