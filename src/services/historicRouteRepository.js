import { historicRoute } from '../data/historicRoute.js'

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function createLocalHistoricRouteRepository() {
  return { async getRoute({ signal } = {}) { signal?.throwIfAborted(); return structuredClone(historicRoute) } }
}

// Adaptador para GET /rutas/:uuid, ya disponible en backend/turismo.cjs.
// La asociación UUID → punto del dibujo es explícita; nunca se deduce por nombre.
export function createApiHistoricRouteRepository({ routeId, stopBindings, fetchRoute }) {
  if (!uuid.test(routeId || '') || typeof fetchRoute !== 'function') throw new Error('Configura la ruta publicada y su consulta a la API.')
  const bindings = Object.entries(stopBindings || {})
  const keys = historicRoute.stops.map(stop => stop.key)
  if (bindings.length !== keys.length || bindings.some(([id, key]) => !uuid.test(id) || !keys.includes(key)) || new Set(bindings.map(([, key]) => key)).size !== keys.length || new Set(bindings.map(([id]) => id.toLowerCase())).size !== keys.length) {
    throw new Error('Asocia las doce paradas del dibujo con sus UUID reales.')
  }
  const bindingMap = new Map(bindings.map(([id, key]) => [id.toLowerCase(), key]))
  return {
    async getRoute({ signal } = {}) {
      const payload = await fetchRoute(`/rutas/${routeId}`, { signal, cache: 'no-store' })
      signal?.throwIfAborted()
      if (typeof payload?.ruta?.ruta_id !== 'string' || payload.ruta.ruta_id.toLowerCase() !== routeId.toLowerCase() || !Array.isArray(payload.paradas) || payload.paradas.length !== keys.length || typeof payload.ruta.nombre !== 'string' || !payload.ruta.nombre.trim()) {
        throw new Error('La respuesta de la ruta no coincide con el mapa ilustrado.')
      }
      const ids = new Set()
      const stops = payload.paradas.map(row => {
        const id = typeof row.parada_id === 'string' ? row.parada_id.toLowerCase() : ''
        const template = historicRoute.stops.find(stop => stop.key === bindingMap.get(id))
        if (!template || ids.has(id) || typeof row.ruta_id !== 'string' || row.ruta_id.toLowerCase() !== routeId.toLowerCase() || row.orden !== template.order || typeof row.nombre !== 'string' || !row.nombre.trim()) {
          throw new Error('Las paradas o su orden no coinciden con la ilustración. Revisa las asociaciones.')
        }
        ids.add(id)
        const hasCoordinates = row.latitud != null || row.longitud != null
        const validCoordinates = Number.isFinite(row.latitud) && Number.isFinite(row.longitud) && Math.abs(row.latitud) <= 90 && Math.abs(row.longitud) <= 180
        if (hasCoordinates && !validCoordinates) throw new Error('La API devolvió coordenadas inválidas.')
        return { ...structuredClone(template), databaseId: id, attractionDatabaseId: row.atractivo_id || null, name: row.nombre, description: row.descripcion || '', coordinates: validCoordinates ? { latitude: row.latitud, longitude: row.longitud } : null }
      }).sort((a, b) => a.order - b.order)
      return { ...structuredClone(historicRoute), source: 'api', databaseId: routeId.toLowerCase(), name: payload.ruta.nombre, description: payload.ruta.descripcion || '', stops }
    },
  }
}

// Único punto de sustitución para conectar esta vista y la ficha del circuito.
export const historicRouteRepository = createLocalHistoricRouteRepository()
