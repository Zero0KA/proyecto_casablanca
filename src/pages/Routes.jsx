import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { routes as ejemplos } from '../data/routes'
import { attractions } from '../data/attractions'
import { apiFetch } from '../components/SessionContext'
export default function Routes(){
  const [rutas,setRutas]=useState([]),[cargando,setCargando]=useState(true),[error,setError]=useState(''),[revision,setRevision]=useState(0)
  useEffect(()=>{const controller=new AbortController();async function cargar(){setCargando(true);setError('');try{setRutas(await apiFetch('/rutas',{signal:controller.signal}))}catch(fallo){if(fallo.name!=='AbortError')setError(fallo.message)}finally{if(!controller.signal.aborted)setCargando(false)}}cargar();return()=>controller.abort()},[revision])
  return <section className="page routes-page"><header className="page-heading"><p className="page-eyebrow">Recorre y descubre</p><h1>Rutas</h1><p className="page-intro">Explora las rutas sin registrarte. Para iniciar un recorrido necesitas una cuenta habilitada.</p></header>
    {cargando&&<p role="status">Consultando rutas publicadas…</p>}{error&&<p className="cuenta-error" role="alert">{error} <button type="button" onClick={()=>setRevision(v=>v+1)}>Reintentar</button></p>}
    {!cargando&&!error&&rutas.length===0&&<p className="demo-notice">Todavía no hay rutas publicadas en la BD. Los ejemplos siguientes muestran el diseño; no crean recorridos.</p>}
    {rutas.length>0&&<><h2>Rutas disponibles</h2><div className="routes-grid">{rutas.map(ruta=><article className="content-card route-card" key={ruta.ruta_id}><div className="card-body"><p className="page-eyebrow">Ruta publicada</p><h2>{ruta.nombre}</h2><p>{ruta.descripcion}</p><p>{ruta.duracion_estimada_minutos} minutos estimados</p><div className="card-actions"><Link className="btn btn-primary" to={`/routes/${ruta.ruta_id}`}>Ver ruta</Link><Link className="btn-text" to={`/routes/${ruta.ruta_id}/start`}>Iniciar recorrido →</Link></div></div></article>)}</div></>}
    {!rutas.length&&<><h2 className="example-heading">Ejemplos de presentación</h2><div className="routes-grid">{ejemplos.map(route=>{const lugares=route.attractionIds.map(id=>attractions.find(a=>a.id===id)).filter(Boolean);return <article className="content-card route-card" key={route.id}><div className="card-body"><p className="page-eyebrow">Ejemplo · sin recorrido en la BD</p><h2>{route.name}</h2><div className="route-attractions"><h3>Lugares incluidos</h3><ul>{lugares.map(a=><li key={a.id}>{a.name}</li>)}</ul></div><p>Se habilitará al publicar una ruta real.</p></div></article>})}</div></>}
  </section>
}
