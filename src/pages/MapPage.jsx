import { Link, useSearchParams } from 'react-router-dom'
import HistoricMap from '../components/HistoricMap'
import GeographicMap from '../components/GeographicMap'
import { useHistoricRoute } from '../hooks/useHistoricRoute'
import './MapPage.css'

export default function MapPage() {
  const [params, setParams] = useSearchParams()
  const { route, error, retry } = useHistoricRoute()
  const geographical = params.get('vista') === 'geografico' || params.has('lugar')
  const selectedKey = params.get('parada') || (params.has('lugar') ? 'centro_cultural_museo' : null)
  function changeView(value) { setParams({ ...(value === 'geografico' ? { vista: 'geografico' } : {}), ...(selectedKey ? { parada:selectedKey } : {}) }, { replace:true }) }
  function selectStop(key) { setParams({ ...(geographical ? { vista:'geografico' } : {}), ...(key ? { parada:key } : {}) }, { replace:true,preventScrollReset:true }) }
  return <section className="page map-page">
    <header className="historic-page-heading">
      <div><Link className="historic-breadcrumb" to="/mapas">Mapas interactivos <span aria-hidden="true">/</span></Link><p className="page-eyebrow">MAPA DEL RECORRIDO</p><h1>{route?.name || 'Casco Histórico'}</h1><p className="page-intro">Doce paradas para descubrir el patrimonio del centro de Casablanca.</p></div>
      <div className="historic-view-switch" role="group" aria-label="Tipo de mapa"><button type="button" aria-pressed={!geographical} onClick={() => changeView('ilustrado')}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2V5Zm6-2v16m6-14v16" /></svg>Ilustrado</button><button type="button" aria-pressed={geographical} onClick={() => changeView('geografico')}><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c-5 4-5 14 0 18 5-4 5-14 0-18Z" /></svg>Geográfico</button></div>
    </header>
    {error ? <div className="historic-load-error" role="alert"><p>No se pudo cargar el recorrido.</p><button type="button" onClick={retry}>Reintentar</button></div> : route ? geographical ? <GeographicMap route={route} selectedKey={selectedKey} onSelect={selectStop} /> : <HistoricMap route={route} selectedKey={selectedKey} onSelect={selectStop} /> : <p role="status">Cargando mapa…</p>}
  </section>
}
