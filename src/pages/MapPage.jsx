import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import L from 'leaflet'
import { MapContainer, Marker, Popup, TileLayer, useMap } from 'react-leaflet'
import 'leaflet/dist/leaflet.css'
import './MapPage.css'
import { attractions } from '../data/attractions'
import { coordinatesFor } from '../data/mapLocations'

const center = [-33.3206, -71.4101]
const pin = L.divIcon({ className: 'leaflet-pin', html: '<span></span>', iconSize: [36, 36], iconAnchor: [18, 18], popupAnchor: [0, -20] })
const located = attractions.map(item => ({ ...item, coords: coordinatesFor(item) })).filter(item => item.coords)

function FocusPlace({ placeId }) {
  const map = useMap()
  useEffect(() => {
    const place = located.find(item => String(item.id) === placeId)
    map.setView(place?.coords || center, 16, { animate: false })
  }, [map, placeId])
  return null
}

export default function MapPage() {
  const [params] = useSearchParams()
  const [failed, setFailed] = useState(false)
  const [revision, setRevision] = useState(0)
  return <section className="page map-page">
    <header className="page-heading">
      <p className="page-eyebrow">Ubica los lugares</p><h1>Mapa</h1>
      <p className="page-intro">Selecciona un punto para conocer el lugar y abrir su detalle.</p>
    </header>
    <div className="map-frame" role="region" aria-label="Mapa de Casablanca">
      <MapContainer key={revision} className="map-canvas" center={center} zoom={16} scrollWheelZoom={false}>
        <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          maxZoom={19} eventHandlers={{ tileerror: () => setFailed(true) }} />
        <FocusPlace placeId={params.get('lugar')} />
        {located.map(item => <Marker key={item.id} position={item.coords} icon={pin} title={item.name} alt={item.name}>
          <Popup><strong>{item.name}</strong><br /><Link to={`/attractions/${item.id}`}>Ver detalle</Link></Popup>
        </Marker>)}
      </MapContainer>
    </div>
    {failed && <p className="map-note" role="status">No se pudo cargar parte del mapa. Puedes consultar los lugares de la lista.{' '}
      <button type="button" onClick={() => { setFailed(false); setRevision(value => value + 1) }}>Reintentar mapa</button>
    </p>}
    <h2>Lugares señalados</h2>
    {located.length ? <ul className="map-place-list">{located.map(item => <li key={item.id}>
      <Link to={`/attractions/${item.id}`}>{item.name}</Link>
    </li>)}</ul> : <p>No hay ubicaciones disponibles.</p>}
  </section>
}
