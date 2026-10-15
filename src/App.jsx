import { useEffect } from 'react'
import { Route, Routes, useLocation } from 'react-router-dom'
import Header from './components/Header'
import Footer from './components/Footer'
import Home from './pages/Home'
import MapPage from './pages/MapPage'
import AttractionDetail from './pages/AttractionDetail'
import Attractions from './pages/Attractions'
import RoutesPage from './pages/Routes'
import Profile from './pages/Profile'
import Register from './pages/Register'
import Login from './pages/Login'
import Categories from './pages/Categories'
import Users from './pages/Users'
import Admin from './pages/Admin'
import StartRoute from './pages/StartRoute'
import CatalogRoute from './pages/CatalogRoute'
import { SessionProvider, RequireSession, GuestOnly } from './components/Session'
import './App.css'
import './integration.css'
import './refresh.css'

function ScrollToTop() {
  const { pathname } = useLocation()

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' })
    const titles = { '/': 'Descubre Casablanca', '/attractions': 'Atractivos', '/routes': 'Rutas', '/map': 'Mapa', '/login': 'Iniciar sesión', '/register': 'Crear cuenta', '/profile': 'Mi cuenta', '/admin': 'Administración', '/admin/users': 'Cuentas', '/admin/categories': 'Categorías' }
    document.title = `${titles[pathname] || 'Explora Casablanca'} · Casablanca Turismo`
  }, [pathname])

  return null
}

function App() {
  return (
    <SessionProvider><div className="app">
      <ScrollToTop />
      <Header />
      <main className="app-main" id="contenido" tabIndex={-1}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/map" element={<MapPage />} />
          <Route path="/routes" element={<RoutesPage />} />
          <Route path="/attractions" element={<Attractions />} />
          <Route path="/attractions/:id" element={<AttractionDetail />} />
          <Route path="/profile" element={<RequireSession><Profile /></RequireSession>} />
          <Route path="/login" element={<GuestOnly><Login /></GuestOnly>} />
          <Route path="/register" element={<GuestOnly><Register /></GuestOnly>} />
          <Route path="/admin" element={<RequireSession admin><Admin /></RequireSession>} />
          <Route path="/admin/categories" element={<RequireSession admin><Categories /></RequireSession>} />
          <Route path="/admin/users" element={<RequireSession admin><Users /></RequireSession>} />
          <Route path="/routes/catalogo/:id" element={<CatalogRoute />} />
          <Route path="/routes/:id" element={<StartRoute />} />
          <Route path="*" element={<section className="page"><h1>Página no encontrada</h1><p>Usa la navegación para volver a los lugares y rutas de Casablanca.</p></section>} />
          <Route path="/routes/:id/start" element={<RequireSession><StartRoute start /></RequireSession>} />
        </Routes>
      </main>
      <Footer />
    </div></SessionProvider>
  )
}

export default App
