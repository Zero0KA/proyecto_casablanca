import { fetchApi } from '../components/demoTransport'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'


const API = `${import.meta.env.BASE_URL}api`
const inicial = { nombre: '', email: '', password: '', confirmacion: '', edad: '', nacionalidad_codigo: '', genero_codigo: 'prefiero_no_responder', genero_detalle: '' }

export default function Register() {
  const [datos, setDatos] = useState(inicial)
  const [paises, setPaises] = useState([])
  const [cargando, setCargando] = useState(true)
  const [revision, setRevision] = useState(0)
  const [ocupado, setOcupado] = useState(false)
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')

  useEffect(() => {
    const controller = new AbortController()
    async function cargar() {
      setCargando(true)
      setError('')
      try {
        const respuesta = await fetchApi(`${API}/paises`, { signal: controller.signal, cache: 'no-store' })
        const lista = await respuesta.json()
        if (!respuesta.ok) throw new Error(lista.mensaje || 'No se pudo cargar el catálogo.')
        if (!Array.isArray(lista) || !lista.length) throw new Error('No hay nacionalidades disponibles.')
        setPaises(lista)
      } catch (fallo) {
        if (fallo.name !== 'AbortError') setError(fallo.message || 'No se pudo conectar con la API.')
      } finally {
        if (!controller.signal.aborted) setCargando(false)
      }
    }
    cargar()
    return () => controller.abort()
  }, [revision])

  function cambiar(evento) {
    const { name, value } = evento.target
    setDatos(anterior => ({ ...anterior, [name]: value, ...(name === 'genero_codigo' && value !== 'otra_identidad' ? { genero_detalle: '' } : {}) }))
    setMensaje('')
  }

  async function registrar(evento) {
    evento.preventDefault()
    if (ocupado) return
    setError(''); setMensaje('')
    if (datos.password !== datos.confirmacion) { setError('Las contraseñas no coinciden.'); return }
    if (!datos.edad.trim()) { setError('Indica tu edad.'); return }
    setOcupado(true)
    try {
      const respuesta = await fetchApi(`${API}/registro`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ nombre: datos.nombre, email: datos.email, password: datos.password,
          edad: Number(datos.edad), nacionalidad_codigo: datos.nacionalidad_codigo,
          genero_codigo: datos.genero_codigo, genero_detalle: datos.genero_detalle || null }),
      })
      const resultado = await respuesta.json()
      if (!respuesta.ok) throw new Error(resultado.mensaje || 'No se pudo registrar la cuenta.')
      setMensaje(resultado.mensaje)
      setDatos(inicial)
    } catch (fallo) { setError(fallo.message || 'No se pudo conectar con la API.') }
    finally { setOcupado(false) }
  }

  return (
    <section className="registro-panel"><p className="page-eyebrow">Tu próxima experiencia empieza aquí</p>
      <Link to="/">← Volver al inicio</Link> · <Link to="/login">Iniciar sesión</Link>
      <h1>Crear cuenta</h1>
      <p>Regístrate como turista para preparar tu acceso a Casablanca.</p>
      <p className="registro-nota">En esta etapa guardamos el registro. El envío de verificación del correo sigue pendiente. Las cuentas de prueba se habilitan manualmente.</p>
      {error && <p className="registro-error" role="alert">{error}</p>}
      {mensaje && <p className="registro-exito" role="status">{mensaje}</p>}
      {cargando && <p role="status">Cargando nacionalidades…</p>}
      {!cargando && !paises.length && <button type="button" onClick={() => setRevision(valor => valor + 1)}>Reintentar conexión</button>}
      <form onSubmit={registrar}>
        <fieldset disabled={ocupado || cargando || !paises.length}>
          <label>Nombre<input name="nombre" value={datos.nombre} onChange={cambiar} required maxLength={100} autoComplete="name" /></label>
          <label>Correo electrónico<input name="email" type="email" value={datos.email} onChange={cambiar} required maxLength={254} autoComplete="email" /></label>
          <label>Contraseña<input name="password" type="password" value={datos.password} onChange={cambiar} required minLength={15} maxLength={128} autoComplete="new-password" aria-describedby="regla-password" /></label>
          <small id="regla-password">Entre 15 y 128 caracteres; puedes usar una frase. No necesitas un formato Argon2id: la API lo genera.</small>
          <label>Repetir contraseña<input name="confirmacion" type="password" value={datos.confirmacion} onChange={cambiar} required minLength={15} maxLength={128} autoComplete="new-password" /></label>
          <div className="registro-fila">
            <label>Edad declarada<input name="edad" type="number" min="0" max="120" step="1" value={datos.edad} onChange={cambiar} required /></label>
            <label>Nacionalidad<select name="nacionalidad_codigo" value={datos.nacionalidad_codigo} onChange={cambiar} required><option value="">Selecciona una opción</option>{paises.map(pais => <option key={pais.codigo} value={pais.codigo}>{pais.nombre_es}</option>)}</select></label>
          </div>
          <label>Género<select name="genero_codigo" value={datos.genero_codigo} onChange={cambiar}>
            <option value="prefiero_no_responder">Prefiero no responder</option>
            <option value="masculino">Masculino</option><option value="femenino">Femenino</option>
            <option value="no_binario">No binario</option><option value="otra_identidad">Otra identidad</option>
          </select></label>
          {datos.genero_codigo === 'otra_identidad' && <label>Detalle de género (opcional)<input name="genero_detalle" value={datos.genero_detalle} onChange={cambiar} maxLength={100} /></label>}
          <button type="submit">{ocupado ? 'Guardando registro…' : 'Crear cuenta'}</button>
        </fieldset>
      </form>
    </section>
  )
}
