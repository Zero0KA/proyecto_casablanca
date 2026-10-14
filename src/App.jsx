import { useEffect } from 'react'
import { Route, Routes, useLocation } from 'react-router-dom'
import Header from './components/Header'
import Footer from './components/Footer'
import Home from './pages/Home'
import MapPage from './pages/MapPage'
import Attractions from './pages/Attractions'
import RoutesPage from './pages/Routes'
import Profile from './pages/Profile'
import Register from './pages/Register'
import Login from './pages/Login'
import Categories from './pages/Categories'
import Users from './pages/Users'
import Admin from './pages/Admin'
import StartRoute from './pages/StartRoute'
import { SessionProvider, RequireSession } from './components/Session'
import './App.css'
import './integration.css'

function ScrollToTop() {
  const { pathname } = useLocation()

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' })
  }, [pathname])

  return null
}

function App() {
  return (
    <SessionProvider><div className="app">
      <ScrollToTop />
      <Header />
      <main className="app-main">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/map" element={<MapPage />} />
          <Route path="/routes" element={<RoutesPage />} />
          <Route path="/attractions" element={<Attractions />} />
          <Route path="/profile" element={<RequireSession><Profile /></RequireSession>} />
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/admin" element={<RequireSession admin><Admin /></RequireSession>} />
          <Route path="/admin/categories" element={<RequireSession admin><Categories /></RequireSession>} />
          <Route path="/admin/users" element={<RequireSession admin><Users /></RequireSession>} />
          <Route path="/routes/:id" element={<StartRoute />} />
          <Route path="/routes/:id/start" element={<RequireSession><StartRoute start /></RequireSession>} />
        </Routes>
      </main>
      <Footer />
    </div></SessionProvider>
  )
}

export default App
