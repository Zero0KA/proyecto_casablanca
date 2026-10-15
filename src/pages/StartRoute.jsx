import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { apiFetch, publicImage, useSession } from '../components/SessionContext'
export default function StartRoute({ start = false }){
  const {id}=useParams();const {usuario}=useSession()
  const [datos,setDatos]=useState(null),[error,setError]=useState(''),[ocupado,setOcupado]=useState(false),[recorrido,setRecorrido]=useState(null)
  useEffect(()=>{const controller=new AbortController();async function cargar(){setDatos(null);setError('');setRecorrido(null);try{setDatos(await apiFetch(`/rutas/${id}`,{signal:controller.signal}))}catch(fallo){if(fallo.name!=='AbortError')setError(fallo.message)}}cargar();return()=>controller.abort()},[id])
  async function iniciar(){if(ocupado)return;setOcupado(true);setError('');try{const r=await apiFetch(`/rutas/${id}/recorridos`,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});setRecorrido(r.recorrido_id)}catch(fallo){setError(fallo.message)}finally{setOcupado(false)}}
  return <section className="page"><Link to="/routes" className="btn-text">← Volver a rutas</Link>
    {error&&<p className="cuenta-error" role="alert">{error}</p>}{!datos&&!error&&<p role="status">Cargando ruta…</p>}
    {datos&&<><header className="page-heading"><p className="page-eyebrow">{start?'Prepara tu recorrido':'Conoce la ruta'}</p><h1>{datos.ruta.nombre}</h1><p>{datos.ruta.descripcion}</p><p>{datos.ruta.duracion_estimada_minutos} minutos estimados · {datos.paradas.length} paradas</p></header>
    <div className="route-details">{datos.paradas.map(p=><article className="content-card" key={p.parada_id}>{publicImage(p.imagen_principal)&&<div className="card-media"><img src={publicImage(p.imagen_principal)} alt={p.imagen_texto_alternativo||p.nombre}/></div>}<div className="card-body"><p className="page-eyebrow">Parada {p.orden}</p><h2>{p.nombre}</h2><p>{p.descripcion}</p></div></article>)}</div>
    {recorrido?<div className="success-notice" role="status"><h2>Recorrido iniciado</h2><p>Puedes consultarlo en tu cuenta.</p><Link className="btn btn-primary" to="/profile">Ver mis recorridos</Link></div>:start?<div className="route-start"><button className="btn btn-primary" type="button" disabled={ocupado} onClick={iniciar}>{ocupado?'Iniciando…':'Confirmar inicio del recorrido'}</button></div>:<Link className="btn btn-primary" to={`/routes/${id}/start`}>{usuario?'Iniciar recorrido':'Iniciar sesión para recorrer'}</Link>}
    </>}
  </section>
}
