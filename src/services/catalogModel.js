import { attractionAliases, routeAliases, historicDatabaseRouteId, historicStopBindings } from '../data/catalogBindings.js'
import { historicRoute } from '../data/historicRoute.js'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const fail = () => { throw new Error('El contenido recibido no es válido. Intenta nuevamente.') }
function id(value) { if (typeof value !== 'string' || !UUID.test(value)) fail(); return value.toLowerCase() }
function text(value) { if (value != null && typeof value !== 'string') fail(); return value || '' }
function name(value, preview) { const result = text(value); if (!preview && !result.trim()) fail(); return result || 'Sin nombre' }
function unique(rows, key) { const values = rows.map(row => row[key]); if (new Set(values).size !== values.length) fail(); return rows }
export function coordinates(row) {
  if (row.latitud == null && row.longitud == null) return null
  if (!Number.isFinite(row.latitud) || !Number.isFinite(row.longitud) || Math.abs(row.latitud) > 90 || Math.abs(row.longitud) > 180) fail()
  return { latitude: row.latitud, longitude: row.longitud }
}
function category(row, preview) { return { id: id(row.categoria_id), code: text(row.codigo), icon: text(row.icono_codigo), name: name(row.nombre, preview), active: row.activo !== false } }
function place(row, preview) {
  if (!Array.isArray(row.categorias)) fail()
  return { id: id(row.atractivo_id), name: name(row.nombre, preview), description: text(row.descripcion), image: text(row.imagen_principal), imageAlt: text(row.imagen_texto_alternativo), coordinates: coordinates(row), categories: unique(row.categorias.map(item => category(item, preview)), 'id'), state: preview ? text(row.estado) : 'publicado' }
}
function route(row, preview) {
  const routeId = id(row.ruta_id)
  if (!Array.isArray(row.paradas)) fail()
  const stops = unique(row.paradas.map(item => {
    if (id(item.ruta_id) !== routeId || !Number.isInteger(item.orden) || item.orden < 1) fail()
    return { key: id(item.parada_id), id: id(item.parada_id), databaseId: id(item.parada_id), order: item.orden, name: name(item.nombre, preview), description: text(item.descripcion), image: text(item.imagen_principal), imageAlt: text(item.imagen_texto_alternativo), coordinates: coordinates(item), attractionId: item.atractivo_id == null ? null : id(item.atractivo_id) }
  }), 'id').sort((a, b) => a.order - b.order)
  if (new Set(stops.map(stop => stop.order)).size !== stops.length) fail()
  if (!preview && stops.some((stop, index) => stop.order !== index + 1)) fail()
  const minutes = row.duracion_estimada_minutos
  if (minutes != null && (!Number.isInteger(minutes) || minutes <= 0)) fail()
  const illustrated = routeId === historicDatabaseRouteId && stops.length === historicRoute.stops.length && stops.every(stop => {
    const template = historicRoute.stops.find(item => item.key === historicStopBindings[stop.id])
    return template && template.order === stop.order
  })
  return { id: routeId, key: routeId, databaseId: routeId, source: 'api', name: name(row.nombre, preview), description: text(row.descripcion), image: text(row.imagen_principal), imageAlt: text(row.imagen_texto_alternativo), minutes: minutes ?? null, state: preview ? text(row.estado) : 'publicado', illustrated,
    stops: stops.map(stop => {
      const template = routeId === historicDatabaseRouteId && historicRoute.stops.find(item => item.key === historicStopBindings[stop.id])
      // Solo se heredan metadatos del dibujo; los textos, asociaciones y GPS vienen de BD.
      return { ...stop, symbol: template?.symbol || 'house', kind: template?.kind || 'Parada del recorrido', ...(illustrated ? { position: { ...template.position } } : {}) }
    }),
    ...(illustrated ? { illustration: { ...historicRoute.illustration }, path: historicRoute.path } : {}),
  }
}
export function normalizeCatalog(payload, preview = false) {
  if (!payload || payload.vista_previa !== preview || !Array.isArray(payload.atractivos) || !Array.isArray(payload.rutas) || !Array.isArray(payload.categorias)) fail()
  return { places: unique(payload.atractivos.map(row => place(row, preview)), 'id'), routes: unique(payload.rutas.map(row => route(row, preview)), 'id'), categories: unique(payload.categorias.map(row => category(row, preview)), 'id'), preview }
}
function canonical(value, aliases) { return typeof value === 'string' && UUID.test(value) ? value.toLowerCase() : typeof value === 'string' && Object.hasOwn(aliases, value) ? aliases[value] : null }
export const canonicalAttractionId = value => canonical(value, attractionAliases)
export const canonicalRouteId = value => canonical(value, routeAliases)
export function withPreview(path, preview = false) { return preview ? `${path}${path.includes('?') ? '&' : '?'}vista_previa=1` : path }
export function routeMapUrl(routeId, preview = false) { return withPreview(routeId === historicDatabaseRouteId ? '/mapas/casco-historico' : `/mapas/rutas/${routeId}`, preview) }
export function routeSummary(item, preview = false) { return { ...item, to: withPreview(`/routes/${item.id}`, preview), places: item.stops } }
export function selectedStopKey(route, value) {
  if (route.stops.some(stop => stop.key === value)) return value
  const boundId = Object.keys(historicStopBindings).find(key => historicStopBindings[key] === value)
  return route.stops.some(stop => stop.key === boundId) ? boundId : null
}
