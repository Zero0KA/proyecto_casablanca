import { startTransition, useCallback, useEffect, useRef, useState } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { SessionContext, apiFetch, useSession } from './SessionContext'

export function SessionProvider({ children }) {
  const navigate = useNavigate()
  const [usuario,setUsuario]=useState(null),[cargando,setCargando]=useState(true),[error,setError]=useState('')
  const revision=useRef(0)
  const refrescar=useCallback(async()=>{
    const actual=++revision.current
    try {const datos=await apiFetch('/sesion',{cache:'no-store'});if(actual===revision.current){setUsuario(datos.usuario);setError('')}}
    catch(fallo){if(actual===revision.current){if(fallo.status===401){setUsuario(null);setError('')}else setError(fallo.message)}}
    finally{if(actual===revision.current)setCargando(false)}
  },[])
  useEffect(()=>{
    const control=revision
    const timer=window.setTimeout(refrescar,0)
    const intervalo=window.setInterval(refrescar,30000)
    window.addEventListener('focus',refrescar)
    return()=>{window.clearTimeout(timer);window.clearInterval(intervalo);window.removeEventListener('focus',refrescar);control.current++}
  },[refrescar])
  function aceptarSesion(nuevoUsuario, destino){
    // Descarta respuestas de comprobaciones anteriores al login.
    revision.current++
    startTransition(() => {
      setUsuario(nuevoUsuario)
      setError('')
      setCargando(false)
      navigate(destino || (nuevoUsuario.administrador === true ? '/admin' : '/profile'), { replace: true })
    })
  }
  async function salir(){
    revision.current++
    await apiFetch('/logout',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})
    revision.current++
    // La ruta y la sesión cambian en la misma transición; el guard no debe abrir Login al salir.
    startTransition(() => {
      setUsuario(null); setError('')
      navigate('/', { replace: true })
    })
  }
  return <SessionContext.Provider value={{usuario,cargando,error,refrescar,salir,aceptarSesion}}>{children}</SessionContext.Provider>
}
export function RequireSession({children,admin=false}){
  const {usuario,cargando,error,refrescar}=useSession();const location=useLocation()
  if(cargando)return <section className="page"><p role="status">Comprobando sesión…</p></section>
  if(error)return <section className="page"><p role="alert">{error}</p><button className="btn btn-primary" type="button" onClick={refrescar}>Reintentar</button></section>
  if(!usuario)return <Navigate to="/login" replace state={{from:location.pathname+location.search}}/>
  if(admin&&usuario.administrador!==true)return <Navigate to="/profile" replace/>
  return children
}

// Las cuentas con sesión no necesitan volver a los formularios de acceso.
export function GuestOnly({ children }) {
  const { usuario, cargando } = useSession()
  if (cargando) return <section className="page"><p role="status">Comprobando sesión…</p></section>
  if (usuario) return <Navigate to={usuario.administrador === true ? '/admin' : '/profile'} replace />
  return children
}
