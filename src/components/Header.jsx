import { useState } from 'react'
import { Link, NavLink } from 'react-router-dom'
import { useSession } from './SessionContext'

const links = [{ to: '/', label: 'Inicio', end: true }, { to: '/attractions', label: 'Atractivos' }, { to: '/routes', label: 'Rutas' }, { to: '/mapas', label: 'Mapas' }]
export default function Header() {
  const [menuOpen, setMenuOpen] = useState(false)
  const [aviso, setAviso] = useState('')
  const [ocupado, setOcupado] = useState(false)
  const { usuario, cargando, error, salir, refrescar } = useSession()
  const navClass = ({ isActive }) => `nav-link${isActive ? ' is-active' : ''}`
  const closeMenu = () => setMenuOpen(false)
  async function cerrar() {
    setOcupado(true); setAviso('')
    try { await salir(); closeMenu() }
    catch (fallo) { setAviso(fallo.message) }
    finally { setOcupado(false) }
  }
  return <header className="site-header refreshed-header">
    <a className="skip-link" href="#contenido" onClick={event => { event.preventDefault(); document.getElementById('contenido')?.focus() }}>Saltar al contenido</a>
    <div className="header-inner">
      <Link to="/" className="brand" aria-label="Casablanca Turismo, inicio" onClick={closeMenu}>
        <span className="brand-mark" aria-hidden="true">C<span>↗</span></span>
        <span><span className="brand-name">Casablanca</span><span className="brand-subtitle">CULTURA Y TURISMO</span></span>
      </Link>
      <button type="button" className="nav-toggle" aria-expanded={menuOpen} aria-controls="principal-nav" onClick={() => setMenuOpen(value => !value)}>{menuOpen ? 'Cerrar menú' : 'Menú'}</button>
      <nav id="principal-nav" className={`site-nav${menuOpen ? ' is-open' : ''}`} aria-label="Navegación principal" onKeyDown={event => { if (event.key === 'Escape') { closeMenu(); document.querySelector('.nav-toggle')?.focus() } }}>
        {links.map(link => <NavLink key={link.to} to={link.to} end={link.end} className={navClass} onClick={closeMenu}>{link.label}</NavLink>)}
        {cargando ? <span className="nav-session-status" role="status">Comprobando cuenta…</span> : usuario ? <>
          <NavLink to="/profile" className={navClass} onClick={closeMenu}>Mi cuenta</NavLink>
          {usuario.administrador === true && <NavLink to="/admin" className={navClass} onClick={closeMenu}>Administración</NavLink>}
          <button type="button" className="nav-link nav-logout" disabled={ocupado} onClick={cerrar}>{ocupado ? 'Cerrando…' : 'Salir'}</button>
        </> : <NavLink to="/login" className="nav-link nav-register" onClick={closeMenu}>Iniciar sesión</NavLink>}
      </nav>
    </div>
    {(aviso || error) && <div className="header-notice" role="status"><div><strong>{aviso ? 'No se pudo cerrar la sesión.' : 'No se pudo conectar con el servicio.'}</strong><span>{aviso ? 'Intenta cerrar la sesión nuevamente.' : 'Intenta nuevamente en unos momentos.'}</span></div><button type="button" onClick={aviso ? cerrar : refrescar} disabled={ocupado}>Reintentar</button></div>}
  </header>
}
