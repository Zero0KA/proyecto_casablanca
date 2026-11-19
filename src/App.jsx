import { useEffect } from 'react'
import { Navigate, Route, Routes, useLocation, useParams } from 'react-router-dom'
import Header from './components/Header'
import Footer from './components/Footer'
import Home from './pages/Home'
import MapPage from './pages/MapPage'
import InteractiveMaps from './pages/InteractiveMaps'
import AttractionDetail from './pages/AttractionDetail'
import AttractionMap from './pages/AttractionMap'
import { canonicalAttractionId, withPreview } from './services/catalogModel.js'
import Attractions from './pages/Attractions'
import RoutesPage from './pages/Routes'
import Profile from './pages/Profile'
import Register from './pages/Register'
import Login from './pages/Login'
import Categories from './pages/Categories'
import Users from './pages/Users'
import Admin from './pages/Admin'
import AdminContent from './pages/AdminContent'
import StartRoute from './pages/StartRoute'
import CatalogRoute from './pages/CatalogRoute'
import { SessionProvider, RequireSession, GuestOnly } from './components/Session'
import './App.css'
import './integration.css'
import './refresh.css'
import './catalog.css'

function ScrollToTop() {
  const { pathname } = useLocation()

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' })
    const titles = { '/': 'Descubre Casablanca', '/attractions': 'Atractivos', '/routes': 'Rutas', '/map': 'Mapa', '/mapas': 'Mapas interactivos', '/mapas/casco-historico': 'Mapa del Casco Histórico', '/login': 'Iniciar sesión', '/register': 'Crear cuenta', '/profile': 'Mi cuenta', '/admin': 'Administración', '/admin/users': 'Cuentas', '/admin/categories': 'Categorías', '/admin/atractivos': 'Administrar atractivos', '/admin/rutas': 'Administrar rutas' }
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
          <Route path="/map" element={<LegacyMap />} />
          <Route path="/mapas" element={<InteractiveMaps />} />
          <Route path="/mapas/casco-historico" element={<MapPage />} />
          <Route path="/mapas/rutas/:id" element={<MapPage />} />
          <Route path="/mapas/atractivos/:id" element={<AttractionMap />} />
          <Route path="/routes" element={<RoutesPage />} />
          <Route path="/attractions" element={<Attractions />} />
          <Route path="/attractions/:id" element={<AttractionDetail />} />
          <Route path="/profile" element={<RequireSession><Profile /></RequireSession>} />
          <Route path="/login" element={<GuestOnly><Login /></GuestOnly>} />
          <Route path="/register" element={<GuestOnly><Register /></GuestOnly>} />
          <Route path="/admin" element={<RequireSession admin><Admin /></RequireSession>} />
          <Route path="/admin/categories" element={<RequireSession admin><Categories /></RequireSession>} />
          <Route path="/admin/users" element={<RequireSession admin><Users /></RequireSession>} />
          <Route path="/admin/atractivos" element={<RequireSession admin><AdminContent key="atractivos" kind="atractivo" /></RequireSession>} />
          <Route path="/admin/rutas" element={<RequireSession admin><AdminContent key="rutas" kind="ruta" /></RequireSession>} />
          <Route path="/admin/rutas/:id/paradas" element={<RequireSession admin><AdminStops /></RequireSession>} />
          <Route path="/routes/catalogo/:id" element={<CatalogRoute />} />
          <Route path="/routes/:id" element={<StartRoute key="detalle" />} />
          <Route path="*" element={<section className="page"><h1>Página no encontrada</h1><p>Usa la navegación para volver a los lugares y rutas de Casablanca.</p></section>} />
          <Route path="/routes/:id/start" element={<RequireSession><StartRoute key="iniciar" start /></RequireSession>} />
        </Routes>
      </main>
      <Footer />
    </div></SessionProvider>
  )
}

export default App

function LegacyMap() {
  const location = useLocation()
  const params = new URLSearchParams(location.search)
  const attraction = canonicalAttractionId(params.get('lugar'))
  if (attraction) return <Navigate to={withPreview(`/mapas/atractivos/${attraction}`, params.get('vista_previa') === '1')} replace />
  return <Navigate to={`/mapas/casco-historico${location.search}`} replace />
}

function AdminStops() {
  const { id } = useParams()
  return <AdminContent key={id} kind="parada" />
}
