'use strict';
// Exclusivo para la demostracion local: no implementa un login de usuarios.
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');
const root = __dirname;
const backend = path.join(root, 'backend');
const localRequire = createRequire(path.join(backend, 'package.json'));
const dotenv = localRequire('dotenv');
const { Client } = localRequire('pg');
const envPath = path.join(backend, '.env');
const demoEmail = 'demo.admin@example.invalid';
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function setValue(text, key, value) {
  const lines = text.split(/\r?\n/);
  const matching = new RegExp(`^\\s*(?:export\\s+)?${key}\\s*=`);
  let done = false;
  const updated = lines.flatMap(line => {
    if (!matching.test(line)) return [line];
    if (done) return [];
    done = true;
    return [`${key}=${value}`];
  });
  if (!done) updated.push(`${key}=${value}`);
  return updated.join('\r\n');
}

async function inspect(client, token) {
  if (!token) return null;
  const { rows } = await client.query('SELECT public.validar_sesion($1::text) AS id', [token]);
  if (!rows[0]?.id) return null;
  const profile = await client.query('SELECT * FROM public.obtener_mi_perfil($1::text)', [token]);
  if (profile.rows[0]?.email !== demoEmail) {
    throw new Error('El token no pertenece a la cuenta de demostracion esperada.');
  }
  // Una sesion vigente de un turista no es suficiente: verificar el rol admin.
  await client.query("SELECT * FROM public.admin_listar_categorias_atractivo($1::text, 'es'::text)", [token]);
  return rows[0].id;
}

async function main() {
  const config = dotenv.parse(fs.readFileSync(envPath));
  if (config.PGUSER !== 'casablanca_backend' || config.PGDATABASE !== 'casablanca') {
    throw new Error('La renovacion requiere PGUSER=casablanca_backend y PGDATABASE=casablanca en backend/.env.');
  }
  const client = new Client({
    host: config.PGHOST || '127.0.0.1',
    port: Number(config.PGPORT || 5432),
    database: config.PGDATABASE, user: config.PGUSER, password: config.PGPASSWORD,
    connectionTimeoutMillis: 5000,
    query_timeout: 10000,
  });
  let transaction = false;
  try {
    await client.connect();
    await client.query('BEGIN'); transaction = true;
    await client.query("SET LOCAL lock_timeout = '5s'");
    // Serializa dos arranques simultaneos; el segundo relee el token actualizado.
    await client.query("SELECT pg_advisory_xact_lock(hashtext('casablanca_demo_session_launcher')::bigint)");
    const text = fs.readFileSync(envPath, 'utf8');
    const current = dotenv.parse(text);
    let id = await inspect(client, current.DEMO_ADMIN_TOKEN);
    let token = current.DEMO_ADMIN_TOKEN;
    let renewed = false;
    if (!id) {
      id = current.DEMO_ADMIN_USUARIO_ID;
      if (!id || !uuidPattern.test(id)) {
        throw new Error('El token no esta vigente y falta DEMO_ADMIN_USUARIO_ID. Consulta una sola vez el UUID en pgAdmin y agregalo a backend/.env. Consulta: SELECT id FROM public.usuario WHERE email = \'demo.admin@example.invalid\';');
      }
      const result = await client.query('SELECT token_original FROM public.crear_sesion($1::uuid)', [id]);
      token = result.rows[0]?.token_original;
      if (!token) throw new Error('La cuenta no esta activa/verificada o no existe. No se creo una sesion.');
      const verifiedId = await inspect(client, token);
      if (!verifiedId || verifiedId !== id.toLowerCase()) throw new Error('La nueva sesion no corresponde al administrador de demostracion.');
      renewed = true;
    }
    // Mantener la transaccion bloqueada hasta terminar la escritura del entorno.
    // Si el COMMIT falla, el proximo arranque detectara el token no valido y lo renovara.
    let updated = setValue(text, 'DEMO_ADMIN_USUARIO_ID', id);
    updated = setValue(updated, 'DEMO_ADMIN_TOKEN', token);
    if (updated !== text) fs.writeFileSync(envPath, updated, { encoding: 'utf8', mode: 0o600 });
    await client.query('COMMIT'); transaction = false;
    console.log(renewed
      ? 'Sesion de demostracion renovada. Token guardado en backend/.env (no se muestra).'
      : 'Token vigente y autorizado: reutilizado sin crear otra sesion.');
    // El lanzador usa el codigo 10 para detectar que una API antigua necesita reinicio.
    process.exitCode = renewed ? 10 : 0;
  } catch (error) {
    if (transaction) await client.query('ROLLBACK').catch(() => {});
    if (error.code) console.error(`No se pudo preparar la sesion. Codigo BD/conexion: ${error.code}. Revisa PostgreSQL, permisos y .env.`);
    else console.error(error.message);
    process.exitCode = 1;
  } finally {
    await client.end().catch(() => {});
  }
}
main().catch(() => { console.error('No se pudo leer la configuracion o iniciar la renovacion.'); process.exitCode = 1; });
