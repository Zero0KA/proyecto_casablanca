'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
const { Pool } = require('../backend/node_modules/pg');
const { withDatabase } = require('./entorno-pruebas.cjs');
const { prepareUsers, start } = require('./integracion-api.cjs');
const { consultar, leerCatalogo } = require('../backend/catalogo.cjs');
const seed = require('../bd/catalogo_inicial.json');
const results = [];
const record = text => { results.push(text); console.log('OK', results.length, text); };

withDatabase(async ({ pool, name, port, host, user, password }) => {
  const users = await prepareUsers(pool);
  const environment = { PGHOST: host, PGPORT: String(port), PGUSER: user, PGPASSWORD: password, PGDATABASE: name, PGAPPNAME: 'qa_catalogo_api_13021', PORT: '13021', FRONT_ORIGINS: 'http://localhost:5190', CASABLANCA_PUBLICO: 'false', NODE_ENV: 'development', DEMO_ADMIN_TOKEN: '' };
  const api = await start('backend/server.cjs', [], environment, 'API: ');
  const limited = new Pool({ host, port, user, password, database: name });
  let publicApi;
  async function request(method, url, body, status = 200, who = null, pub = false, origin = null) {
    const response = await fetch(`http://127.0.0.1:${pub ? 13022 : 13021}/api${url}`, {
      method, headers: { Origin: origin || (pub ? 'https://zero0ka.github.io' : 'http://localhost:5190'), 'Content-Type': 'application/json', ...(who ? pub ? { Authorization: `Bearer ${users[who].token}` } : { Cookie: `casablanca_sesion=${users[who].token}` } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const data = response.status === 204 ? null : await response.json();
    assert.equal(response.status, status, `${method} ${url}: ${JSON.stringify(data)}`);
    assert.match(response.headers.get('cache-control') || '', /no-store/);
    return data;
  }
  const get = () => request('GET', '/catalogo');
  const preview = () => request('GET', '/admin/vista-previa/catalogo', undefined, 200, 'admin');
  const updateBody = row => ({ traducciones: row.traducciones, imagen_principal: row.imagen_principal, ...(row.ruta_id ? { duracion_estimada_minutos: 45 } : { latitud: row.latitud, longitud: row.longitud, categoria_ids: row.categoria_ids }) });
  try {
    const health = await request('GET', '/salud'); assert.equal(health.conectado, true); assert.equal(health.version, '2026-11-19'); record('Arranque sin token fijo: servicio y conexión comprobados');
    const login = await request('POST', '/login', { email: 'qa.admin@example.invalid', password: 'Pruebas1234' });
    assert.equal(login.usuario.administrador, true); assert.equal(login.usuario.usuario_id, users.admin.id); record('Login real con Argon2: sesión personal y rol administrativo conservados');
    const idle = await pool.query("SELECT pid FROM pg_stat_activity WHERE application_name=$1 AND state='idle'", ['qa_catalogo_api_13021']);
    assert(idle.rows.length > 0);
    for (const row of idle.rows) await pool.query('SELECT pg_terminate_backend($1::integer)', [row.pid]);
    let recovered = false;
    for (let attempt = 0; attempt < 10; attempt++) {
      const response = await fetch('http://127.0.0.1:13021/api/salud');
      if (response.ok && (await response.json()).conectado === true) { recovered = true; break; }
      assert.equal(response.status, 503); await new Promise(resolve => setTimeout(resolve, 100));
    }
    assert(recovered); record('Conexión inactiva interrumpida: la API permanece activa y vuelve a conectarse');
    assert.deepEqual(await get(), { atractivos: [], rutas: [], categorias: [], vista_previa: false }); record('BD vacía: catálogo público vacío, sin copias locales');
    await request('POST', '/admin/catalogo-inicial', { confirmacion: true }, 200, 'admin');
    assert.equal((await get()).rutas.length, 0); assert.equal((await get()).atractivos.length, 0); record('Población opcional: borradores ausentes del catálogo público');
    await request('GET', '/admin/vista-previa/catalogo', undefined, 401);
    await request('GET', '/admin/vista-previa/catalogo', undefined, 403, 'turista');
    const draft = await preview(); assert.equal(draft.atractivos.length, 6); assert.equal(draft.rutas.length, 3); assert(draft.rutas.every(row => row.estado === 'borrador')); record('Vista previa: seis atractivos y tres rutas, acceso administrativo verificado por BD');
    assert.equal((await request('GET', '/catalogo?vista_previa=1')).rutas.length, 0); record('Un parámetro público no habilita acceso a borradores');
    for (const url of ['/catalogo?idioma=xx', '/catalogo?idioma=es&idioma=en', '/catalogo?idioma=es%27%3BDROP%20TABLE%20ruta', '/atractivos/1']) await request('GET', url, undefined, 400);
    await request('GET', '/atractivos/00000000-0000-0000-0000-000000000000', undefined, 404); record('Idioma, parámetros repetidos e identificadores inválidos rechazados sin ejecutar SQL inyectado');
    const adminPlaces = (await request('GET', '/admin/atractivos', undefined, 200, 'admin')).atractivos;
    for (const place of adminPlaces.filter(item => item.latitud != null)) await request('PATCH', `/admin/atractivos/${place.atractivo_id}/estado`, { estado: 'publicado' }, 200, 'admin');
    const routes = (await request('GET', '/admin/rutas', undefined, 200, 'admin')).rutas;
    await request('PATCH', `/admin/rutas/${routes[0].ruta_id}/estado`, { estado: 'publicado' }, 409, 'admin');
    for (const route of routes) { await request('PUT', `/admin/rutas/${route.ruta_id}`, updateBody(route), 200, 'admin'); await request('PATCH', `/admin/rutas/${route.ruta_id}/estado`, { estado: 'publicado' }, 200, 'admin'); }
    const published = await get(); assert.equal(published.atractivos.length, 5); assert.equal(published.rutas.length, 3); assert.equal(new Set(published.rutas.map(item => item.ruta_id)).size, 3); record('Publicación con requisitos existentes: cinco atractivos, tres rutas, cero duplicados');
    const cascoId = seed.rutas[1].id;
    const casco = published.rutas.find(item => item.ruta_id === cascoId); assert.equal(casco.paradas.length, 12); assert.equal(casco.paradas.filter(stop => stop.latitud != null).length, 7); assert.equal(casco.paradas[1].latitud, null); record('Casco desde BD: doce paradas; siete GPS y cinco ausentes, sin aproximaciones sustitutas');
    const routeDetail = await request('GET', `/rutas/${cascoId}`); assert.deepEqual(routeDetail.paradas, casco.paradas); assert.equal((await request('GET', '/rutas')).length, 3); record('Compatibilidad de endpoints de rutas: misma ficha y paradas actuales');
    const placeId = seed.atractivos[0].id;
    assert.equal((await request('GET', `/atractivos/${placeId}`)).atractivo.atractivo_id, placeId); record('La ficha de atractivo por UUID consulta el contenido publicado');
    const cat = (await pool.query("SELECT public.admin_crear_categoria_atractivo($1,'qa_catalogo','book') AS id", [users.admin.token])).rows[0].id;
    for (const lang of ['es', 'en']) await pool.query('SELECT public.admin_guardar_categoria_traduccion($1,$2,$3,$4)', [users.admin.token, cat, lang, lang === 'es' ? 'Historia viva' : 'Living history']);
    await pool.query('SELECT public.admin_cambiar_activacion_categoria($1,$2,true)', [users.admin.token, cat]);
    const originalPlace = adminPlaces.find(item => item.atractivo_id === placeId);
    const edit = updateBody(originalPlace); edit.categoria_ids = [cat]; edit.traducciones.es.nombre = "Museo actualizado'); DROP TABLE public.ruta; --";
    await request('PUT', `/admin/atractivos/${placeId}`, edit, 200, 'admin');
    const edited = (await get()).atractivos.find(item => item.atractivo_id === placeId);
    assert.equal(edited.nombre, edit.traducciones.es.nombre); assert.equal(edited.categorias[0].nombre, 'Historia viva'); assert.equal(edited.categorias[0].icono_codigo, 'book'); record('Edición de nombre y categoría visible públicamente; SQL malicioso permanece texto literal');
    await pool.query('SELECT public.admin_cambiar_activacion_categoria($1,$2,false)', [users.admin.token, cat]);
    assert.equal((await get()).atractivos.find(item => item.atractivo_id === placeId).categorias.length, 0); record('Desactivar categoría la retira del filtro y de sus fichas públicas');
    await assert.rejects(limited.query('SELECT * FROM public.usuario'), { code: '42501' }); await assert.rejects(limited.query('UPDATE public.ruta SET duracion_estimada_minutos=1'), { code: '42501' }); record('La conexión API conserva privilegios mínimos y no accede a tablas privadas');
    const journey = (await request('POST', `/rutas/${cascoId}/recorridos`, {}, 201, 'turista')).recorrido_id;
    const frozen = (await pool.query('SELECT parada_id,orden FROM public.recorrido_parada WHERE recorrido_id=$1 ORDER BY orden', [journey])).rows;
    await request('PATCH', `/admin/rutas/${cascoId}/estado`, { estado: 'borrador' }, 200, 'admin');
    assert(!(await get()).rutas.some(item => item.ruta_id === cascoId)); await request('GET', `/rutas/${cascoId}`, undefined, 404); assert.equal((await request('GET', '/recorridos', undefined, 200, 'turista'))[0].recorrido_id, journey); record('Retirar una ruta oculta catálogo y URL directa, conservando el recorrido abierto de la persona');
    await request('POST', `/recorridos/${journey}/abandonar`, {}, 200, 'turista');
    const adminStops = (await request('GET', `/admin/rutas/${cascoId}/paradas`, undefined, 200, 'admin')).paradas;
    const first = adminStops[0]; const stopBody = { traducciones: first.traducciones, imagen_principal: first.imagen_principal, latitud: -33.318, longitud: -71.409, atractivo_id: first.atractivo_id, orden: 1 };
    stopBody.traducciones.es.nombre = 'Parada editada en PostgreSQL'; await request('PUT', `/admin/rutas/${cascoId}/paradas/${first.parada_id}`, stopBody, 200, 'admin');
    const changed = (await preview()).rutas.find(item => item.ruta_id === cascoId).paradas[0]; assert.equal(changed.nombre, stopBody.traducciones.es.nombre); assert.equal(changed.latitud, -33.318); record('Nombre y GPS de parada se actualizan en la vista previa sin editar archivos del frontend');
    const ids = adminStops.map(stop => stop.parada_id); [ids[0], ids[1]] = [ids[1], ids[0]];
    await request('PUT', `/admin/rutas/${cascoId}/orden`, { parada_ids: ids }, 200, 'admin');
    await request('PATCH', `/admin/rutas/${cascoId}/estado`, { estado: 'publicado' }, 200, 'admin');
    assert.deepEqual((await get()).rutas.find(item => item.ruta_id === cascoId).paradas.map(stop => stop.parada_id), ids); assert.deepEqual((await pool.query('SELECT parada_id,orden FROM public.recorrido_parada WHERE recorrido_id=$1 ORDER BY orden', [journey])).rows, frozen); record('Reordenación visible al publicar; el orden del recorrido anterior permanece intacto');
    const snapshotName = (await get()).atractivos.find(item => item.atractivo_id === placeId).nombre;
    await consultar(limited, async client => {
      await client.query("SELECT * FROM public.listar_atractivos_publicados('es',NULL)");
      await pool.query('SELECT public.admin_guardar_atractivo_traduccion($1,$2,$3,$4,$5,$6)', [users.admin.token, placeId, 'es', 'Nombre posterior a la instantánea', edited.descripcion, null]);
      assert.equal((await leerCatalogo(client)).atractivos.find(item => item.atractivo_id === placeId).nombre, snapshotName);
    });
    assert.equal((await get()).atractivos.find(item => item.atractivo_id === placeId).nombre, 'Nombre posterior a la instantánea'); record('Lectura consistente: una edición concurrente no mezcla dos versiones en la misma respuesta');
    const disposable = seed.rutas[0].id;
    await request('PATCH', `/admin/rutas/${disposable}/estado`, { estado: 'borrador' }, 200, 'admin'); await request('DELETE', `/admin/rutas/${disposable}`, {}, 200, 'admin');
    assert(!(await get()).rutas.some(item => item.ruta_id === disposable)); assert(!(await preview()).rutas.some(item => item.ruta_id === disposable)); record('Eliminar ruta sin historial la retira también de los catálogos, sin resucitar la copia local');
    const publicPayload = JSON.stringify(await get()); assert(!/"(?:password_hash|token_sesion|token_original|email|usuario_id)"\s*:/.test(publicPayload)); record('El catálogo público no incluye cuentas, hashes ni secretos de sesión');
    assert.equal((await request('GET', '/catalogo?idioma=en')).rutas.length, 2); record('Lectura inglesa existente sin simular traducción integral de la interfaz');
    publicApi = await start('backend/server.cjs', [], { ...environment, PORT: '13022', CASABLANCA_PUBLICO: 'true' }, 'API: ');
    assert.equal((await request('GET', '/catalogo', undefined, 200, null, true)).rutas.length, 2);
    await request('GET', '/admin/vista-previa/catalogo', undefined, 403, 'turista', true);
    assert.equal((await request('GET', '/admin/vista-previa/catalogo', undefined, 200, 'admin', true)).vista_previa, true);
    await request('GET', '/catalogo', undefined, 403, null, true, 'https://ajeno.example'); record('Modo público: catálogo por origen permitido, vista previa por Bearer admin y denegación de turista/origen ajeno');
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM public.usuario')).rows[0].n, 2); assert.equal((await pool.query('SELECT count(*)::int AS n FROM public.recorrido_usuario WHERE id=$1', [journey])).rows[0].n, 1); record('Las consultas y cambios preservan las cuentas, sesiones y el historial creado en la prueba');
    fs.writeFileSync(path.join(__dirname, 'resultado-catalogo.json'), JSON.stringify({ fecha: new Date().toISOString(), entorno: (await pool.query('SELECT version() AS postgres, public.postgis_full_version() AS postgis')).rows[0], casos: results }, null, 2));
  } finally {
    await limited.end();
    for (const child of [api, publicApi].filter(Boolean)) child.kill('SIGTERM');
    await Promise.all([api, publicApi].filter(Boolean).map(child => new Promise(resolve => child.exitCode !== null || child.signalCode ? resolve() : child.once('exit', resolve))));
  }
}).catch(error => { console.error(error); process.exitCode = 1; });

// RESULTADO 19/11/2026: 24 grupos correctos, 0 fallos; PostgreSQL 17.11/PostGIS 3.5.2 reales. BD y rol temporales eliminados al terminar.
