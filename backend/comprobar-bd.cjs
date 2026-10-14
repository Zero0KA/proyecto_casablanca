const path = require('node:path');

require('dotenv').config({
  path: path.join(__dirname, '.env'),
  quiet: true,
});

const { Client } = require('pg');

async function comprobar() {
  const cliente = new Client({
    connectionTimeoutMillis: 5000,
  });

  try {
    await cliente.connect();

    const resultado = await cliente.query(`
      SELECT
        current_database() AS base,
        (SELECT count(*)::integer FROM public.pais) AS paises,
        (SELECT count(*)::integer FROM public.rol) AS roles
    `);

    console.table(resultado.rows);
  } catch (error) {
    console.error('No se pudo comprobar la BD.');
    console.error('Código:', error.code || 'sin código');
    process.exitCode = 1;
  } finally {
    await cliente.end();
  }
}

comprobar();