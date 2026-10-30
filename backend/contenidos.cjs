'use strict';
const express = require('express');
const { exigirCookie } = require('./sesiones.cjs');
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const allowedImages = new Set(['images/museo.jpg', 'images/plaza.jpg', 'images/parroquia.jpg', 'images/biblioteca.jpg', 'images/centroCultural.jpg', 'images/teatro.png', 'maps/casco-historico.svg']);
function bad(message) { const error = new Error(message); error.code = 'VALIDATION'; throw error; }
function object(value, allowed) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.keys(value).some(key => !allowed.includes(key))) bad('El formulario contiene campos no admitidos.');
}
function text(value, max, label, required = true) {
  if (value == null && !required) return null;
  if (typeof value !== 'string' || Array.from(value.trim()).length > max || (required && !value.trim())) bad(`Revisa ${label}.`);
  return value.trim() || null;
}
function identifier(value) { if (typeof value !== 'string' || !UUID.test(value)) bad('Identificador inválido.'); return value.toLowerCase(); }
function coordinates(body) {
  const lat = body.latitud, lon = body.longitud;
  if (lat == null && lon == null) return { lat: null, lon: null };
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) bad('Indica latitud y longitud válidas, o deja ambas vacías.');
  return { lat, lon };
}
function translations(value) {
  object(value, ['es', 'en']);
  if (!value.es) bad('Completa el nombre y la descripción en español.');
  return ['es','en'].filter(lang => value[lang] != null).map(lang => {
    const row = value[lang]; object(row, ['nombre','descripcion','imagen_texto_alternativo']);
    return { lang, name: text(row.nombre, 200, `el nombre (${lang})`), description: text(row.descripcion, 20000, `la descripción (${lang})`), alt: text(row.imagen_texto_alternativo, 300, 'el texto de imagen', false) };
  });
}
function image(value) {
  if (value == null || value === '') return null;
  const ref = text(value, 2048, 'la imagen');
  if (allowedImages.has(ref)) return ref;
  // Solo referencia: la API no descarga archivos ni realiza solicitudes a esta URL.
  try { const url = new URL(ref); if (url.protocol === 'https:' && !url.username && !url.password) return ref; } catch { /* Se informa como un campo inválido. */ }
  bad('Selecciona una imagen existente o una referencia HTTPS.');
}
function validateContent(body, kind) {
  const fields = ['traducciones','imagen_principal'];
  if (kind === 'ruta') fields.push('duracion_estimada_minutos');
  else fields.push('latitud','longitud', ...(kind === 'parada' ? ['atractivo_id','orden'] : ['categoria_ids']));
  object(body, fields);
  const result = { translations: translations(body.traducciones), image: image(body.imagen_principal) };
  if (kind === 'ruta') {
    const minutes = body.duracion_estimada_minutos;
    if (minutes != null && (!Number.isInteger(minutes) || minutes < 1 || minutes > 100000)) bad('La duración debe ser un número entero positivo.');
    result.minutes = minutes ?? null;
  } else Object.assign(result, coordinates(body));
  if (kind === 'atractivo') {
    const ids = body.categoria_ids ?? [];
    if (!Array.isArray(ids) || ids.length > 100) bad('Revisa las categorías.');
    result.categories = ids.map(identifier);
    if (new Set(result.categories).size !== result.categories.length) bad('Hay categorías repetidas.');
  }
  if (kind === 'parada') {
    result.attractionId = body.atractivo_id == null || body.atractivo_id === '' ? null : identifier(body.atractivo_id);
    if (body.orden != null && (!Number.isInteger(body.orden) || body.orden < 1 || body.orden > 100000)) bad('El orden debe ser un entero positivo.');
    result.order = body.orden;
  }
  return result;
}

function crearRouterContenidos(pool) {
  const router = express.Router(); router.use(exigirCookie);
  function failure(res, error) {
    console.error('Administración de contenido:', error.code || 'sin código');
    const status = error.code === '42501' ? 403 : error.code === 'P0002' ? 404 : ['23503','23505','23514','55000','55P03','40P01'].includes(error.code) ? 409 : ['VALIDATION','22023','22001','23502','22P02'].includes(error.code) ? 400 : 503;
    const message = error.code === 'VALIDATION' ? error.message : error.code === '42501' ? 'Se requiere una sesión administrativa válida.' : error.code === 'P0002' ? 'El registro ya no existe.' : error.code === '23503' ? 'El registro no existe o tiene asociaciones que impiden esta operación.' : error.code === '23505' ? 'Hay un registro o una posición repetida. Recarga la lista.' : ['55P03','40P01'].includes(error.code) ? 'Otro cambio está en curso. Recarga e intenta nuevamente.' : error.code === '55000' ? 'Retira el contenido antes de eliminarlo. Si una ruta tiene historial, utiliza Archivar.' : error.code === '23514' ? 'La operación no cumple las reglas de publicación o conservación de recorridos. Revisa imágenes, idiomas, orden y asociaciones.' : status === 400 ? 'Revisa los campos del formulario.' : 'No se pudo completar la operación. Intenta nuevamente.';
    return res.status(status).json({ mensaje: message });
  }
  async function transaction(req, res, task, status = 200) {
    let client, active = false;
    try {
      client = await pool.connect(); await client.query('BEGIN'); active = true;
      await client.query("SET LOCAL lock_timeout = '5s'");
      const result = await task(client, req.tokenSesion);
      await client.query('COMMIT'); active = false;
      return res.status(status).json(result);
    } catch (error) { if (active) await client.query('ROLLBACK').catch(() => {}); return failure(res, error); }
    finally { client?.release(); }
  }
  async function list(client, token, kind, id) {
    const functionName = kind === 'atractivo' ? 'admin_listar_atractivos' : kind === 'ruta' ? 'admin_listar_rutas' : 'admin_listar_ruta_paradas';
    const args = kind === 'parada' ? [token,id] : [token];
    const signature = kind === 'parada' ? "$1::text,$2::uuid" : '$1::text';
    const es = await client.query(`SELECT * FROM public.${functionName}(${signature},'es'::text)`, args);
    const en = await client.query(`SELECT * FROM public.${functionName}(${signature},'en'::text)`, args);
    const key = kind === 'atractivo' ? 'atractivo_id' : kind === 'ruta' ? 'ruta_id' : 'parada_id';
    const english = new Map(en.rows.map(row => [row[key],row]));
    return es.rows.map(row => ({ ...row, traducciones: { es: { nombre: row.nombre || '', descripcion: row.descripcion || '', imagen_texto_alternativo: row.imagen_texto_alternativo || '' }, en: { nombre: english.get(row[key])?.nombre || '', descripcion: english.get(row[key])?.descripcion || '', imagen_texto_alternativo: english.get(row[key])?.imagen_texto_alternativo || '' } } }));
  }
  async function saveTranslations(client, token, kind, id, values) {
    const fn = kind === 'atractivo' ? 'admin_guardar_atractivo_traduccion' : kind === 'ruta' ? 'admin_guardar_ruta_traduccion' : 'admin_guardar_parada_traduccion';
    for (const item of values) await client.query(`SELECT public.${fn}($1::text,$2::uuid,$3::text,$4::text,$5::text,$6::text)`, [token,id,item.lang,item.name,item.description,item.alt]);
  }
  router.get('/atractivos', (req,res) => transaction(req,res,async(client,token) => {
    const rows = await list(client,token,'atractivo');
    // El listado conserva también las asociaciones de categorías de cada ficha.
    const categories = await client.query("SELECT * FROM public.admin_listar_categorias_atractivo($1::text,'es'::text)",[token]);
    for (const row of rows) { const assigned = await client.query("SELECT * FROM public.admin_listar_categorias_atractivo_asignadas($1::text,$2::uuid,'es'::text)",[token,row.atractivo_id]); row.categoria_ids = assigned.rows.map(item => item.categoria_id); }
    return { atractivos: rows, categorias: categories.rows };
  }));
  router.get('/rutas', (req,res) => transaction(req,res,async(client,token) => ({ rutas: await list(client,token,'ruta') })));
  router.get('/rutas/:id/paradas', (req,res) => transaction(req,res,async(client,token) => ({ paradas: await list(client,token,'parada',identifier(req.params.id)) })));

  for (const kind of ['atractivo','ruta']) {
    const plural = kind === 'ruta' ? 'rutas' : 'atractivos';
    for (const creating of [true,false]) router[creating ? 'post' : 'put'](`/${plural}${creating ? '' : '/:id'}`, (req,res) => transaction(req,res,async(client,token) => {
      const data = validateContent(req.body,kind);
      let id = creating ? null : identifier(req.params.id);
      if (creating) { const created = await client.query(`SELECT public.admin_crear_${kind}($1::text) AS id`,[token]); id = created.rows[0].id; }
      else if (kind === 'ruta') await client.query('SELECT public.admin_bloquear_ruta_edicion($1::text,$2::uuid)',[token,id]);
      const query = kind === 'ruta' ? 'SELECT public.admin_actualizar_ruta($1::text,$2::uuid,$3::integer,$4::text)' : 'SELECT public.admin_actualizar_atractivo($1::text,$2::uuid,$3::text,$4::double precision,$5::double precision)';
      await client.query(query,kind === 'ruta' ? [token,id,data.minutes,data.image] : [token,id,data.image,data.lon,data.lat]);
      await saveTranslations(client,token,kind,id,data.translations);
      if (kind === 'atractivo') {
        const current = await client.query("SELECT * FROM public.admin_listar_categorias_atractivo_asignadas($1::text,$2::uuid,'es'::text)",[token,id]);
        const before = current.rows.map(item => item.categoria_id);
        for (const cat of before.filter(cat => !data.categories.includes(cat))) await client.query('SELECT public.admin_quitar_categoria_atractivo($1::text,$2::uuid,$3::uuid)',[token,id,cat]);
        for (const cat of data.categories.filter(cat => !before.includes(cat))) await client.query('SELECT public.admin_asignar_categoria_atractivo($1::text,$2::uuid,$3::uuid)',[token,id,cat]);
      }
      return { id, guardado: true };
    },creating ? 201 : 200));
    router.patch(`/${plural}/:id/estado`, (req,res) => transaction(req,res,async(client,token) => {
      object(req.body,['estado']); const id = identifier(req.params.id); const state = req.body.estado;
      if (!['borrador','publicado','archivado'].includes(state)) bad('Estado inválido.');
      await client.query(state === 'publicado' ? `SELECT public.admin_publicar_${kind}($1::text,$2::uuid)` : `SELECT public.admin_retirar_${kind}($1::text,$2::uuid,$3::text)`,state === 'publicado' ? [token,id] : [token,id,state]);
      return { actualizado: true };
    }));
    router.delete(`/${plural}/:id`, (req,res) => transaction(req,res,async(client,token) => {
      await client.query(`SELECT public.admin_eliminar_${kind}($1::text,$2::uuid)`,[token,identifier(req.params.id)]); return { eliminado: true };
    }));
  }
  for (const creating of [true,false]) router[creating ? 'post' : 'put'](`/rutas/:id/paradas${creating ? '' : '/:parada'}`, (req,res) => transaction(req,res,async(client,token) => {
    const routeId = identifier(req.params.id), data = validateContent(req.body,'parada');
    await client.query('SELECT public.admin_bloquear_ruta_edicion($1::text,$2::uuid)',[token,routeId]);
    const stops = await list(client,token,'parada',routeId);
    let id = creating ? null : identifier(req.params.parada);
    if (!creating && !stops.some(stop => stop.parada_id === id)) { const error = new Error(); error.code = 'P0002'; throw error; }
    if (creating) {
      const created = await client.query('SELECT public.admin_crear_ruta_parada($1::text,$2::uuid,$3::integer,$4::uuid,$5::text,$6::double precision,$7::double precision) AS id',[token,routeId,Math.max(0,...stops.map(stop => stop.orden)) + 1,data.attractionId,data.image,data.lon,data.lat]); id = created.rows[0].id;
    } else await client.query('SELECT public.admin_actualizar_ruta_parada($1::text,$2::uuid,$3::uuid,$4::text,$5::double precision,$6::double precision)',[token,id,data.attractionId,data.image,data.lon,data.lat]);
    await saveTranslations(client,token,'parada',id,data.translations);
    if (data.order != null) {
      const order = stops.map(stop => stop.parada_id).filter(item => item !== id);
      if (data.order > order.length + 1) bad('La posición excede la cantidad de paradas.');
      order.splice(data.order - 1,0,id);
      await client.query('SELECT public.admin_reordenar_ruta_paradas($1::text,$2::uuid,$3::uuid[])',[token,routeId,order]);
    }
    return { id, guardado: true };
  },creating ? 201 : 200));
  router.put('/rutas/:id/orden', (req,res) => transaction(req,res,async(client,token) => {
    object(req.body,['parada_ids']);
    if (!Array.isArray(req.body.parada_ids) || req.body.parada_ids.length > 10000) bad('Lista de paradas inválida.');
    await client.query('SELECT public.admin_reordenar_ruta_paradas($1::text,$2::uuid,$3::uuid[])',[token,identifier(req.params.id),req.body.parada_ids.map(identifier)]);
    return { actualizado: true };
  }));
  router.delete('/rutas/:id/paradas/:parada', (req,res) => transaction(req,res,async(client,token) => {
    const routeId = identifier(req.params.id), id = identifier(req.params.parada);
    await client.query('SELECT public.admin_bloquear_ruta_edicion($1::text,$2::uuid)',[token,routeId]);
    const stops = await list(client,token,'parada',routeId);
    if (!stops.some(stop => stop.parada_id === id)) { const error = new Error(); error.code = 'P0002'; throw error; }
    await client.query('SELECT public.admin_eliminar_ruta_parada($1::text,$2::uuid)',[token,id]);
    return { eliminado: true };
  }));
  router.post('/catalogo-inicial', (req,res) => transaction(req,res,async(client,token) => {
    object(req.body,['confirmacion']); if (req.body.confirmacion !== true) bad('Confirma la incorporación del catálogo inicial.');
    const result = await client.query('SELECT public.admin_cargar_catalogo_inicial($1::text) AS resultado',[token]);
    return result.rows[0].resultado;
  }));
  return router;
}
module.exports = { crearRouterContenidos, validateContent };
