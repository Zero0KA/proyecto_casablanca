import { useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { apiFetch } from '../components/SessionContext'
import ContentFields from '../components/ContentFields'
import { contentPayload, newContent } from '../data/contentForm'
import './AdminContent.css'

const labels = { atractivo: ['Atractivos','atractivo','atractivos','atractivo_id'], ruta: ['Rutas','ruta','rutas','ruta_id'], parada: ['Paradas','parada','paradas','parada_id'] }
export default function AdminContent({ kind = 'atractivo' }) {
  const { id: routeId } = useParams()
  const [rows,setRows] = useState([]), [categories,setCategories] = useState([]), [attractions,setAttractions] = useState([])
  const [routeName,setRouteName] = useState(''), [routeState,setRouteState] = useState('')
  const [form,setForm] = useState(null), [editing,setEditing] = useState(null), [query,setQuery] = useState('')
  const [loading,setLoading] = useState(true), [busy,setBusy] = useState(false), [error,setError] = useState(''), [notice,setNotice] = useState(''), [revision,setRevision] = useState(0)
  const formTitle = useRef(null), requestBusy = useRef(false)
  const [title,singular,plural,key] = labels[kind]
  const base = kind === 'parada' ? `/admin/rutas/${routeId}/paradas` : `/admin/${plural}`
  useEffect(() => {
    const controller = new AbortController()
    async function load() {
      try {
        const result = await apiFetch(base,{ signal:controller.signal })
        let extra = null, routes = null
        if (kind === 'parada') [extra,routes] = await Promise.all([apiFetch('/admin/atractivos',{signal:controller.signal}),apiFetch('/admin/rutas',{signal:controller.signal})])
        if (controller.signal.aborted) return
        setRows(result[plural] || []); setCategories(result.categorias || []); setAttractions(extra?.atractivos || [])
        if (routes) { const route = routes.rutas.find(item => item.ruta_id === routeId); setRouteName(route?.nombre || 'Ruta'); setRouteState(route?.estado || '') }
      } catch (failure) { if (!controller.signal.aborted && failure.name !== 'AbortError') setError(failure.message) }
      finally { if (!controller.signal.aborted) setLoading(false) }
    }
    load(); return () => controller.abort()
  },[base,kind,plural,revision,routeId])
  const formOpen = form !== null
  useEffect(() => { if (formOpen) formTitle.current?.focus() },[editing,formOpen])
  function refresh() { setLoading(true); setRevision(value => value + 1) }
  function open(row) { setError(''); setNotice(''); setEditing(row?.[key] || null); setForm(row ? { ...newContent(kind), ...structuredClone(row),englishExists:Boolean(row.traducciones.en.nombre || row.traducciones.en.descripcion) } : { ...newContent(kind),orden:rows.length + 1 }) }
  async function run(task,message) {
    if (requestBusy.current) return
    requestBusy.current = true; setBusy(true); setError(''); setNotice('')
    try { await task(); setNotice(message); refresh() } catch (failure) { setError(failure.message) }
    finally { requestBusy.current = false; setBusy(false) }
  }
  async function save(event) {
    event.preventDefault()
    await run(async () => { await apiFetch(base + (editing ? `/${editing}` : ''),{ method:editing ? 'PUT' : 'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(contentPayload(form,kind)) }); setForm(null); setEditing(null) },editing ? 'Cambios guardados.' : kind === 'parada' ? 'Parada creada.' : `${singular === 'ruta' ? 'Ruta creada' : 'Atractivo creado'} como borrador de trabajo.`)
  }
  async function state(row,value) { await run(() => apiFetch(`${base}/${row[key]}/estado`,{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({estado:value})}),'Estado actualizado.') }
  async function remove(row) {
    if (!window.confirm(`¿Eliminar definitivamente ${row.nombre || `esta ${singular}`}? Se aplicarán las protecciones de asociaciones e historial.`)) return
    await run(async () => { await apiFetch(`${base}/${row[key]}`,{method:'DELETE',headers:{'Content-Type':'application/json'},body:'{}'}); if (editing === row[key]) { setForm(null); setEditing(null) } },'Registro eliminado.')
  }
  async function move(index,offset) {
    const ids = rows.map(row => row.parada_id); const next = index + offset
    if (next < 0 || next >= ids.length) return
    ;[ids[index],ids[next]] = [ids[next],ids[index]]
    await run(() => apiFetch(`/admin/rutas/${routeId}/orden`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({parada_ids:ids})}),'Orden actualizado.')
  }
  async function populate() {
    if (!window.confirm('¿Agregar el catálogo inicial que falte? Se conservarán las ediciones existentes. Los registros nuevos quedarán en borrador.')) return
    await run(async () => {
      const result = await apiFetch('/admin/catalogo-inicial',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({confirmacion:true})})
      setForm(null); setEditing(null)
      return result
    },'Catálogo inicial incorporado. Se conservaron los registros existentes.')
  }
  const normalize = value => (value || '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase()
  const visible = rows.filter(row => normalize(`${row.nombre || ''} ${row.estado || ''}`).includes(normalize(query.trim())))
  return <section className="page admin-content-panel">
    <Link className="home-link" to={kind === 'parada' ? '/admin/rutas' : '/admin'}>← {kind === 'parada' ? 'Volver a rutas' : 'Volver a administración'}</Link>
    <header className="page-heading"><p className="page-eyebrow">GESTIÓN DE CONTENIDO</p><h1>{kind === 'parada' ? `Paradas de ${routeName || 'la ruta'}` : `Administrar ${plural}`}</h1><p className="page-intro">{kind === 'parada' ? 'Edita los lugares y su orden en el recorrido.' : `Consulta, crea y actualiza ${plural}.`}</p>{kind === 'parada' && routeState && <p className="content-route-state">Ruta: <strong>{routeState}</strong></p>}</header>
    <nav className="content-admin-nav" aria-label="Administración de contenido"><Link to="/admin/atractivos" aria-current={kind === 'atractivo' ? 'page' : undefined}>Atractivos</Link><Link to="/admin/rutas" aria-current={kind !== 'atractivo' ? 'page' : undefined}>Rutas</Link><Link to="/admin/categories">Categorías</Link></nav>
    <div className="content-admin-toolbar"><label>Buscar {plural}<input type="search" value={query} maxLength={200} onChange={event => setQuery(event.target.value)} /></label><div className="content-toolbar-actions"><button className="btn btn-primary" type="button" disabled={busy || loading} onClick={() => open(null)}>Crear {singular}</button>{kind !== 'parada' && <button className="btn btn-outline" type="button" disabled={busy || loading} onClick={populate}>Agregar catálogo inicial</button>}</div></div>
    {error && <div className="cuenta-error" role="alert"><p>{error}</p><button className="btn btn-outline" type="button" disabled={busy} onClick={() => { setError(''); refresh() }}>Actualizar listado</button></div>}
    {notice && <p className="content-success" role="status">{notice}</p>}
    {form && <form className="content-edit-form" onSubmit={save}><h2 ref={formTitle} tabIndex={-1}>{editing ? `Editar ${singular}` : `Crear ${singular}`}</h2><fieldset disabled={busy}><ContentFields form={form} setForm={setForm} kind={kind} categories={categories} attractions={attractions} stopCount={rows.length} editing={Boolean(editing)} /><div className="content-form-actions"><button className="btn btn-primary" type="submit">{busy ? 'Guardando…' : 'Guardar'}</button><button className="btn btn-outline" type="button" onClick={() => { setForm(null); setEditing(null) }}>Cancelar</button></div></fieldset></form>}
    {loading && <p role="status">Cargando {plural}…</p>}
    {!loading && !visible.length && <p>No hay {plural} que coincidan con la consulta.</p>}
    {visible.length > 0 && <div className="content-table-wrap"><table className="content-table"><caption className="content-sr-only">{title} disponibles para administrar</caption><thead><tr>{kind === 'parada' && <th scope="col">Orden</th>}<th scope="col">Nombre</th>{kind !== 'parada' && <th scope="col">Estado</th>}<th scope="col">{kind === 'ruta' ? 'Duración' : 'Ubicación'}</th><th scope="col">Acciones</th></tr></thead><tbody>{visible.map(row => <tr key={row[key]}>
      {kind === 'parada' && <td><div className="content-order"><strong>{row.orden}</strong><button type="button" disabled={busy || loading || rows.indexOf(row) === 0} onClick={() => move(rows.indexOf(row),-1)} aria-label={`Subir ${row.nombre || 'parada'}`}>↑</button><button type="button" disabled={busy || loading || rows.indexOf(row) === rows.length - 1} onClick={() => move(rows.indexOf(row),1)} aria-label={`Bajar ${row.nombre || 'parada'}`}>↓</button></div></td>}
      <th scope="row">{row.nombre || 'Sin nombre en español'}</th>{kind !== 'parada' && <td><span className={`content-state content-state-${row.estado}`}>{row.estado}</span></td>}
      <td>{kind === 'ruta' ? row.duracion_estimada_minutos ? `${row.duracion_estimada_minutos} min` : 'Sin definir' : row.latitud != null && row.longitud != null ? <span className="content-coordinates">{Number(row.latitud).toFixed(6)}<br />{Number(row.longitud).toFixed(6)}</span> : 'Sin ubicación'}</td>
      <td><div className="content-row-actions"><button className="btn btn-outline" type="button" disabled={busy || loading} onClick={() => open(row)}>Editar</button>{kind === 'ruta' && <Link className="btn btn-outline" to={`/admin/rutas/${row.ruta_id}/paradas`}>Paradas</Link>}{kind !== 'parada' && <>{row.estado !== 'publicado' && <button className="btn btn-outline" type="button" disabled={busy || loading} onClick={() => state(row,'publicado')}>Publicar</button>}{row.estado !== 'borrador' && <button className="btn btn-outline" type="button" disabled={busy || loading} onClick={() => state(row,'borrador')}>Pasar a borrador</button>}{row.estado !== 'archivado' && <button className="btn btn-outline" type="button" disabled={busy || loading} onClick={() => state(row,'archivado')}>Archivar</button>}</>}<button className="btn content-delete" type="button" disabled={busy || loading || (kind === 'parada' ? routeState !== 'borrador' : row.estado === 'publicado')} onClick={() => remove(row)}>Eliminar</button></div></td>
    </tr>)}</tbody></table></div>}
  </section>
}
