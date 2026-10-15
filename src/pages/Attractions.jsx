import { useState } from 'react'
import { Link } from 'react-router-dom'
import { attractions } from '../data/attractions'

function Attractions() {
  const [query, setQuery] = useState('')
  const normalize = value => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('es')
  const visible = attractions.filter(place => normalize(`${place.name} ${place.description}`).includes(normalize(query.trim())))
  return (
    <section className="page attractions-page">
      <header className="page-heading">
        <p className="page-eyebrow">Descubre Casablanca</p>
        <h1>Atractivos turísticos</h1>
        <p className="page-intro">
          Conoce los espacios históricos, culturales y patrimoniales
          que forman parte de la identidad de Casablanca.
        </p>
      </header>

      <div className="attraction-search"><label htmlFor="place-search">¿Qué lugar quieres conocer?</label><div><input id="place-search" type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Busca por nombre o descripción" maxLength={100} />{query && <button type="button" onClick={() => setQuery('')}>Limpiar búsqueda</button>}</div><p role="status">{visible.length} {visible.length === 1 ? 'lugar encontrado' : 'lugares encontrados'}</p></div>
      {!visible.length && <p>No encontramos lugares con esa búsqueda. Prueba con otro nombre.</p>}
      <div className="attractions-grid">
        {visible.map((attraction) => (
          <article className="content-card attraction-card" key={attraction.id}>
            <div className="card-media">
              <img
                src={attraction.image}
                alt={attraction.name}
                loading="lazy"
              />
            </div>

            <div className="card-body">
              <h2>{attraction.name}</h2>
              <p>{attraction.description}</p>
              <Link className="btn btn-text" to={`/attractions/${attraction.id}`}>Ver detalle</Link>
            </div>
          </article>
        ))}
      </div>
    </section>
  )
}

export default Attractions
