'use strict';
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const { spawn, spawnSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');

const ROOT = __dirname;
const REPO = 'Zero0KA/proyecto_casablanca';
const PAGES = 'https://zero0ka.github.io/proyecto_casablanca/';
const CONFIG = 'public/demo-api.json';
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
let api, tunel, cerrado = false, terminando = false;
let lockFd;
const lockPath = path.join(ROOT, '.demo-publica.lock');

function command(exe, args, visible = false) {
  const r = spawnSync(exe, args, { cwd: ROOT, encoding: 'utf8', stdio: visible ? 'inherit' : 'pipe', windowsHide: true });
  if (r.error || r.status !== 0) throw new Error(`${exe} ${args[0] || ''} falló. ${visible ? 'Revisa el mensaje anterior.' : 'Comprueba que esté instalado y autorizado.'}`);
  return (r.stdout || '').trim();
}
function mainBranch() {
  if (command('git', ['branch', '--show-current']) !== 'main') throw new Error('Abre la versión publicada en la rama main. La preparación en demo-tunel debe terminar antes.');
  const remote = command('git', ['remote', 'get-url', 'origin']);
  if (!/^https:\/\/github\.com\/Zero0KA\/proyecto_casablanca(?:\.git)?\/?$/i.test(remote)) throw new Error('origin no corresponde al repositorio Casablanca esperado.');
  if (command('git', ['status', '--porcelain'])) throw new Error('Hay cambios locales sin guardar. Haz el commit de preparación antes de iniciar; no se publicarán archivos adicionales automáticamente.');
}
function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.once('error', () => reject(new Error('El puerto 3001 está ocupado. Detén la API anterior con Ctrl+C y repite.')));
    s.listen(3001, '127.0.0.1', () => s.close(resolve));
  });
}
function takeLock() {
  try { lockFd = fs.openSync(lockPath, 'wx'); }
  catch (e) {
    if (e.code !== 'EEXIST') throw e;
    const previous = Number(fs.readFileSync(lockPath, 'utf8'));
    let alive = false;
    if (Number.isInteger(previous) && previous > 0) {
      try { process.kill(previous, 0); alive = true; } catch (error) { if (error.code === 'EPERM') alive = true; }
    }
    if (alive) throw new Error('Ya hay un lanzador público abierto. Usa esa ventana o ciérrala con Ctrl+C.');
    fs.unlinkSync(lockPath);
    lockFd = fs.openSync(lockPath, 'wx');
  }
  fs.writeFileSync(lockFd, String(process.pid));
}
function stop() {
  if (terminando) return;
  terminando = true;
  cerrado = true;
  for (const child of [tunel, api]) if (child && child.exitCode === null) child.kill();
  if (lockFd !== undefined) {
    fs.closeSync(lockFd); lockFd = undefined;
    fs.unlinkSync(lockPath);
  }
}
async function dbReady() {
  for (let i = 0; i < 30; i++) {
    if (api.exitCode !== null || cerrado) throw new Error('La API se detuvo antes de estar lista.');
    try {
      const r = await fetch('http://127.0.0.1:3001/api/publico/estado', { signal: AbortSignal.timeout(3000) });
      if (r.ok && (await r.json()).conectado === true) return;
    } catch { /* Espera la primera conexión local. */ }
    await sleep(1000);
  }
  throw new Error('No se pudo conectar con PostgreSQL. Comprueba el servicio y backend/.env.');
}
function quickTunnel() {
  return new Promise((resolve, reject) => {
    let found = false, buffer = '';
    const timeout = setTimeout(() => { if (!found) reject(new Error('Cloudflare no entregó una dirección en 90 segundos. Comprueba Internet.')); }, 90000);
    tunel = spawn('cloudflared', ['tunnel', '--url', 'http://127.0.0.1:3001'], { cwd: ROOT, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
    function read(chunk) {
      buffer = (buffer + chunk.toString()).slice(-12000);
      const match = buffer.match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com/);
      if (match && !found) { found = true; clearTimeout(timeout); resolve(match[0]); }
    }
    tunel.stdout.on('data', read); tunel.stderr.on('data', read);
    tunel.once('error', () => { clearTimeout(timeout); reject(new Error('No se pudo ejecutar cloudflared. Reabre la terminal y verifica cloudflared --version.')); });
    tunel.once('exit', () => {
      clearTimeout(timeout);
      if (!found) reject(new Error('El túnel se cerró antes de entregar un enlace. Si tienes configuración propia de Cloudflare, revisa su compatibilidad con Quick Tunnels.'));
      else if (!terminando) { console.error('El túnel se cerró. La presentación dejó de estar conectada.'); process.exitCode = 1; stop(); }
    });
  });
}
async function externalReady(origin) {
  for (let i = 0; i < 30; i++) {
    if (cerrado) throw new Error('Se detuvo el lanzador.');
    try {
      const r = await fetch(origin + '/api/publico/estado', { headers: { Origin: 'https://zero0ka.github.io' }, signal: AbortSignal.timeout(4000) });
      if (r.ok && r.headers.get('access-control-allow-origin') === 'https://zero0ka.github.io' && (await r.json()).conectado === true) return;
    } catch { /* DNS y conexión del túnel pueden tardar. */ }
    await sleep(1000);
  }
  throw new Error('El túnel no respondió públicamente. No se actualizó GitHub.');
}
async function waitPages(config) {
  for (let i = 0; i < 100; i++) {
    if (cerrado) throw new Error('Se detuvo el lanzador.');
    try {
      const r = await fetch(PAGES + 'demo-api.json?verificar=' + Date.now(), { cache: 'no-store', signal: AbortSignal.timeout(5000) });
      if (r.ok) {
        const current = await r.json();
        if (current.publicacion_id === config.publicacion_id && current.api_url === config.api_url) return;
      }
    } catch { /* Espera el despliegue de Pages. */ }
    if (i % 5 === 0) console.log('Esperando que GitHub Pages publique la conexión...');
    await sleep(5000);
  }
  throw new Error('GitHub Pages todavía no publicó el cambio. Revisa Actions; no se considera lista la presentación.');
}
function openBrowser(url) {
  if (process.platform === 'win32') {
    const child = spawn('rundll32.exe', ['url.dll,FileProtocolHandler', url], { detached: true, stdio: 'ignore', windowsHide: true });
    child.on('error', () => console.log('Abre manualmente: ' + url)); child.unref();
  }
}
async function main() {
  command('cloudflared', ['--version']);
  command('gh', ['auth', 'status']);
  mainBranch();
  command('git', ['fetch', 'origin', 'main']);
  if (command('git', ['rev-parse', 'HEAD']) !== command('git', ['rev-parse', 'origin/main'])) throw new Error('La copia local y GitHub main difieren. Actualiza/revisa antes de iniciar; no se hará una fusión automática.');
  if (!fs.existsSync(path.join(ROOT, 'backend', '.env'))) throw new Error('Falta backend/.env privado. Cópialo una vez desde la versión integrada.');
  if (!fs.existsSync(path.join(ROOT, 'backend', 'node_modules', 'pg'))) throw new Error('Faltan dependencias del backend. Ejecuta npm.cmd ci dentro de backend una vez.');
  takeLock();
  await freePort();
  console.log('Iniciando API para GitHub Pages...');
  api = spawn(process.execPath, ['server.cjs'], { cwd: path.join(ROOT, 'backend'), env: { ...process.env, CASABLANCA_PUBLICO: 'true', PORT: '3001' }, stdio: ['ignore', 'inherit', 'inherit'], windowsHide: true });
  api.once('error', () => { console.error('No se pudo iniciar Node para la API.'); process.exitCode = 1; stop(); });
  api.once('exit', () => { if (!terminando) { console.error('La API se cerró. La presentación dejó de estar conectada.'); process.exitCode = 1; stop(); } });
  await dbReady();
  console.log('Abriendo túnel temporal...');
  const origin = await quickTunnel();
  await externalReady(origin);
  const config = { activo: true, api_url: origin + '/api', publicacion_id: randomUUID(), actualizado_en: new Date().toISOString() };
  fs.writeFileSync(path.join(ROOT, CONFIG), JSON.stringify(config, null, 2) + '\n');
  command('git', ['add', '--', CONFIG]);
  // Revisa nuevamente que el commit solo contenga la dirección pública.
  if (command('git', ['diff', '--cached', '--name-only']) !== CONFIG) throw new Error('Hay otros archivos preparados. Se detuvo la publicación para no mezclarlos.');
  command('git', ['commit', '-m', 'Actualizar conexión de API para presentación'], true);
  command('git', ['push', 'origin', 'HEAD:main'], true);
  await waitPages(config);
  console.log('\nLISTO: ' + PAGES);
  console.log('Comparte ese enlace habitual. Mantén esta ventana y PostgreSQL activos.');
  console.log('Ctrl+C detiene la API y el túnel. No elimina registros ni cambia roles.');
  openBrowser(PAGES);
}
process.once('SIGINT', () => { console.log('\nDeteniendo presentación...'); stop(); });
process.once('SIGTERM', stop);
process.once('exit', stop);
main().catch(error => { console.error('\n' + error.message); process.exitCode = 1; stop(); });
