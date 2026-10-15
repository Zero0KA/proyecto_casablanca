import { createContext, useContext } from 'react'
import { fetchApi } from './demoTransport'
export const SessionContext = createContext(null)
export const API = `${import.meta.env.BASE_URL}api`
export function useSession() { return useContext(SessionContext) }
export async function apiFetch(ruta, opciones = {}) {
  const respuesta = await fetchApi(`${API}${ruta}`, { credentials: 'same-origin', ...opciones })
  let datos
  try { datos = await respuesta.json() } catch (fallo) { if (fallo.name === 'AbortError') throw fallo; throw new Error('El servicio no respondió correctamente. Intenta nuevamente.', { cause: fallo }) }
  if (!respuesta.ok) { const error = new Error(datos.mensaje === 'No se pudo completar la consulta. Comprueba la API y la BD.' ? 'No se pudo completar la consulta. Intenta nuevamente.' : datos.mensaje || 'No se pudo completar la operación.'); error.status = respuesta.status; throw error }
  return datos
}
export function publicImage(value) {
  if (typeof value !== 'string') return null
  if (/^https?:\/\//i.test(value)) return value
  if (value.startsWith('/images/')) return import.meta.env.BASE_URL + value.slice(1)
  if (value.startsWith(import.meta.env.BASE_URL) && !value.startsWith('//')) return value
  if (value.startsWith('images/')) return import.meta.env.BASE_URL + value
  return null
}
