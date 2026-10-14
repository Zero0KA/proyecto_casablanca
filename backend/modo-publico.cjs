'use strict';
const { isIP } = require('node:net');

const modoPublico = () => process.env.CASABLANCA_PUBLICO === 'true';
const origenPublico = () => 'https://zero0ka.github.io';

function configurarModoPublico(app, pool) {
  if (!modoPublico()) return;
  app.disable('x-powered-by');
  app.set('trust proxy', 'loopback');
  app.use((req, res, next) => {
    // La API solo escucha en loopback; Cloudflare aporta la IP del visitante.
    const ip = req.headers['cf-connecting-ip'];
    if (typeof ip === 'string' && isIP(ip)) req.headers['x-forwarded-for'] = ip;
    else delete req.headers['x-forwarded-for'];
    next();
  });
  app.get('/api/publico/estado', async (req, res) => {
    res.set('Cache-Control', 'no-store');
    if (req.headers.origin === origenPublico()) {
      res.vary('Origin');
      res.set('Access-Control-Allow-Origin', origenPublico());
    }
    try {
      await pool.query('SELECT 1');
      res.json({ conectado: true, modo: 'github-pages' });
    } catch {
      res.status(503).json({ conectado: false, modo: 'github-pages' });
    }
  });
  app.use('/api', (req, res, next) => {
    res.set('Cache-Control', 'no-store');
    // El diagnóstico local del administrador fijo no se publica.
    if (req.path === '/estado') return res.status(404).json({ mensaje: 'No disponible.' });
    if (req.headers.origin !== origenPublico()) {
      return res.status(403).json({ mensaje: 'Origen no permitido.' });
    }
    res.vary('Origin');
    res.set('Access-Control-Allow-Origin', origenPublico());
    res.set('Access-Control-Expose-Headers', 'Retry-After');
    if (req.method === 'OPTIONS') {
      const method = req.headers['access-control-request-method'];
      const headers = String(req.headers['access-control-request-headers'] || '')
        .toLowerCase().split(',').map(x => x.trim()).filter(Boolean);
      if (!['GET', 'POST', 'PATCH', 'PUT', 'DELETE'].includes(method) ||
          headers.some(x => !['content-type', 'authorization'].includes(x))) {
        return res.status(403).json({ mensaje: 'Solicitud no permitida.' });
      }
      return res.status(204)
        .set('Access-Control-Allow-Methods', 'GET, POST, PATCH, PUT, DELETE')
        .set('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        .set('Access-Control-Max-Age', '300').end();
    }
    next();
  });
}

module.exports = { modoPublico, origenPublico, configurarModoPublico };
