const path = require('node:path');

require('dotenv').config({
  path: path.join(__dirname, '.env'),
  quiet: true,
});

const express = require('express');
const { Pool } = require('pg');

const app = express();
const pool = new Pool({
  connectionTimeoutMillis: 5000,
});

// Conexión opcional con GitHub Pages para presentaciones.
require('./modo-publico.cjs').configurarModoPublico(app, pool);

// Permite recibir formularios enviados como JSON.
app.use(express.json({ limit: '16kb' }));

app.use((_req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});

const { crearRouterSesiones, protegerOrigen, exigirCookie } = require('./sesiones.cjs');
app.use('/api', protegerOrigen);
app.use('/api', crearRouterSesiones(pool));
const { crearRouterTurismo } = require('./turismo.cjs');
app.use('/api', crearRouterTurismo(pool));
// El CRUD ahora usa la sesión de la persona, sin recurrir al token fijo.
app.use('/api/categorias', exigirCookie);
const { crearRouterCategorias } = require('./categorias.cjs');
app.use('/api/categorias', crearRouterCategorias(pool));

// Registro público: no utiliza el token de demostración.
const { crearRouterRegistro } = require('./registro.cjs');
app.use('/api', crearRouterRegistro(pool));

// Comprueba conexión y acceso administrativo mediante una función autorizada.
app.get('/api/estado', async (_req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT current_database() AS base, current_user AS cuenta_bd'
    );

    const token = process.env.DEMO_ADMIN_TOKEN;

    if (!token) {
      return res.status(503).json({
        conectado: true,
        ...rows[0],
        administrador: false,
        mensaje: 'Falta configurar DEMO_ADMIN_TOKEN.',
      });
    }

    try {
      await pool.query(
        "SELECT * FROM public.admin_listar_categorias_atractivo($1::text, 'es'::text)",
        [token]
      );
    } catch (error) {
      if (error.code !== '42501') throw error;

      return res.status(403).json({
        conectado: true,
        ...rows[0],
        administrador: false,
        mensaje: 'La sesión no permite administrar categorías.',
      });
    }

    return res.json({
      conectado: true,
      ...rows[0],
      administrador: true,
    });
  } catch (error) {
    console.error('Error de comprobación:', error.code || 'sin código');

    return res.status(503).json({
      conectado: false,
      mensaje: 'No se pudo completar la comprobación.',
    });
  }
});

// Consulta las categorías existentes.
app.get('/api/categorias', async (req, res) => {
  const token = req.tokenSesion;

  if (!token) {
    return res.status(503).json({
      mensaje: 'Falta configurar la sesión de demostración.',
    });
  }

  try {
    const { rows } = await pool.query(
      "SELECT * FROM public.admin_listar_categorias_atractivo($1::text, 'es'::text)",
      [token]
    );

    return res.json(rows);
  } catch (error) {
    console.error('Error al listar categorías:', error.code || 'sin código');

    return res.status(error.code === '42501' ? 403 : 500).json({
      mensaje: error.code === '42501'
        ? 'La sesión no permite administrar categorías.'
        : 'No se pudieron consultar las categorías.',
    });
  }
});

app.use((error, _req, res, next) => {
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({
      mensaje: 'El cuerpo de la petición debe ser JSON válido.',
    });
  }

  if (error.type === 'entity.too.large') {
    return res.status(413).json({
      mensaje: 'La petición supera el tamaño permitido.',
    });
  }

  next(error);
});
app.patch('/api/categorias/:id/icono', async (req, res) => {
  const { id } = req.params;
  const { icono_codigo } = req.body || {};

  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
    return res.status(400).json({ mensaje: 'Identificador inválido.' });
  }

  if (typeof icono_codigo !== 'string' || !icono_codigo.trim()) {
    return res.status(400).json({ mensaje: 'Debes indicar el icono.' });
  }

  const token = req.tokenSesion;

  if (!token) {
    return res.status(503).json({
      mensaje: 'Falta configurar la sesión de demostración.',
    });
  }

  try {
    const { rows } = await pool.query(
      `SELECT public.admin_actualizar_icono_categoria(
        $1::text, $2::uuid, $3::text
      ) AS actualizado`,
      [token, id, icono_codigo.trim()]
    );

    if (!rows[0].actualizado) {
      return res.status(404).json({ mensaje: 'La categoría no existe.' });
    }

    return res.json({ actualizado: true });
  } catch (error) {
    console.error('Error al actualizar icono:', error.code || 'sin código');

    const estado = error.code === '42501'
      ? 403
      : ['23514', '23502', '22001', '22023'].includes(error.code)
        ? 400
        : 500;

    return res.status(estado).json({
      mensaje: estado === 403
        ? 'La sesión no permite administrar categorías.'
        : estado === 400
          ? 'El icono no cumple las reglas de la BD.'
          : 'No se pudo actualizar el icono.',
    });
  }
});
app.delete('/api/categorias/:id', async (req, res) => {
  const { id } = req.params;
  const token = req.tokenSesion;

  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
    return res.status(400).json({ mensaje: 'Identificador inválido.' });
  }

  if (!token) {
    return res.status(503).json({
      mensaje: 'Falta configurar la sesión de demostración.',
    });
  }

  try {
    const { rows } = await pool.query(
      `SELECT public.admin_eliminar_categoria_atractivo(
        $1::text, $2::uuid
      ) AS eliminado`,
      [token, id]
    );

    if (!rows[0].eliminado) {
      return res.status(404).json({ mensaje: 'La categoría no existe.' });
    }

    return res.json({ eliminado: true });
  } catch (error) {
    console.error('Error al eliminar categoría:', error.code || 'sin código');

    if (error.code === '23503') {
      return res.status(409).json({
        mensaje: 'No se puede eliminar una categoría vinculada a atractivos.',
      });
    }

    return res.status(error.code === '42501' ? 403 : 500).json({
      mensaje: error.code === '42501'
        ? 'La sesión no permite administrar categorías.'
        : 'No se pudo eliminar la categoría.',
    });
  }
});
const puerto = Number(process.env.PORT || 3001);

// Solo escucha en el computador de la demostración.
const servidor = app.listen(puerto, '127.0.0.1', () => {
  console.log(`API: http://127.0.0.1:${puerto}/api/${process.env.CASABLANCA_PUBLICO === 'true' ? 'publico/estado' : 'estado'}`);
});

servidor.on('error', (error) => {
  console.error('No se pudo iniciar la API:', error.code || 'sin código');
  process.exit(1);
});