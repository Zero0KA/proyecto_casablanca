import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { createRequire } from 'node:module'
const { acquirePublicLock, inspectProcess } = createRequire(import.meta.url)('../backend/publicacion-lock.cjs')

function fixture(task) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'casablanca-lock-'))
  try { task(root, path.join(root, '.demo-publica.lock')) } finally { fs.rmSync(root, { recursive: true, force: true }) }
}
const current = { start: 'inicio_actual', command: 'node compartir-demo.cjs' }
test('El bloqueo nuevo guarda identidad de proceso y se libera al terminar', () => fixture((root, file) => {
  const release = acquirePublicLock(root, { inspect: () => current, pid: 10 })
  assert.equal(JSON.parse(fs.readFileSync(file)).version, 2); release(); assert.equal(fs.existsSync(file), false)
}))
test('Una segunda instancia reconoce al lanzador activo', () => fixture(root => {
  const release = acquirePublicLock(root, { inspect: () => current, pid: 10 })
  assert.throws(() => acquirePublicLock(root, { inspect: () => current, pid: 10 }), /Ya hay/); release()
}))
test('Un PID reutilizado después de reiniciar no se confunde con el proceso anterior', () => fixture((root, file) => {
  fs.writeFileSync(file, JSON.stringify({ pid: 10, start: 'arranque_anterior', nonce: 'viejo' }))
  const release = acquirePublicLock(root, { inspect: () => current, pid: 10 }); release()
}))
test('El formato antiguo se recupera si ese PID pertenece ahora a otro programa', () => fixture((root, file) => {
  fs.writeFileSync(file, '20')
  const release = acquirePublicLock(root, { inspect: pid => pid === 20 ? { start: 'otro', command: 'editor.exe' } : current, pid: 10 }); release()
}))
test('El formato antiguo respeta a un lanzador que sigue activo', () => fixture((root, file) => {
  fs.writeFileSync(file, '20')
  assert.throws(() => acquirePublicLock(root, { inspect: () => current, pid: 10 }), /Ya hay/)
}))
test('Un archivo de bloqueo de un proceso inexistente se reemplaza', () => fixture((root, file) => {
  fs.writeFileSync(file, '20')
  const release = acquirePublicLock(root, { inspect: pid => pid === 20 ? null : current, pid: 10 }); release()
}))
test('Una salida antigua no elimina el bloqueo de otra instancia', () => fixture((root, file) => {
  const release = acquirePublicLock(root, { inspect: () => current, pid: 10 })
  fs.writeFileSync(file, JSON.stringify({ pid: 10, nonce: 'otra_instancia' })); release(); assert.equal(fs.existsSync(file), true)
}))
test('Un bloqueo incompleto recién creado no se borra durante el arranque', () => fixture((root, file) => {
  fs.writeFileSync(file, '')
  assert.throws(() => acquirePublicLock(root, { inspect: () => current, pid: 10 }), /iniciándose/)
}))
test('Un archivo incompleto antiguo se recupera tras una salida abrupta', () => fixture((root, file) => {
  fs.writeFileSync(file, ''); fs.utimesSync(file, new Date(0), new Date(0))
  const release = acquirePublicLock(root, { inspect: () => current, pid: 10 }); release()
}))
test('Se obtiene una identidad real del proceso de pruebas', () => {
  const info = inspectProcess(process.pid); assert.equal(typeof info.start, 'string'); assert.equal(typeof info.command, 'string')
})

// RESULTADO 19/11/2026: 10 pruebas correctas, 0 fallos; identidad nativa comprobada en Linux y casos de PID modelados. Windows pendiente de aceptación en el PC.
