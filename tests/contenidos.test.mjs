import test from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { readFile } from 'node:fs/promises'
import { historicRoute } from '../src/data/historicRoute.js'
import { contentPayload, newContent } from '../src/data/contentForm.js'
const require = createRequire(import.meta.url)
const { validateContent } = require('../backend/contenidos.cjs')
const uuid = 'a1111111-1111-4111-8111-111111111111'
const valid = { traducciones:{es:{nombre:'Plaza',descripcion:'Descripción'},en:{nombre:'Square',descripcion:'Description'}},imagen_principal:'images/plaza.jpg',latitud:-33.3205,longitud:-71.4101,categoria_ids:[] }

test('El mapa distingue doce referencias, siete cartográficas y cinco aproximadas', () => {
  assert.equal(historicRoute.stops.filter(s=>s.coordinates.accuracy==='cartographic').length,7)
  assert.equal(historicRoute.stops.filter(s=>s.coordinates.accuracy==='approximate').length,5)
  assert.ok(historicRoute.stops.every(s=>s.coordinates.reference))
  assert.notDeepEqual(historicRoute.stops[0].coordinates,historicRoute.stops[0].position)
})
test('La carga inicial conserva identidades, relaciones y el orden del folleto', async () => {
  const catalog = JSON.parse(await readFile(new URL('../bd/catalogo_inicial.json',import.meta.url),'utf8'))
  const route = catalog.rutas.find(r=>r.local_id===2)
  assert.equal(catalog.atractivos.length,6);assert.equal(catalog.rutas.length,3)
  assert.equal(catalog.rutas.reduce((n,r)=>n+r.paradas.length,0),14)
  assert.deepEqual(route.paradas.map(p=>p.key),historicRoute.stops.map(p=>p.key))
  assert.equal(new Set(catalog.rutas.flatMap(r=>r.paradas.map(p=>p.id))).size,14)
  for (const p of route.paradas) {
    const geo = historicRoute.stops.find(s=>s.key===p.key).coordinates
    assert.equal(p.latitud,geo.accuracy==='cartographic'?geo.latitude:null)
    assert.equal(p.longitud,geo.accuracy==='cartographic'?geo.longitude:null)
    if (p.atractivo_id) assert.ok(catalog.atractivos.some(a=>a.id===p.atractivo_id))
  }
})
test('Validación admite coordenadas cero, Unicode, borradores sin GPS e imágenes existentes', () => {
  const result = validateContent({...valid,latitud:0,longitud:0},'atractivo')
  assert.equal(result.lat,0);assert.equal(result.lon,0)
  assert.equal(validateContent({...valid,latitud:null,longitud:null},'atractivo').lat,null)
  assert.equal(validateContent({...valid,traducciones:{es:{nombre:'á'.repeat(200),descripcion:'Texto'}}},'atractivo').translations[0].name.length,200)
})
for (const [label,change] of [
  ['latitud fuera de rango',{latitud:90.1}],['longitud fuera de rango',{longitud:-180.1}],
  ['coordenadas incompletas',{latitud:null}],['números enviados como texto',{latitud:'-33.32'}],
  ['campo de rol añadido',{administrador:true}],['estado enviado en el formulario',{estado:'publicado'}],
  ['UUID como arreglo',{categoria_ids:[[uuid]]}],['UUID repetidos',{categoria_ids:[uuid,uuid]}],
  ['imagen con JavaScript',{imagen_principal:'javascript:alert(1)'}],['ruta de archivo local',{imagen_principal:'file:///etc/passwd'}],
  ['imagen relativa fuera del catálogo',{imagen_principal:'../backend/.env'}],['URL con credenciales',{imagen_principal:'https://usuario:secreto@example.com/a.jpg'}],
  ['nombre vacío',{traducciones:{es:{nombre:' ',descripcion:'Texto'}}}],['idioma no admitido',{traducciones:{es:{nombre:'A',descripcion:'B'},fr:{nombre:'A',descripcion:'B'}}}],
]) test(`Validación rechaza ${label}`,()=>assert.throws(()=>validateContent({...valid,...change},'atractivo'),{code:'VALIDATION'}))
test('Una ruta requiere duración entera positiva cuando se especifica',()=>{
  const input={traducciones:valid.traducciones,imagen_principal:null,duracion_estimada_minutos:null}
  assert.equal(validateContent(input,'ruta').minutes,null)
  for(const value of [0,-1,1.5,'30',100001])assert.throws(()=>validateContent({...input,duracion_estimada_minutos:value},'ruta'),{code:'VALIDATION'})
})
test('El formulario convierte números y preserva la obligación de una traducción inglesa existente',()=>{
  const form=newContent('parada');form.latitud='-33.32';form.longitud='-71.41';form.orden='2'
  let payload=contentPayload(form,'parada');assert.equal(payload.latitud,-33.32);assert.equal(payload.orden,2);assert.equal(payload.atractivo_id,null);assert.equal(payload.traducciones.en,undefined)
  form.englishExists=true;payload=contentPayload(form,'parada');assert.ok(payload.traducciones.en)
  assert.throws(()=>validateContent(payload,'parada'),{code:'VALIDATION'})
})

// RESULTADO DOCUMENTADO 30/10/2026: 19 pruebas de este archivo correctas (38 al incluir historic-route.test.mjs).
