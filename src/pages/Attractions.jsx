import { useState } from 'react'
import { Link } from 'react-router-dom'
import { publicImage } from '../components/SessionContext'
import CatalogStatus, { PreviewNotice } from '../components/CatalogStatus'
import CategoryIcon from '../components/CategoryIcon'
import { useCatalog } from '../hooks/useCatalog'
import { withPreview } from '../services/catalogModel.js'

const normalize = value => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('es')
export default function Attractions() {
  const [query, setQuery] = useState(''), [category, setCategory] = useState('')
  const state = useCatalog()
  const categories = state.catalog?.categories || []
  const activeCategory = categories.some(item => item.id === category) ? category : ''
  const visible = (state.catalog?.places || []).filter(place => normalize(`${place.name} ${place.description}`).includes(normalize(query.trim())) && (!activeCategory || place.categories.some(item => item.id === activeCategory)))
  return <section className="page attractions-page">
    <header className="page-heading"><p className="page-eyebrow">Descubre Casablanca</p><h1>Atractivos turísticos</h1><p className="page-intro">Conoce los espacios históricos, culturales y patrimoniales de Casablanca.</p></header>
    <PreviewNotice preview={state.preview} /><CatalogStatus {...state} />
    {state.catalog && <><div className="attraction-search catalog-filters"><label htmlFor="place-search">¿Qué lugar quieres conocer?</label><div><input id="place-search" type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Busca por nombre o descripción" maxLength={100} /><label className="catalog-category-filter">Categoría<select value={activeCategory} onChange={event => setCategory(event.target.value)}><option value="">Todas las categorías</option>{categories.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>{(query || activeCategory) && <button type="button" onClick={() => { setQuery(''); setCategory('') }}>Limpiar filtros</button>}</div><p role="status">{visible.length} {visible.length === 1 ? 'lugar encontrado' : 'lugares encontrados'}</p></div>
    {!visible.length && <p>{state.catalog.places.length ? 'No encontramos lugares con esos filtros.' : 'No hay atractivos disponibles en este momento.'}</p>}
    <div className="attractions-grid">{visible.map(place => <article className="content-card attraction-card" key={place.id}>
      {publicImage(place.image) && <div className="card-media"><img src={publicImage(place.image)} alt={place.imageAlt || place.name} loading="lazy" decoding="async" /></div>}
      <div className="card-body"><h2>{place.name}</h2><p>{place.description}</p>{place.categories.length > 0 && <ul className="catalog-category-list" aria-label="Categorías">{place.categories.map(item => <li key={item.id}><CategoryIcon code={item.icon} />{item.name}</li>)}</ul>}<Link className="btn btn-text" to={withPreview(`/attractions/${place.id}`, state.preview)}>Ver detalle</Link></div>
    </article>)}</div></>}
  </section>
}
