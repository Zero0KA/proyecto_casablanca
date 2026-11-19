'use strict';

const express = require('express');
const { exigirCookie } = require('./sesiones.cjs');
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function idioma(req) {
  const value = req.query.idioma ?? 'es';
  if (typeof value !== 'string' || !['es', 'en'].includes(value)) {
    const error = new Error('Selecciona un idioma válido.'); error.code = 'CATALOG_VALIDATION'; throw error;
  }
  return value;
}

// Las lecturas compuestas comparten una instantánea. No se consultan tablas privadas.
async function consultar(pool, task) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    await client.query("SET LOCAL statement_timeout = '10s'");
    const result = await task(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally { client.release(); }
}

async function leerCatalogo(client, lang = 'es', token = null) {
  if (token) {
    // La BD comprueba el rol en cada función administrativa, también al previsualizar.
    const places = await client.query('SELECT * FROM public.admin_listar_atractivos($1::text,$2::text)', [token, lang]);
    const routes = await client.query('SELECT * FROM public.admin_listar_rutas($1::text,$2::text)', [token, lang]);
    const categories = await client.query('SELECT * FROM public.admin_listar_categorias_atractivo($1::text,$2::text)', [token, lang]);
    for (const place of places.rows) {
      place.categorias = (await client.query('SELECT * FROM public.admin_listar_categorias_atractivo_asignadas($1::text,$2::uuid,$3::text)', [token, place.atractivo_id, lang])).rows;
    }
    for (const route of routes.rows) {
      route.paradas = (await client.query('SELECT * FROM public.admin_listar_ruta_paradas($1::text,$2::uuid,$3::text)', [token, route.ruta_id, lang])).rows;
    }
    return { atractivos: places.rows, rutas: routes.rows, categorias: categories.rows, vista_previa: true };
  }
  const places = await leerAtractivosPublicados(client, lang);
  const routes = await leerRutasPublicadas(client, lang);
  const categories = await client.query('SELECT * FROM public.listar_categorias_activas($1::text)', [lang]);
  return { atractivos: places, rutas: routes, categorias: categories.rows, vista_previa: false };
}

async function leerAtractivosPublicados(client, lang = 'es') {
  const result = await client.query(`
    SELECT a.*, COALESCE((
      SELECT jsonb_agg(c ORDER BY c.nombre, c.categoria_id)
      FROM public.listar_categorias_atractivo_publicado(a.atractivo_id,$1::text) AS c
    ), '[]'::jsonb) AS categorias
    FROM public.listar_atractivos_publicados($1::text,NULL::uuid) AS a
  `, [lang]);
  return result.rows;
}

async function leerRutasPublicadas(client, lang = 'es') {
  const result = await client.query(`
    SELECT r.*, COALESCE((
      SELECT jsonb_agg(p ORDER BY p.orden)
      FROM public.listar_paradas_ruta_publicada(r.ruta_id,$1::text) AS p
    ), '[]'::jsonb) AS paradas
    FROM public.listar_rutas_publicadas($1::text) AS r
  `, [lang]);
  return result.rows;
}

function falloCatalogo(res, error) {
  console.error('Consulta de catálogo:', error.code || 'sin código');
  const status = error.code === '42501' ? 403 : error.code === 'CATALOG_VALIDATION' ? 400 : 503;
  return res.status(status).json({ mensaje: status === 403 ? 'Se requiere una sesión administrativa válida.' : status === 400 ? error.message : 'No se pudo cargar el contenido. Intenta nuevamente.' });
}

function crearRouterCatalogo(pool) {
  const router = express.Router();
  router.get('/catalogo', async (req, res) => {
    try { return res.json(await consultar(pool, client => leerCatalogo(client, idioma(req)))); }
    catch (error) { return falloCatalogo(res, error); }
  });
  router.get('/admin/vista-previa/catalogo', exigirCookie, async (req, res) => {
    try { return res.json(await consultar(pool, client => leerCatalogo(client, idioma(req), req.tokenSesion))); }
    catch (error) { return falloCatalogo(res, error); }
  });
  router.get('/atractivos/:id', async (req, res) => {
    if (!UUID.test(req.params.id)) return res.status(400).json({ mensaje: 'Identificador de atractivo inválido.' });
    try {
      const places = await consultar(pool, client => leerAtractivosPublicados(client, idioma(req)));
      const place = places.find(row => row.atractivo_id === req.params.id.toLowerCase());
      return place ? res.json({ atractivo: place }) : res.status(404).json({ mensaje: 'El atractivo no está disponible.' });
    } catch (error) { return falloCatalogo(res, error); }
  });
  return router;
}

module.exports = { crearRouterCatalogo, consultar, leerCatalogo, leerRutasPublicadas, leerAtractivosPublicados, falloCatalogo };
