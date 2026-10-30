import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import L from 'leaflet'
import { Circle, MapContainer, Marker, Popup, TileLayer, useMap } from 'react-leaflet'
import 'leaflet/dist/leaflet.css'

const center = [-33.3206, -71.4101]
const validCoordinates = stop => Number.isFinite(stop.coordinates?.latitude) && Number.isFinite(stop.coordinates?.longitude) && Math.abs(stop.coordinates.latitude) <= 90 && Math.abs(stop.coordinates.longitude) <= 180
const point = stop => [stop.coordinates.latitude,stop.coordinates.longitude]
function stopIcon(stop, selected) {
  return L.divIcon({ className:`historic-geo-pin${selected ? ' is-selected' : ''}${stop.coordinates.accuracy === 'approximate' ? ' is-approximate' : ''}`,html:`<span>${Number(stop.order)}</span>`,iconSize:[42,42],iconAnchor:[21,21],popupAnchor:[0,-24] })
}
function FocusStops({ stops, selectedKey }) {
  const map = useMap()
  useEffect(() => {
    const selected = stops.find(stop => stop.key === selectedKey)
    if (selected) map.setView(point(selected),17,{ animate:false })
    else if (stops.length) map.fitBounds(stops.map(point),{ padding:[45,45],maxZoom:17,animate:false })
  },[map,stops,selectedKey])
  return null
}
export default function GeographicMap({ route, selectedKey, onSelect }) {
  const [failed,setFailed] = useState(false), [revision,setRevision] = useState(0)
  // La posición del dibujo nunca se convierte en una coordenada geográfica.
  const located = route.stops.filter(validCoordinates)
  const selected = route.stops.find(stop => stop.key === selectedKey)
  return <div className="geographic-map-panel">
    <div className="geo-toolbar"><p><strong>{located.length} paradas en el mapa</strong><span>Selecciona un número o una parada de la lista.</span></p><button className="btn btn-outline" type="button" onClick={() => onSelect(null)}>Ver todas las paradas</button></div>
    <div className="geographic-route-layout"><div>
      <div className="map-frame" role="region" aria-label={`Mapa geográfico de la ruta ${route.name}`}><MapContainer key={revision} className="map-canvas" center={center} zoom={16} scrollWheelZoom={false}>
        <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' maxZoom={19} eventHandlers={{ tileerror:() => setFailed(true) }} />
        <FocusStops stops={located} selectedKey={selectedKey} />
        {located.map(stop => <Marker key={stop.key} position={point(stop)} icon={stopIcon(stop,stop.key === selectedKey)} zIndexOffset={stop.key === selectedKey ? 1000 : 0} title={`${stop.order}. ${stop.name}${stop.coordinates.accuracy === 'approximate' ? ' (ubicación aproximada)' : ''}`} alt={`${stop.order}. ${stop.name}`} eventHandlers={{ click:() => onSelect(stop.key) }}><Popup><strong>{stop.order}. {stop.name}</strong><p>{stop.coordinates.reference || stop.description}</p>{stop.coordinates.accuracy === 'approximate' && <p className="geo-approximate-label">Ubicación aproximada</p>}{stop.attractionId && <Link to={`/attractions/${stop.attractionId}`}>Ver lugar</Link>}</Popup></Marker>)}
        {selected?.coordinates?.accuracy === 'approximate' && validCoordinates(selected) && <Circle center={point(selected)} radius={90} pathOptions={{color:'#a45d2d',fillColor:'#d8ac58',fillOpacity:0.12,weight:1,dashArray:'5 5'}} />}
      </MapContainer></div>
      {failed && <p className="map-note" role="status">No se pudo cargar parte del mapa. La lista de paradas sigue disponible. <button type="button" onClick={() => { setFailed(false);setRevision(value => value + 1) }}>Reintentar mapa</button></p>}
      <p className="geo-map-legend"><span className="geo-legend-point" aria-hidden="true" />Paradas del recorrido <span className="geo-legend-point approximate" aria-hidden="true" />Ubicación aproximada</p>
      {selected && <section className="geo-selected-detail" aria-live="polite"><p className="page-eyebrow">PARADA {selected.order}</p><h2>{selected.name}</h2><p>{selected.description}</p><p>{selected.coordinates?.reference}</p>{selected.coordinates?.accuracy === 'approximate' && <p className="geo-approximate-label">Ubicación aproximada</p>}{!validCoordinates(selected) && <p>Sin ubicación geográfica disponible.</p>}{selected.attractionId && <Link to={`/attractions/${selected.attractionId}`}>Ver lugar</Link>}</section>}
    </div><nav className="geo-stops-panel" aria-label="Paradas del Casco Histórico"><h2>Las doce paradas</h2><ol>{route.stops.map(stop => <li key={stop.key}><button type="button" aria-pressed={stop.key === selectedKey} onClick={() => onSelect(stop.key)}><span className="geo-list-number" aria-hidden="true">{stop.order}</span><span>{stop.name}{stop.coordinates?.accuracy === 'approximate' && <small>Ubicación aproximada</small>}{!validCoordinates(stop) && <small>Sin ubicación</small>}</span></button></li>)}</ol></nav></div>
  </div>
}
