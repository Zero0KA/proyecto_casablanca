import { routes } from './routes'
import { attractions } from './attractions'
import { historicRoute } from './historicRoute'
const descriptions = { 1: 'Visita al Museo Arqueológico y Antropológico de Casablanca.', 2: historicRoute.description, 3: 'Un recorrido por la Plaza de Armas de Casablanca.' }
export const routeCatalog = routes.map(route => ({ key: `catalogo-${route.id}`, name: route.name, description: descriptions[route.id] || '', to: `/routes/catalogo/${route.id}`, illustrated: route.id === 2, places: route.id === 2 ? historicRoute.stops.map(stop => ({ ...stop, id: stop.key })) : route.attractionIds.map(id => attractions.find(place => place.id === id)).filter(Boolean) }))
export function publishedRoute(route) { return { key: route.ruta_id, name: route.nombre, description: route.descripcion, minutes: route.duracion_estimada_minutos, to: `/routes/${route.ruta_id}`, places: [] } }
