import RouteOverview from '../components/RouteOverview'
import CatalogStatus, { PreviewNotice } from '../components/CatalogStatus'
import { useCatalog } from '../hooks/useCatalog'
import { routeSummary } from '../services/catalogModel.js'

export default function Routes() {
  const state = useCatalog()
  return <section className="page routes-page">
    <header className="page-heading"><h1>Rutas</h1><p className="page-intro">Consulta los recorridos y sus paradas.</p></header>
    <PreviewNotice preview={state.preview} /><CatalogStatus {...state} />
    {state.catalog && !state.catalog.routes.length && <p>No hay rutas disponibles en este momento.</p>}
    <div className="route-overview-list">{state.catalog?.routes.map((route, index) => <RouteOverview key={route.id} route={routeSummary(route, state.preview)} position={index} headingLevel={2} />)}</div>
  </section>
}
