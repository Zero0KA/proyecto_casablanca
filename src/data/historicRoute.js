import { historicLocations } from './historicLocations.js'

// Las posiciones son del dibujo (1100 × 820), nunca latitud/longitud.
export const historicRoute = {
  key: 'casco_historico',
  databaseId: null,
  source: 'local',
  name: 'Casco Histórico',
  description: 'Doce paradas por las plazas, casas y espacios culturales del centro de Casablanca.',
  illustration: { width: 1100, height: 820, image: 'maps/casco-historico.svg' },
  // El trazado sigue el folleto; no representa una geometría de navegación GPS.
  path: 'M 836 250 L 860 210 L 900 260 L 800 615 L 835 690 L 790 680 L 800 615 L 700 615 L 310 615 L 175 615 L 150 615 L 150 516 L 150 430 L 183 430 L 280 350 L 365 430 L 395 430 L 410 250 L 430 250 L 255 247 L 200 248 L 115 150',
  stops: [
    { key: 'el_control', order: 1, name: 'El Control', kind: 'Hito del recorrido', symbol: 'monument', position: { x: 836, y: 250 }, description: 'Punto de inicio del circuito del Casco Histórico.' },
    { key: 'plaza_bicentenario', order: 2, name: 'Plaza Bicentenario', kind: 'Plaza', symbol: 'park', position: { x: 835, y: 690 }, description: 'Primera plaza del recorrido, antes de continuar por Chacabuco.' },
    { key: 'casa_jorge_montt', order: 3, name: 'Casa Presidente Jorge Montt', kind: 'Casa patrimonial', symbol: 'house', position: { x: 700, y: 615 }, description: 'Una de las casas señaladas en el circuito del Casco Histórico.' },
    { key: 'casa_alejandro_galaz', order: 4, name: 'Casa Poeta Alejandro Galaz', kind: 'Casa patrimonial', symbol: 'house', position: { x: 310, y: 615 }, description: 'Parada del recorrido por las casas del centro de Casablanca.' },
    { key: 'almacen_don_lalo', order: 5, name: 'Almacén Don Lalo', kind: 'Comercio tradicional', symbol: 'shop', position: { x: 175, y: 615 }, description: 'El almacén forma parte del circuito del Casco Histórico.' },
    { key: 'casa_julio_montt', order: 6, name: 'Casa Julio Montt Salamanca', kind: 'Casa patrimonial', symbol: 'house', position: { x: 150, y: 516 }, description: 'Casa señalada entre Almacén Don Lalo y la Cooperativa Agrícola.' },
    { key: 'cooperativa_agricola', order: 7, name: 'Cooperativa Agrícola', kind: 'Patrimonio local', symbol: 'shop', position: { x: 150, y: 430 }, description: 'Parada previa al paso por la Plaza de Armas.' },
    { key: 'plaza_armas', order: 8, name: 'Plaza de Armas', kind: 'Plaza', symbol: 'park', position: { x: 280, y: 350 }, attractionId: 2, description: 'La plaza central de Casablanca, parte del circuito del Casco Histórico.' },
    { key: 'bomberos', order: 9, name: '1.ª Compañía de Bomberos', kind: 'Patrimonio local', symbol: 'firehouse', position: { x: 395, y: 430 }, description: 'El circuito continúa desde la Plaza de Armas hacia la compañía de bomberos.' },
    { key: 'municipalidad', order: 10, name: 'I. Municipalidad de Casablanca', kind: 'Edificio público', symbol: 'civic', position: { x: 430, y: 250 }, description: 'Edificio señalado en el recorrido por la avenida Constitución.' },
    { key: 'parroquia_santa_barbara', order: 11, name: 'Parroquia Santa Bárbara', kind: 'Patrimonio religioso', symbol: 'church', position: { x: 255, y: 247 }, attractionId: 3, description: 'La parroquia es la penúltima parada del circuito.' },
    { key: 'centro_cultural_museo', order: 12, name: 'Centro Cultural y Museo', kind: 'Cultura y patrimonio', symbol: 'museum', position: { x: 115, y: 150 }, attractionId: 5, description: 'El circuito del Casco Histórico termina en el Centro Cultural y Museo.' },
  ].map(stop => ({ ...stop, databaseId: null, coordinates: historicLocations[stop.key] || null })),
}

export function historicStopForAttraction(id) {
  // Museo y Centro Cultural comparten esta parada; conservan sus propias fichas.
  return historicRoute.stops.find(stop => stop.attractionId === id || (id === 1 && stop.key === 'centro_cultural_museo')) || null
}

export function historicMapUrl(stopKey) {
  return stopKey ? `/mapas/casco-historico?parada=${encodeURIComponent(stopKey)}` : '/mapas/casco-historico'
}
