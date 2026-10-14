// El enlace público de la API es configuración; nunca contiene credenciales.
const BASE = import.meta.env.BASE_URL
const API_LOCAL = `${BASE}api`
const TOKEN = /^[0-9a-f]{64}$/
let configuracion = null
let pendiente = null
const memoria = new Map()

function local() {
  return ['localhost', '127.0.0.1', '[::1]'].includes(window.location.hostname)
}

async function destino() {
  if (local()) return { api: API_LOCAL, remoto: false }
  if (configuracion && Date.now() - configuracion.leida < 15000) return configuracion
  if (!pendiente) {
    pendiente = (async () => {
      const respuesta = await fetch(`${BASE}demo-api.json?consulta=${Date.now()}`, { cache: 'no-store', credentials: 'omit' })
      if (!respuesta.ok) throw new Error('La conexión de la presentación todavía no está publicada.')
      const datos = await respuesta.json()
      if (datos.activo !== true || typeof datos.api_url !== 'string') {
        throw new Error('La API de la presentación está apagada. El contenido público sigue disponible.')
      }
      const url = new URL(datos.api_url)
      if (url.protocol !== 'https:' || !/^[a-z0-9-]+\.trycloudflare\.com$/.test(url.hostname) ||
          url.port || url.username || url.password || url.pathname !== '/api' || url.search || url.hash) {
        throw new Error('La dirección de la API no es válida.')
      }
      configuracion = { api: url.href, remoto: true, leida: Date.now() }
      return configuracion
    })().finally(() => { pendiente = null })
  }
  return pendiente
}

function leer(api) {
  let registro = memoria.get(api)
  try { registro = JSON.parse(window.sessionStorage.getItem(`casablanca.demo:${api}`)) || registro } catch { /* Usa memoria si el navegador desactiva almacenamiento. */ }
  if (!registro || !TOKEN.test(registro.token) || !(registro.vence > Date.now())) return null
  return registro.token
}
function guardar(api, token, vence) {
  const registro = { token, vence }
  memoria.set(api, registro)
  try { window.sessionStorage.setItem(`casablanca.demo:${api}`, JSON.stringify(registro)) } catch { /* La sesión dura hasta recargar si no hay almacenamiento. */ }
}
function borrar(api, anterior) {
  // Una respuesta vieja no debe borrar una sesión que acaba de abrirse.
  if (leer(api) !== anterior) return
  memoria.delete(api)
  try { window.sessionStorage.removeItem(`casablanca.demo:${api}`) } catch { /* Ya se limpió memoria. */ }
}

export async function fetchApi(url, opciones = {}) {
  const ruta = typeof url === 'string' && url.startsWith(`${API_LOCAL}/`) ? url.slice(API_LOCAL.length) : null
  if (ruta === null || ruta.includes('\\') || ruta.includes('#')) throw new Error('Ruta de API inválida.')
  const config = await destino()
  const headers = new Headers(opciones.headers)
  const anterior = config.remoto ? leer(config.api) : null
  if (config.remoto && anterior) headers.set('Authorization', `Bearer ${anterior}`)
  const respuesta = await fetch(config.api + ruta, {
    ...opciones, headers, cache: 'no-store',
    credentials: config.remoto ? 'omit' : 'same-origin',
    redirect: 'error',
  })
  if (config.remoto) {
    if (ruta === '/login' && respuesta.ok) {
      const datos = await respuesta.clone().json()
      const vence = Date.parse(datos.vence_en)
      if (!TOKEN.test(datos.token_sesion) || !(vence > Date.now())) {
        throw new Error('La API no entregó una sesión remota válida.')
      }
      guardar(config.api, datos.token_sesion, vence)
    } else if ((ruta === '/logout' && respuesta.ok) || (ruta === '/sesion' && respuesta.status === 401)) {
      borrar(config.api, anterior)
    }
  }
  return respuesta
}
