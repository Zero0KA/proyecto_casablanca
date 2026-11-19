import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { normalizeCatalog, canonicalAttractionId, canonicalRouteId, routeMapUrl, selectedStopKey, withPreview } from '../src/services/catalogModel.js'
import { historicDatabaseRouteId, historicStopBindings } from '../src/data/catalogBindings.js'

const seed = JSON.parse(fs.readFileSync(new URL('../bd/catalogo_inicial.json', import.meta.url), 'utf8'))
function fixture(preview = false) {
  return { vista_previa: preview, categorias: [], atractivos: seed.atractivos.map(item => ({ atractivo_id: item.id, nombre: item.nombre, descripcion: item.descripcion, imagen_principal: item.imagen, latitud: item.latitud, longitud: item.longitud, estado: 'borrador', categorias: [] })), rutas: seed.rutas.map(item => ({ ruta_id: item.id, nombre: item.nombre, descripcion: item.descripcion, duracion_estimada_minutos: 60, imagen_principal: item.imagen, estado: 'borrador', paradas: item.paradas.map(stop => ({ parada_id: stop.id, ruta_id: item.id, orden: stop.order, atractivo_id: stop.atractivo_id, nombre: stop.name, descripcion: stop.description, latitud: stop.latitud, longitud: stop.longitud })) })) }
}

test('El catálogo convierte IDs de BD sin agregar las antiguas copias locales', () => {
  const catalog = normalizeCatalog(fixture())
  assert.equal(catalog.places.length, 6); assert.equal(catalog.routes.length, 3)
  assert(catalog.routes.every(route => route.source === 'api'))
})
test('La edición de texto e imagen se conserva literalmente; no se recupera texto local', () => {
  const input = fixture(); input.rutas[1].nombre = 'Nuevo nombre'; input.rutas[1].paradas[0].nombre = '<script>alert(1)</script>'; input.atractivos[0].imagen_principal = 'images/plaza.jpg'
  const result = normalizeCatalog(input)
  assert.equal(result.routes[1].name, 'Nuevo nombre'); assert.equal(result.routes[1].stops[0].name, '<script>alert(1)</script>'); assert.equal(result.places[0].image, 'images/plaza.jpg')
})
test('GPS nulo sigue nulo aunque exista una aproximación en el folleto', () => {
  const casco = normalizeCatalog(fixture()).routes.find(item => item.id === historicDatabaseRouteId)
  assert.equal(casco.stops.length, 12); assert.equal(casco.stops.filter(stop => stop.coordinates).length, 7)
  assert.equal(casco.stops[1].coordinates, null)
})
test('El dibujo se habilita por las doce identidades y su orden, sin comparar nombres', () => {
  const input = fixture(); input.rutas[1].nombre = 'Nombre cambiado'; input.rutas[1].paradas.reverse()
  const route = normalizeCatalog(input).routes[1]
  assert.equal(route.illustrated, true); assert.equal(route.stops[0].order, 1)
  assert(route.stops.every(stop => Number.isFinite(stop.position.x)))
})
test('Cambiar el orden conserva el recorrido vivo y deshabilita el dibujo que ya no coincide', () => {
  const input = fixture(); [input.rutas[1].paradas[0].orden, input.rutas[1].paradas[1].orden] = [2, 1]
  const route = normalizeCatalog(input).routes[1]
  assert.equal(route.illustrated, false); assert.equal(route.stops[0].id, input.rutas[1].paradas[1].parada_id); assert.equal(route.stops.length, 12)
})
test('Eliminar una parada no la reconstruye desde el folleto', () => {
  const input = fixture(); input.rutas[1].paradas.pop()
  const route = normalizeCatalog(input).routes[1]
  assert.equal(route.illustrated, false); assert.equal(route.stops.length, 11)
})
test('Una parada nueva funciona en la lista/geográfico sin asignarle píxeles inventados', () => {
  const input = fixture(); input.rutas[1].paradas.push({ ...input.rutas[1].paradas[0], parada_id: 'a1111111-1111-4111-8111-111111111111', orden: 13 })
  const route = normalizeCatalog(input).routes[1]
  assert.equal(route.illustrated, false); assert.equal(route.stops.length, 13); assert.equal(route.stops[12].position, undefined)
})
test('Iguales nombres con diferentes IDs son registros distintos, no una fusión arbitraria', () => {
  const input = fixture(); input.atractivos[1].nombre = input.atractivos[0].nombre
  assert.equal(normalizeCatalog(input).places.length, 6)
})
test('Una lista pública vacía permanece vacía', () => {
  assert.deepEqual(normalizeCatalog({ vista_previa: false, atractivos: [], rutas: [], categorias: [] }), { places: [], routes: [], categories: [], preview: false })
})
test('La vista previa acepta borradores incompletos y no inventa duración ni GPS', () => {
  const input = fixture(true); input.rutas[0].nombre = null; input.rutas[0].duracion_estimada_minutos = null; input.rutas[0].paradas = []
  const route = normalizeCatalog(input, true).routes[0]
  assert.equal(route.name, 'Sin nombre'); assert.equal(route.minutes, null); assert.equal(route.stops.length, 0)
})
test('Una respuesta administrativa nunca se acepta como catálogo público', () => {
  assert.throws(() => normalizeCatalog(fixture(true)))
  assert.throws(() => normalizeCatalog(fixture(), true))
})
for (const [label, mutate] of [
  ['UUID repetido', p => { p.atractivos[1].atractivo_id = p.atractivos[0].atractivo_id }],
  ['parada repetida', p => { p.rutas[1].paradas.push({ ...p.rutas[1].paradas[0] }) }],
  ['parada de otra ruta', p => { p.rutas[1].paradas[0].ruta_id = p.rutas[0].ruta_id }],
  ['posición repetida', p => { p.rutas[1].paradas[0].orden = 2 }],
  ['hueco en el orden publicado', p => { p.rutas[1].paradas[11].orden = 13 }],
  ['GPS parcial', p => { p.rutas[1].paradas[0].longitud = null }],
  ['GPS como cadena', p => { p.rutas[1].paradas[0].latitud = '-33' }],
  ['latitud fuera de rango', p => { p.atractivos[0].latitud = 91 }],
  ['nombre público vacío', p => { p.atractivos[0].nombre = ' ' }],
  ['UUID con SQL', p => { p.rutas[0].ruta_id = "');DROP TABLE ruta;--" }],
  ['colección ausente', p => { delete p.rutas }],
]) test(`El catálogo rechaza datos incoherentes: ${label}`, () => { const input = fixture(); mutate(input); assert.throws(() => normalizeCatalog(input)) })

test('Enlaces antiguos resuelven UUID conocidos sin buscar ni crear por nombre', () => {
  assert.equal(canonicalAttractionId('1'), seed.atractivos[0].id)
  assert.equal(canonicalRouteId('2'), historicDatabaseRouteId)
  assert.equal(canonicalRouteId('9999'), null); assert.equal(canonicalAttractionId('constructor'), null)
})
test('La selección antigua se convierte a UUID y se conserva entre vistas', () => {
  const route = normalizeCatalog(fixture()).routes[1]
  const first = Object.keys(historicStopBindings)[0]
  assert.equal(selectedStopKey(route, 'el_control'), first); assert.equal(selectedStopKey(route, first), first); assert.equal(selectedStopKey(route, 'no_existe'), null)
})
test('Los enlaces de vista previa y de mapas conservan la identidad del registro', () => {
  assert.equal(routeMapUrl(historicDatabaseRouteId), '/mapas/casco-historico')
  assert.equal(withPreview('/routes?orden=nombre', true), '/routes?orden=nombre&vista_previa=1')
  assert.equal(routeMapUrl(seed.rutas[0].id, true), `/mapas/rutas/${seed.rutas[0].id}?vista_previa=1`)
})

// RESULTADO 19/11/2026: 25 pruebas correctas, 0 fallos; fixtures de datos, sin escrituras en PostgreSQL.
