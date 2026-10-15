import { fetchApi } from '../components/demoTransport'
import { useEffect, useState } from 'react'
import { API } from '../components/SessionContext'

export default function Users() {
  const [usuarios,setUsuarios]=useState([]), [texto,setTexto]=useState(''), [busqueda,setBusqueda]=useState('')
  const [manual,setManual]=useState(false)
  const [pagina,setPagina]=useState(1), [total,setTotal]=useState(0), [revision,setRevision]=useState(0)
  const [cargando,setCargando]=useState(true), [ocupado,setOcupado]=useState(false), [error,setError]=useState(''), [mensaje,setMensaje]=useState('')
  useEffect(()=>{
    const controller=new AbortController()
    async function cargar(){
      setCargando(true);setError('')
      try {
        const params=new URLSearchParams({busqueda,pagina:String(pagina)})
        const respuesta=await fetchApi(`${API}/admin/usuarios?${params}`,{signal:controller.signal,cache:'no-store'})
        const datos=await respuesta.json()
        if(!respuesta.ok)throw new Error(datos.mensaje||'No se pudieron cargar las cuentas.')
        setUsuarios(datos.usuarios);setTotal(datos.total);setManual(datos.habilitacion_manual === true)
      }catch(fallo){if(fallo.name!=='AbortError')setError(fallo.message)}
      finally{if(!controller.signal.aborted)setCargando(false)}
    }
    cargar();return()=>controller.abort()
  },[busqueda,pagina,revision])
  async function bloquear(u){
    const bloqueado=u.estado!=='bloqueado'
    if(!window.confirm(`${bloqueado?'Bloquear':'Desbloquear'} la cuenta ${u.email}?${bloqueado?' Se revocarán sus sesiones.':''}`))return
    setOcupado(true);setError('');setMensaje('')
    try{
      const respuesta=await fetchApi(`${API}/admin/usuarios/${u.usuario_id}/bloqueo`,{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({bloqueado})})
      const datos=await respuesta.json()
      if(!respuesta.ok)throw new Error(datos.mensaje||'No se pudo actualizar.')
      setMensaje(bloqueado?'Cuenta bloqueada y sesiones revocadas.':'Cuenta desbloqueada. Debe iniciar sesión de nuevo; si no tiene correo verificado, sigue pendiente.')
      setRevision(v=>v+1)
    }catch(fallo){setError(fallo.message)}finally{setOcupado(false)}
  }
  async function habilitar(u){
    if(ocupado)return
    if(!window.confirm(`¿Habilitar la cuenta de ${u.email}? Podrá iniciar sesión como turista.`))return
    setOcupado(true);setError('');setMensaje('')
    try{
      const respuesta=await fetchApi(`${API}/admin/usuarios/${u.usuario_id}/habilitar-demo`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({confirmacion_demo:true})})
      const datos=await respuesta.json()
      if(!respuesta.ok)throw new Error(respuesta.status === 404 ? 'No se pudo habilitar la cuenta. Actualiza el listado e intenta nuevamente.' : datos.mensaje||'No se pudo habilitar la cuenta.')
      setMensaje('Cuenta habilitada.');setRevision(v=>v+1)
    }catch(fallo){setError(fallo.message)}finally{setOcupado(false)}
  }
  return <section className="page usuarios-panel"><h1>Administración de cuentas</h1><p>Lista y bloquea cuentas turistas. Las cuentas administradoras están protegidas.</p>
    <form onSubmit={e=>{e.preventDefault();setBusqueda(texto.trim());setPagina(1);setRevision(v=>v+1)}} className="usuarios-busqueda"><label>Buscar por correo<input value={texto} onChange={e=>setTexto(e.target.value)} maxLength={254}/></label><button type="submit" disabled={ocupado}>Buscar</button></form>
    {error&&<p role="alert" className="cuenta-error">{error} <button type="button" onClick={()=>setRevision(v=>v+1)}>Reintentar</button></p>}
    {mensaje&&<p role="status">{mensaje}</p>}{cargando&&<p role="status">Cargando cuentas…</p>}
    {!error&&!cargando&&<><div className="usuarios-tabla"><table><thead><tr><th>Correo</th><th>Nombre</th><th>Rol</th><th>Estado</th><th>Correo confirmado</th><th>Acción</th></tr></thead><tbody>
      {usuarios.map(u=><tr key={u.usuario_id}><td>{u.email}</td><td>{u.nombre}</td><td>{u.administrador?'Administrador':'Turista'}</td><td>{u.estado}</td><td>{u.correo_verificado?'Sí':'No'}</td><td><div className="user-row-actions">{manual&&u.estado==='pendiente'&&!u.correo_verificado&&!u.administrador&&<button type="button" disabled={ocupado} onClick={()=>habilitar(u)}>Habilitar cuenta</button>} <button type="button" disabled={ocupado||u.administrador} onClick={()=>bloquear(u)}>{u.administrador?'Protegida':u.estado==='bloqueado'?'Desbloquear':'Bloquear'}</button></div></td></tr>)}
    </tbody></table></div>{!usuarios.length&&<p>No hay cuentas para esta búsqueda.</p>}
    <div className="usuarios-paginacion"><button type="button" disabled={pagina===1||ocupado} onClick={()=>setPagina(v=>v-1)}>Anterior</button><span>Página {pagina} · {total} cuentas</span><button type="button" disabled={usuarios.length<25||pagina*25>=total||ocupado} onClick={()=>setPagina(v=>v+1)}>Siguiente</button></div></>}
  </section>
}
