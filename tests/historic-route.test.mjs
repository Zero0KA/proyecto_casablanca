import test from 'node:test'
import assert from 'node:assert/strict'
import { historicRoute } from '../src/data/historicRoute.js'
import { createApiHistoricRouteRepository, createLocalHistoricRouteRepository } from '../src/services/historicRouteRepository.js'

const routeId = 'a1111111-1111-4111-8111-111111111111'
const stopId = index => `00000000-0000-4000-8000-${String(index + 1).padStart(12, '0')}`
const bindings = Object.fromEntries(historicRoute.stops.map((stop, index) => [stopId(index), stop.key]))
function fixture() {
  return {
    ruta: { ruta_id: routeId, nombre: 'Nombre desde la API', descripcion: 'Contenido de la ruta publicada.' },
    paradas: historicRoute.stops.map((stop, index) => ({ parada_id: stopId(index), ruta_id: routeId, atractivo_id: null, orden: stop.order, nombre: `Nombre actualizado ${stop.order}`, descripcion: 'Descripción desde la BD.', latitud: null, longitud: null })),
  }
}
function repository(payload, customBindings = bindings) { return createApiHistoricRouteRepository({ routeId, stopBindings: customBindings, fetchRoute: async () => payload }) }

test('El catálogo conserva las doce paradas del folleto, con orden e identificadores únicos', () => {
  assert.deepEqual(historicRoute.stops.map(stop => stop.order), Array.from({ length: 12 }, (_, index) => index + 1))
  assert.equal(new Set(historicRoute.stops.map(stop => stop.key)).size, 12)
  assert.equal(historicRoute.stops[0].name, 'El Control')
  assert.equal(historicRoute.stops[11].name, 'Centro Cultural y Museo')
  for (const stop of historicRoute.stops) {
    assert.ok(Number.isFinite(stop.coordinates.latitude) && Math.abs(stop.coordinates.latitude) <= 90)
    assert.ok(Number.isFinite(stop.coordinates.longitude) && Math.abs(stop.coordinates.longitude) <= 180)
    assert.ok(['cartographic','approximate'].includes(stop.coordinates.accuracy))
    assert.equal(stop.databaseId, null)
    assert.ok(Number.isFinite(stop.position.x) && stop.position.x > 0 && stop.position.x < historicRoute.illustration.width)
    assert.ok(Number.isFinite(stop.position.y) && stop.position.y > 0 && stop.position.y < historicRoute.illustration.height)
  }
})

test('El proveedor local entrega una copia independiente y respeta la cancelación', async () => {
  const local = createLocalHistoricRouteRepository()
  const copy = await local.getRoute()
  copy.stops[0].position.x = 0
  assert.equal((await local.getRoute()).stops[0].position.x, historicRoute.stops[0].position.x)
  const controller = new AbortController(); controller.abort()
  await assert.rejects(local.getRoute({ signal: controller.signal }), { name: 'AbortError' })
})

test('El adaptador usa la consulta existente, el UUID y la señal de cancelación', async () => {
  const controller = new AbortController()
  const live = createApiHistoricRouteRepository({ routeId, stopBindings: bindings, fetchRoute: async (path, options) => {
    assert.equal(path, `/rutas/${routeId}`)
    assert.equal(options.signal, controller.signal)
    assert.equal(options.cache, 'no-store')
    return fixture()
  } })
  const result = await live.getRoute({ signal: controller.signal })
  assert.equal(result.source, 'api')
  assert.equal(result.databaseId, routeId)
  assert.equal(result.name, 'Nombre desde la API')
})

test('Asocia por UUID y conserva el orden aunque cambien los nombres o el orden del JSON', async () => {
  const payload = fixture(); payload.paradas.reverse()
  const result = await repository(payload).getRoute()
  assert.equal(result.stops[0].key, 'el_control')
  assert.equal(result.stops[0].name, 'Nombre actualizado 1')
  assert.equal(result.stops[11].databaseId, stopId(11))
  assert.deepEqual(result.stops.map(stop => stop.order), historicRoute.stops.map(stop => stop.order))
})

test('Mantiene separados píxeles y coordenadas reales; acepta cero y ausencia de GPS', async () => {
  const payload = fixture(); payload.paradas[0].latitud = 0; payload.paradas[0].longitud = 0
  const result = await repository(payload).getRoute()
  assert.deepEqual(result.stops[0].coordinates, { latitude: 0, longitude: 0 })
  assert.deepEqual(result.stops[0].position, historicRoute.stops[0].position)
  assert.equal(result.stops[1].coordinates, null)
  result.stops[0].position.x = 0
  assert.notEqual(historicRoute.stops[0].position.x, 0)
})

for (const [label, mutate] of [
  ['falta una parada', payload => payload.paradas.pop()],
  ['sobran paradas', payload => payload.paradas.push({ ...payload.paradas[0] })],
  ['UUID duplicado', payload => { payload.paradas[1] = { ...payload.paradas[0] } }],
  ['cambió el orden del circuito', payload => { payload.paradas[0].orden = 2 }],
  ['parada de otra ruta', payload => { payload.paradas[0].ruta_id = stopId(6) }],
  ['ruta distinta', payload => { payload.ruta.ruta_id = stopId(6) }],
  ['nombre vacío', payload => { payload.paradas[0].nombre = ' ' }],
  ['latitud fuera de rango', payload => { payload.paradas[0].latitud = 91; payload.paradas[0].longitud = -71 }],
  ['longitud fuera de rango', payload => { payload.paradas[0].latitud = -33; payload.paradas[0].longitud = 181 }],
  ['coordenadas incompletas', payload => { payload.paradas[0].latitud = -33 }],
  ['coordenadas como texto', payload => { payload.paradas[0].latitud = '-33'; payload.paradas[0].longitud = '-71' }],
  ['orden como texto', payload => { payload.paradas[0].orden = '1' }],
]) test(`Rechaza la respuesta sin sustituirla por datos locales: ${label}`, async () => {
  const payload = fixture(); mutate(payload)
  await assert.rejects(repository(payload).getRoute())
})

test('Rechaza asociaciones incompletas o repetidas antes de consultar la API', () => {
  assert.throws(() => repository(fixture(), {}))
  assert.throws(() => repository(fixture(), { ...bindings, [stopId(1)]: 'el_control' }))
  assert.throws(() => createApiHistoricRouteRepository({ routeId: "1; DROP TABLE ruta", stopBindings: bindings, fetchRoute: async () => fixture() }))
})

test('Propaga la caída de API y la cancelación sin simular datos de la BD', async () => {
  const offline = createApiHistoricRouteRepository({ routeId, stopBindings: bindings, fetchRoute: async () => { throw new Error('Desconectado') } })
  await assert.rejects(offline.getRoute(), /Desconectado/)
  const controller = new AbortController()
  const aborted = createApiHistoricRouteRepository({ routeId, stopBindings: bindings, fetchRoute: async () => { controller.abort(); return fixture() } })
  await assert.rejects(aborted.getRoute({ signal: controller.signal }), { name: 'AbortError' })
})

// Resultado observado 29/10/2026: 19 pruebas correctas, 0 fallos.
// Se probaron datos locales y respuestas simuladas de API; no se modificó PostgreSQL.
