'use strict';
const express = require('express');
const argon2 = require('argon2');
const generos = new Set(['masculino', 'femenino', 'no_binario', 'otra_identidad', 'prefiero_no_responder']);
const campos = new Set(['email', 'password', 'nombre', 'edad', 'nacionalidad_codigo', 'genero_codigo', 'genero_detalle']);
const longitud = valor => Array.from(valor).length;

function validarRegistro(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('Debes enviar un formulario JSON.');
  if (Object.keys(body).some(campo => !campos.has(campo))) throw new Error('El formulario contiene campos no admitidos. El rol no puede elegirse.');
  for (const campo of ['email', 'password', 'nombre', 'nacionalidad_codigo', 'genero_codigo']) {
    if (typeof body[campo] !== 'string') throw new Error('Faltan campos obligatorios o tienen un tipo incorrecto.');
  }
  const email = body.email.trim().toLowerCase();
  const nombre = body.nombre.trim();
  const nacionalidad = body.nacionalidad_codigo.trim().toUpperCase();
  const genero = body.genero_codigo.trim().toLowerCase();
  if (longitud(email) > 254 || !/^[^\s@]+@[^\s@]+$/.test(email)) throw new Error('Indica un correo válido.');
  if (!nombre || longitud(nombre) > 100) throw new Error('El nombre debe tener entre 1 y 100 caracteres.');
  // Regla del backend; no modifica los CHECK de la BD. No recortar la contraseña.
  if (longitud(body.password) < 15 || longitud(body.password) > 128 || !body.password.trim()) {
    throw new Error('La contraseña debe tener entre 15 y 128 caracteres. Puedes usar una frase.');
  }
  if (!Number.isInteger(body.edad) || body.edad < 0 || body.edad > 120) throw new Error('La edad debe ser un entero entre 0 y 120.');
  if (!/^[A-Z]{2}$/.test(nacionalidad)) throw new Error('Selecciona una nacionalidad del catálogo.');
  if (!generos.has(genero)) throw new Error('Selecciona una opción de género válida.');
  if (body.genero_detalle != null && typeof body.genero_detalle !== 'string') throw new Error('El detalle de género debe ser texto.');
  const detalle = body.genero_detalle?.trim() || null;
  if (detalle && (genero !== 'otra_identidad' || longitud(detalle) > 100)) throw new Error('El detalle, de hasta 100 caracteres, solo corresponde a otra identidad.');
  return { email, password: body.password, nombre, edad: body.edad, nacionalidad, genero, detalle };
}

function crearRouterRegistro(pool) {
  const router = express.Router();
  let trabajos = 0;
  router.get('/paises', async (_req, res) => {
    try {
      const { rows } = await pool.query('SELECT codigo, nombre_es FROM public.pais ORDER BY nombre_es, codigo');
      return res.json(rows);
    } catch (error) {
      console.error('Error de catálogo:', error.code || 'sin código');
      return res.status(503).json({ mensaje: 'No se pudo cargar el catálogo de nacionalidades.' });
    }
  });
  router.post('/registro', async (req, res) => {
    let datos;
    try { datos = validarRegistro(req.body); }
    catch (error) { return res.status(400).json({ mensaje: error.message }); }
    // Limita los cálculos costosos simultáneos en esta API local.
    if (trabajos >= 2) return res.status(503).set('Retry-After', '2').json({ mensaje: 'Registro ocupado. Intenta nuevamente en unos segundos.' });
    trabajos++;
    try {
      const pais = await pool.query('SELECT codigo FROM public.pais WHERE codigo = $1::varchar', [datos.nacionalidad]);
      if (!pais.rows.length) return res.status(400).json({ mensaje: 'La nacionalidad no pertenece al catálogo.' });
      const hashGenerado = await argon2.hash(datos.password, {
        type: argon2.argon2id, memoryCost: 65536, timeCost: 3, parallelism: 1, hashLength: 32,
      });
      // La BD exige el orden m,t,p. La biblioteca puede emitir m,p,t.
      // Ordenar metadatos conserva salt, resultado y valores criptográficos.
      const partes = hashGenerado.split('$');
      const parametros = Object.fromEntries(partes[3].split(',').map(item => item.split('=')));
      partes[3] = `m=${parametros.m},t=${parametros.t},p=${parametros.p}`;
      const hash = partes.join('$');
      const { rows } = await pool.query(`SELECT public.registrar_turista(
        $1::text, $2::text, $3::text, $4::integer, $5::text, $6::text, $7::text
      ) AS usuario_id`, [datos.email, hash, datos.nombre, datos.edad, datos.nacionalidad, datos.genero, datos.detalle]);
      return res.status(201).json({
        usuario_id: rows[0].usuario_id, estado: 'pendiente',
        mensaje: 'Registro guardado. La cuenta está pendiente de verificar el correo; todavía no se ha enviado un mensaje de verificación.',
      });
    } catch (error) {
      console.error('Error de registro:', error.code || 'sin código');
      if (error.code === '23505') return res.status(409).json({ mensaje: 'Ya existe una cuenta con ese correo.' });
      if (['23514', '23502', '23503', '22001', '22023'].includes(error.code)) {
        return res.status(400).json({ mensaje: 'Los datos no cumplen las reglas del registro.' });
      }
      return res.status(503).json({ mensaje: 'No se pudo completar el registro. Intenta nuevamente más tarde.' });
    } finally { trabajos--; }
  });
  return router;
}
module.exports = { crearRouterRegistro, validarRegistro };
