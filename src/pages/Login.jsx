import { fetchApi } from '../components/demoTransport'
import { useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { API, useSession } from '../components/SessionContext'

export default function Login() {
  const { aceptarSesion } = useSession()
  const location = useLocation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)

  async function entrar(evento) {
    evento.preventDefault()
    if (ocupado) return

    setOcupado(true)
    setError('')

    try {
      const respuesta = await fetchApi(`${API}/login`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      })

      let datos
      try {
        datos = await respuesta.json()
      } catch (fallo) {
        throw new Error(
          'No se pudo completar el inicio de sesión. Intenta nuevamente.',
          { cause: fallo }
        )
      }

      if (!respuesta.ok) {
        throw new Error(datos.mensaje || 'No se pudo iniciar sesión.')
      }

      if (!datos.usuario || typeof datos.usuario.administrador !== 'boolean') {
        throw new Error('La respuesta de la sesión no es válida.')
      }

      setPassword('')

      const administrador = datos.usuario.administrador === true
      const solicitado = location.state?.from
      let destinoFinal = administrador ? '/admin' : '/profile'

      // Solo recuperamos destinos conocidos y permitidos para la cuenta.
      if (typeof solicitado === 'string' && !solicitado.includes('\\')) {
        const rutaPermitida = /^\/routes\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/start(?:\?[^#]*)?$/i.test(solicitado)
        const adminPermitido = administrador && /^\/admin(?:\/(?:users|categories))?$/.test(solicitado)
        if (rutaPermitida || adminPermitido) destinoFinal = solicitado
      }

      aceptarSesion(datos.usuario, destinoFinal)
    } catch (fallo) {
      setError(fallo.message || 'No se pudo conectar con el servicio.')
    } finally {
      setOcupado(false)
    }
  }

  return (
    <section className="cuenta-panel">
      <p className="page-eyebrow">Bienvenido a Casablanca</p>
      <h1>Iniciar sesión</h1>


      {error && <p className="cuenta-error" role="alert">{error}</p>}

      <form onSubmit={entrar}>
        <fieldset disabled={ocupado}>
          <label>
            Correo
            <input
              type="email"
              value={email}
              onChange={(evento) => setEmail(evento.target.value)}
              required
              maxLength={254}
              autoComplete="username"
            />
          </label>
          <label>
            Contraseña
            <input
              type="password"
              value={password}
              onChange={(evento) => setPassword(evento.target.value)}
              required
              maxLength={128}
              autoComplete="current-password"
            />
          </label>
          <button type="submit">
            {ocupado ? 'Comprobando…' : 'Entrar'}
          </button>
        </fieldset>
      </form>

      <p>
        <Link to="/register">Crear una cuenta</Link>
        {' · '}
        <Link to="/">Inicio</Link>
      </p>
    </section>
  )
}
