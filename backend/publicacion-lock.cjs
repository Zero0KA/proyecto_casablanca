'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { spawnSync } = require('node:child_process');

function inspectProcess(pid) {
  try { process.kill(pid, 0); }
  catch (error) { if (error.code === 'ESRCH') return null; if (error.code !== 'EPERM') throw error; }
  if (process.platform === 'win32') {
    // PID numérico interno: no se interpolan rutas, contraseñas ni entradas del navegador.
    const script = `$p=Get-CimInstance Win32_Process -Filter 'ProcessId=${pid}'; if($p){ @{start=$p.CreationDate.ToUniversalTime().Ticks.ToString(); command=$p.CommandLine} | ConvertTo-Json -Compress }`;
    const result = spawnSync('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script], { encoding: 'utf8', windowsHide: true, timeout: 6000 });
    if (result.error || result.status !== 0) throw new Error('No se pudo comprobar el proceso del lanzador anterior.');
    if (!result.stdout.trim()) return null;
    return JSON.parse(result.stdout.replace(/^\uFEFF/, ''));
  }
  const stat = fs.readFileSync(`/proc/${pid}/stat`, 'utf8');
  const start = stat.slice(stat.lastIndexOf(')') + 2).trim().split(/\s+/)[19];
  return { start: `${fs.readFileSync('/proc/sys/kernel/random/boot_id', 'utf8').trim()}:${start}`, command: fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').replaceAll('\0', ' ') };
}

function acquirePublicLock(root, { inspect = inspectProcess, pid = process.pid } = {}) {
  const lockPath = path.join(root, '.demo-publica.lock');
  const current = inspect(pid);
  if (!current?.start) throw new Error('No se pudo comprobar la identidad del lanzador actual.');
  const record = { version: 2, pid, start: current.start, nonce: randomUUID(), creado_en: new Date().toISOString() };
  for (let attempt = 0; attempt < 3; attempt++) {
    let fd;
    try {
      fd = fs.openSync(lockPath, 'wx', 0o600);
      fs.writeFileSync(fd, JSON.stringify(record) + '\n');
      fs.closeSync(fd);
      return () => {
        try {
          const owner = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
          if (owner.pid === record.pid && owner.nonce === record.nonce) fs.unlinkSync(lockPath);
        } catch (error) { if (error.code !== 'ENOENT') console.error('No se pudo retirar el bloqueo local del lanzador.'); }
      };
    } catch (error) {
      if (fd !== undefined) { try { fs.closeSync(fd); } catch { /* Ya cerrado. */ } }
      if (error.code !== 'EEXIST') throw error;
    }
    let previousText;
    try { previousText = fs.readFileSync(lockPath, 'utf8'); }
    catch (error) { if (error.code === 'ENOENT') continue; throw error; }
    let previous;
    try { previous = JSON.parse(previousText); } catch { previous = null; }
    if (typeof previous === 'number') previous = { pid: previous }; // Formato anterior.
    const validPid = Number.isSafeInteger(previous?.pid) && previous.pid > 0;
    if (!validPid && Date.now() - fs.statSync(lockPath).mtimeMs < 10000) throw new Error('Otro lanzador está iniciándose. Espera unos segundos y repite.');
    const info = validPid ? inspect(previous.pid) : null;
    const isLauncher = info && typeof info.command === 'string' && /(?:^|[\\/\s"'])compartir-demo\.cjs(?:[\s"']|$)/i.test(info.command);
    const sameProcess = info && (!previous.start || previous.start === info.start);
    if (sameProcess && isLauncher) throw new Error('Ya hay un lanzador público abierto. Usa esa ventana o ciérrala con Ctrl+C.');
    // Se retira un archivo huérfano, no se termina ningún proceso del equipo.
    if (fs.readFileSync(lockPath, 'utf8') !== previousText) continue;
    fs.unlinkSync(lockPath);
  }
  throw new Error('El estado del lanzador cambió. Intenta nuevamente.');
}

module.exports = { acquirePublicLock, inspectProcess };
