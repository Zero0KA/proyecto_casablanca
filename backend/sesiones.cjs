'use strict';
const express = require('express');
const argon2 = require('argon2');
const { modoPublico, origenPublico } = require('./modo-publico.cjs');
const cookieName = 'casablanca_sesion';
const cookieOptions = { httpOnly: true, sameSite: 'strict', secure: process.env.NODE_ENV === 'production', path: '/' };

function leerToken(req) {
  if (modoPublico()) {
    const match = /^Bearer ([0-9a-f]{64})$/.exec(req.headers.authorization || '');
    return match ? match[1] : null;
  }
  const valores = (req.headers.cookie || '').split(';').map(x => x.trim()).filter(x => x.startsWith(cookieName + '='));
  if (valores.length !== 1) return null;
  const token = valores[0].slice(cookieName.length + 1);
  return /^[0-9a-f]{64}$/.test(token) ? token : null;
}
function protegerOrigen(req, res, next) {
  if (!['POST','PATCH','DELETE','PUT'].includes(req.method)) return next();
  if (!req.is('application/json')) return res.status(415).json({ mensaje: 'Envía JSON.' });
  const origin = req.headers.origin;
  if (modoPublico()) {
    if (origin !== origenPublico()) return res.status(403).json({ mensaje: 'Origen no permitido.' });
    return next();
  }
  if (req.headers['sec-fetch-site'] === 'cross-site') return res.status(403).json({ mensaje: 'Origen no permitido.' });
  if (origin) {
    let allowed = false;
    try {
      const url = new URL(origin);
      const defaults = ['127.0.0.1','localhost'].includes(url.hostname) && url.protocol === 'http:' &&
        (url.port === '3001' || (Number(url.port) >= 5173 && Number(url.port) <= 5193));
      const configured = (process.env.FRONT_ORIGINS || '').split(',').map(x => x.trim()).filter(Boolean);
      allowed = configured.length ? configured.includes(url.origin) : defaults;
    } catch { }
    if (!allowed) return res.status(403).json({ mensaje: 'Origen no permitido.' });
  } else if (req.headers.cookie) {
    return res.status(403).json({ mensaje: 'Las solicitudes con sesión requieren un origen permitido.' });
  }
  return next();
}
function exigirCookie(req, res, next) {
  req.tokenSesion = leerToken(req);
  if (!req.tokenSesion) return res.status(401).json({ mensaje: 'Inicia sesión para continuar.' });
  return next();
}
function crearRouterSesiones(pool) {
  const router = express.Router();
  const habilitacionManual = () => process.env.DEMO_HABILITACION_MANUAL === 'true' && process.env.NODE_ENV !== 'production';
  const dummy = argon2.hash('credencial ficticia para comparar tiempo', { type: argon2.argon2id, memoryCost: 65536, timeCost: 3, parallelism: 1 });
  let trabajos = 0;
  const intentos = new Map();
  router.post('/login', async (req, res) => {
    const { email, password } = req.body || {};
    if (typeof email !== 'string' || typeof password !== 'string' || email.length > 254 || !email.trim() || !password || Array.from(password).length > 128) {
      return res.status(400).json({ mensaje: 'Indica correo y contraseña válidos.' });
    }
    const ahora = Date.now(), key = req.ip;
    for (const [k, v] of intentos) if (v.hasta <= ahora) intentos.delete(k);
    const intento = intentos.get(key) || { hasta: ahora + 60000, cuenta: 0 };
    if (intento.cuenta >= 10) return res.status(429).set('Retry-After','60').json({ mensaje: 'Demasiados intentos. Espera un minuto.' });
    intento.cuenta++; intentos.set(key, intento);
    if (intentos.size > 4096) intentos.delete(intentos.keys().next().value);
    if (trabajos >= 2) return res.status(503).json({ mensaje: 'Inicio de sesión ocupado. Intenta nuevamente.' });
    trabajos++;
    let client;
    let transaction = false;
    try {
      const { rows } = await pool.query('SELECT * FROM public.obtener_credenciales_login($1::text)', [email.trim().toLowerCase()]);
      const cuenta = rows[0];
      const correcto = await argon2.verify(cuenta?.password_hash || await dummy, password);
      if (!cuenta || !correcto) return res.status(401).json({ mensaje: 'Correo o contraseña incorrectos, o cuenta no habilitada.' });
      client = await pool.connect();
      await client.query('BEGIN'); transaction = true;
      const sesion = await client.query('SELECT * FROM public.crear_sesion($1::uuid)', [cuenta.usuario_id]);
      const nueva = sesion.rows[0];
      if (!nueva) {
        await client.query('ROLLBACK'); transaction = false;
        return res.status(401).json({ mensaje: 'Correo o contraseña incorrectos, o cuenta no habilitada.' });
      }
      const contexto = await client.query('SELECT * FROM public.obtener_contexto_sesion($1::text)', [nueva.token_original]);
      if (!contexto.rows[0]) throw new Error('No se pudo validar la nueva sesión');
      const anterior = leerToken(req);
      if (anterior) await client.query('SELECT public.cerrar_sesion($1::text)', [anterior]);
      await client.query('COMMIT'); transaction = false;
      if (modoPublico()) {
        return res.json({ usuario: contexto.rows[0], vence_en: nueva.vence_en, token_sesion: nueva.token_original });
      }
      res.cookie(cookieName, nueva.token_original, { ...cookieOptions, expires: new Date(nueva.vence_en) });
      return res.json({ usuario: contexto.rows[0], vence_en: nueva.vence_en });
    } catch (error) {
      if (transaction) await client.query('ROLLBACK').catch(() => {});
      console.error('Error de login:', error.code || 'sin código');
      return res.status(503).json({ mensaje: 'No se pudo iniciar sesión.' });
    } finally { if (client) client.release(); trabajos--; }
  });
  router.get('/sesion', exigirCookie, async (req, res) => {
    try {
      const { rows } = await pool.query('SELECT * FROM public.obtener_contexto_sesion($1::text)', [req.tokenSesion]);
      if (!rows[0]) {
        if (!modoPublico()) res.clearCookie(cookieName, cookieOptions);
        return res.status(401).json({ mensaje: 'Sesión vencida, cerrada o cuenta bloqueada.' });
      }
      return res.json({ usuario: rows[0] });
    } catch (error) {
      console.error('Error de sesión:', error.code || 'sin código');
      return res.status(503).json({ mensaje: 'No se pudo comprobar la sesión.' });
    }
  });
  router.post('/logout', async (req, res) => {
    try {
      const token = leerToken(req);
      if (token) await pool.query('SELECT public.cerrar_sesion($1::text)', [token]);
      if (!modoPublico()) res.clearCookie(cookieName, cookieOptions);
      return res.json({ cerrado: true });
    } catch (error) {
      console.error('Error al cerrar sesión:', error.code || 'sin código');
      return res.status(503).json({ mensaje: 'No se pudo cerrar la sesión. Intenta nuevamente.' });
    }
  });
  router.get('/admin/usuarios', exigirCookie, async (req, res) => {
    const busqueda = req.query.busqueda || '';
    const pagina = Number(req.query.pagina || 1);
    if (typeof busqueda !== 'string' || busqueda.length > 254 || !Number.isInteger(pagina) || pagina < 1 || pagina > 40001) {
      return res.status(400).json({ mensaje: 'Búsqueda o página inválida.' });
    }
    try {
      const { rows } = await pool.query('SELECT * FROM public.admin_listar_usuarios($1::text,$2::text,$3::integer,$4::integer)', [req.tokenSesion,busqueda,25,(pagina-1)*25]);
      return res.json({ usuarios: rows.map(({ total, ...u })=>u), total: Number(rows[0]?.total || 0), pagina, habilitacion_manual: habilitacionManual() });
    } catch (error) {
      console.error('Error de listado:', error.code || 'sin código');
      return res.status(error.code === '42501' ? 403 : 503).json({ mensaje: error.code === '42501' ? 'Se requiere una sesión administrativa válida.' : 'No se pudo listar las cuentas.' });
    }
  });
  router.post('/admin/usuarios/:id/habilitar-demo', exigirCookie, async (req, res) => {
    if (!habilitacionManual()) return res.status(404).json({ mensaje: 'La habilitación manual de demostración está desactivada.' });
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(req.params.id) || req.body?.confirmacion_demo !== true) {
      return res.status(400).json({ mensaje: 'Indica una cuenta y confirma que esta operación omite la comprobación real del correo.' });
    }
    try {
      const { rows } = await pool.query('SELECT public.admin_habilitar_cuenta_demo($1::text,$2::uuid) AS habilitado', [req.tokenSesion, req.params.id]);
      if (!rows[0].habilitado) return res.status(404).json({ mensaje: 'La cuenta no existe.' });
      return res.json({ habilitado: true, mensaje: 'Cuenta habilitada manualmente para la demostración. No se ha comprobado la propiedad del correo.' });
    } catch (error) {
      console.error('Error de habilitación manual:', error.code || 'sin código');
      const status = error.code === '42501' ? 403 : error.code === '54000' ? 429 : error.code === '55000' ? 409 : error.code === '22023' ? 400 : 503;
      if (status === 429) res.set('Retry-After', '60');
      return res.status(status).json({ mensaje: status === 403 ? 'Se requiere una sesión administrativa válida.' : status === 429 ? 'Se alcanzó el límite de emisión. Espera antes de volver a intentar; si hubo varios intentos, el límite puede durar una hora.' : status === 409 ? 'La cuenta ya no está pendiente o no puede habilitarse. Recarga el listado.' : status === 400 ? 'Solo se permite habilitar cuentas turistas pendientes.' : 'No se pudo habilitar la cuenta.' });
    }
  });
  router.patch('/admin/usuarios/:id/bloqueo', exigirCookie, async (req, res) => {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(req.params.id) || typeof req.body?.bloqueado !== 'boolean') {
      return res.status(400).json({ mensaje: 'Indica usuario y bloqueo válidos.' });
    }
    try {
      const { rows } = await pool.query('SELECT public.admin_cambiar_bloqueo_usuario($1::text,$2::uuid,$3::boolean) AS actualizado', [req.tokenSesion, req.params.id,req.body.bloqueado]);
      if (!rows[0].actualizado) return res.status(404).json({ mensaje: 'La cuenta no existe.' });
      return res.json({ actualizado: true });
    } catch (error) {
      console.error('Error de bloqueo:', error.code || 'sin código');
      const status = error.code === '42501' ? 403 : error.code === '22023' ? 400 : 503;
      return res.status(status).json({ mensaje: status === 403 ? 'Se requiere una sesión administrativa válida.' : status === 400 ? 'Las cuentas administradoras están protegidas del bloqueo.' : 'No se pudo cambiar el bloqueo.' });
    }
  });
  return router;
}
module.exports = { crearRouterSesiones, protegerOrigen, exigirCookie, leerToken };
