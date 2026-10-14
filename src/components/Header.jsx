import { useState } from 'react'
import { Link, NavLink, useNavigate } from 'react-router-dom'
import { useSession } from './SessionContext'
const links=[{to:'/',label:'Inicio',end:true},{to:'/map',label:'Mapa'},{to:'/routes',label:'Rutas'},{to:'/attractions',label:'Atractivos'}]
export default function Header(){
  const [menuOpen,setMenuOpen]=useState(false),[aviso,setAviso]=useState(''),[ocupado,setOcupado]=useState(false)
  const {usuario,cargando,error,salir,refrescar}=useSession();const navigate=useNavigate()
  async function cerrar(){setOcupado(true);setAviso('');try{await salir();setMenuOpen(false);navigate('/')}catch(fallo){setAviso(fallo.message)}finally{setOcupado(false)}}
  const navClass=({isActive})=>isActive?'nav-link is-active':'nav-link'
  return <header className="site-header"><div className="header-inner">
    <Link to="/" className="brand" aria-label="Municipalidad de Casablanca, inicio" onClick={()=>setMenuOpen(false)}><span className="brand-name">Municipalidad de Casablanca</span><span className="brand-subtitle">Dirección de Relaciones Públicas, Cultura y Turismo</span></Link>
    <button type="button" className="nav-toggle" aria-expanded={menuOpen} aria-controls="principal-nav" onClick={()=>setMenuOpen(v=>!v)}>{menuOpen?'Cerrar':'Menú'}</button>
    <nav id="principal-nav" className={menuOpen?'site-nav is-open':'site-nav'} aria-label="Principal">
      {links.map(link=><NavLink key={link.to} to={link.to} end={link.end} className={navClass} onClick={()=>setMenuOpen(false)}>{link.label}</NavLink>)}
      {cargando?<span className="nav-link">Comprobando cuenta…</span>:usuario?<>
        <NavLink to="/profile" className={navClass} onClick={()=>setMenuOpen(false)}>Mi cuenta</NavLink>
        {usuario.administrador&&<NavLink to="/admin" className={navClass} onClick={()=>setMenuOpen(false)}>Administración</NavLink>}
        <button type="button" className="nav-link nav-logout" disabled={ocupado} onClick={cerrar}>{ocupado?'Cerrando…':'Cerrar sesión'}</button>
      </>:<><NavLink to="/login" className={navClass} onClick={()=>setMenuOpen(false)}>Iniciar sesión</NavLink><NavLink to="/register" className="nav-link nav-register" onClick={()=>setMenuOpen(false)}>Registrarse</NavLink></>}
    </nav>
  </div>{(aviso||error)&&<div className="header-notice" role="alert">{aviso||'No se pudo comprobar la cuenta. El contenido público sigue disponible.'} <button type="button" onClick={refrescar}>Reintentar</button></div>}</header>
}
