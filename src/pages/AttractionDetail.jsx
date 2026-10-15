import { Link, useParams } from 'react-router-dom'
import { attractions } from '../data/attractions'
import { coordinatesFor } from '../data/mapLocations'
import './MapPage.css'

export default function AttractionDetail() {
  const { id } = useParams()
  const attraction = /^\d+$/.test(id || '') ? attractions.find(item => item.id === Number(id)) : null
  if (!attraction) return <section className="page map-detail-page">
    <Link className="map-detail-back" to="/attractions">Volver a Atractivos</Link>
    <h1>Atractivo no encontrado</h1><p>El lugar solicitado no está en este catálogo.</p>
  </section>
  const coords = coordinatesFor(attraction)
  return <section className="page map-detail-page">
    <Link className="map-detail-back" to="/attractions">Volver a Atractivos</Link>
    <p className="demo-notice">Contenido de presentación del catálogo local.</p>
    <article className="map-detail-article">
      <img className="map-detail-photo" src={attraction.image} alt={attraction.name} />
      <div className="map-detail-copy">
        <h1>{attraction.name}</h1><p>{attraction.description}</p>
        {coords ? <Link className="btn btn-primary" to={`/map?lugar=${attraction.id}`}>Ver ubicación en el mapa</Link>
          : <p>La ubicación de este lugar todavía no está disponible en el mapa.</p>}
      </div>
    </article>
  </section>
}
