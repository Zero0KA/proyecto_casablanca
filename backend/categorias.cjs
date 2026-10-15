'use strict';
const express = require('express');
const code = /^[a-z][a-z0-9_]{0,49}$/;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function validarCategoria(body, crear) {
  const allowed = new Set(crear ? ['nombre', 'codigo', 'icono_codigo'] : ['nombre', 'icono_codigo']);
  if (!body || typeof body !== 'object' || Array.isArray(body) || Object.keys(body).some(key => !allowed.has(key))) throw new Error('El formulario contiene campos no admitidos.');
  if (typeof body.nombre !== 'string' || !body.nombre.trim() || Array.from(body.nombre.trim()).length > 100) throw new Error('El nombre debe tener entre 1 y 100 caracteres.');
  if (typeof body.icono_codigo !== 'string' || !code.test(body.icono_codigo.trim())) throw new Error('Selecciona un icono válido.');
  if (crear && (typeof body.codigo !== 'string' || !code.test(body.codigo.trim()))) throw new Error('El identificador no es válido.');
  return { nombre: body.nombre.trim(), icono: body.icono_codigo.trim(), codigo: crear ? body.codigo.trim() : null };
}
function crearRouterCategorias(pool) {
  const router = express.Router();
  async function guardar(req, res, crear) {
    if (!req.tokenSesion) return res.status(401).json({ mensaje: 'Inicia sesión para continuar.' });
    if (!crear && !uuid.test(req.params.id)) return res.status(400).json({ mensaje: 'Identificador inválido.' });
    let datos;
    try { datos = validarCategoria(req.body, crear); } catch (error) { return res.status(400).json({ mensaje: error.message }); }
    let client, transaction = false;
    try {
      client = await pool.connect();
      await client.query('BEGIN'); transaction = true;
      let id = req.params.id;
      if (crear) {
        const { rows } = await client.query('SELECT public.admin_crear_categoria_atractivo($1::text,$2::text,$3::text) AS categoria_id', [req.tokenSesion, datos.codigo, datos.icono]);
        id = rows[0]?.categoria_id;
        if (!id) throw new Error('No se obtuvo la categoría');
      } else {
        const { rows } = await client.query('SELECT public.admin_actualizar_icono_categoria($1::text,$2::uuid,$3::text) AS actualizado', [req.tokenSesion, id, datos.icono]);
        if (rows[0]?.actualizado !== true) { await client.query('ROLLBACK'); transaction = false; return res.status(404).json({ mensaje: 'La categoría no existe.' }); }
      }
      // Nombre e icono se guardan juntos; un fallo no deja una categoría incompleta.
      const { rows } = await client.query("SELECT public.admin_guardar_categoria_traduccion($1::text,$2::uuid,'es'::text,$3::text) AS guardado", [req.tokenSesion, id, datos.nombre]);
      if (rows[0]?.guardado !== true) throw new Error('No se guardó el nombre');
      await client.query('COMMIT'); transaction = false;
      return res.status(crear ? 201 : 200).json(crear ? { categoria_id: id } : { actualizado: true });
    } catch (error) {
      if (transaction) await client.query('ROLLBACK').catch(() => {});
      console.error('Error de categoría:', error.code || 'sin código');
      const status = error.code === '42501' ? 403 : error.code === '23505' ? 409 : ['23514','23502','23503','22001','22023'].includes(error.code) ? 400 : 503;
      return res.status(status).json({ mensaje: status === 403 ? 'La sesión no permite administrar categorías.' : status === 409 ? 'Ya existe una categoría con ese identificador. Actualiza el listado e intenta nuevamente.' : status === 400 ? 'El nombre o el icono no cumplen las reglas de la categoría.' : 'No se pudo guardar la categoría.' });
    } finally { if (client) client.release(); }
  }
  router.post('/', (req, res) => guardar(req, res, true));
  router.put('/:id', (req, res) => guardar(req, res, false));
  return router;
}
module.exports = { crearRouterCategorias, validarCategoria };
