import { useEffect, useState } from 'react'
import { fetchApi } from '../components/demoTransport'
import CategoryIcon from '../components/CategoryIcon'
import { categoryIcons, categoryCode } from '../data/categoryIcons'
const API = `${import.meta.env.BASE_URL}api/categorias`
async function consultar(url, options = {}) {
  const response = await fetchApi(url, options), data = await response.json()
  if (!response.ok) throw new Error(data.mensaje || 'No se pudo completar la operación.')
  return data
}
export default function Categories() {
  const [categorias, setCategorias] = useState([]), [nombre, setNombre] = useState(''), [icono, setIcono] = useState('landmark')
  const [editando, setEditando] = useState(null), [ocupado, setOcupado] = useState(true), [error, setError] = useState(''), [mensaje, setMensaje] = useState('')
  useEffect(() => {
    const controller = new AbortController()
    consultar(API, { signal: controller.signal }).then(setCategorias).catch(fallo => { if (fallo.name !== 'AbortError') setError(fallo.message) }).finally(() => { if (!controller.signal.aborted) setOcupado(false) })
    return () => controller.abort()
  }, [])
  function limpiar() { setNombre(''); setIcono('landmark'); setEditando(null) }
  async function guardar(event) {
    event.preventDefault(); if (ocupado) return
    setOcupado(true); setError(''); setMensaje('')
    try {
      await consultar(editando ? `${API}/${editando.categoria_id}` : API, { method: editando ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ nombre: nombre.trim(), icono_codigo: icono, ...(!editando ? { codigo: categoryCode(nombre, categorias) } : {}) }) })
      setMensaje(editando ? 'Categoría actualizada.' : 'Categoría creada.'); limpiar(); setCategorias(await consultar(API))
    } catch (fallo) { setError(fallo.message) } finally { setOcupado(false) }
  }
  async function eliminar(item) {
    if (ocupado || !window.confirm(`¿Eliminar la categoría "${item.nombre || item.codigo}"?`)) return
    setOcupado(true); setError(''); setMensaje('')
    try { await consultar(`${API}/${item.categoria_id}`, { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: '{}' }); if (editando?.categoria_id === item.categoria_id) limpiar(); setMensaje('Categoría eliminada.'); setCategorias(await consultar(API)) }
    catch (fallo) { setError(fallo.message) } finally { setOcupado(false) }
  }
  function editar(item) { setEditando(item); setNombre(item.nombre || item.codigo.replaceAll('_', ' ')); setIcono(item.icono_codigo); setError(''); setMensaje(''); document.getElementById('categoria-nombre')?.focus() }
  return <section className="page admin-page category-page"><h1>Administrar categorías</h1>
    {error && <p role="alert" className="cuenta-error">{error}</p>}{mensaje && <p role="status" className="success-notice">{mensaje}</p>}
    <div className="category-layout"><form onSubmit={guardar}><fieldset disabled={ocupado}><legend>{editando ? 'Editar categoría' : 'Crear categoría'}</legend>
      <label htmlFor="categoria-nombre">Nombre de la categoría</label><input id="categoria-nombre" value={nombre} onChange={event => setNombre(event.target.value)} maxLength={100} placeholder="Cultura y patrimonio" required />
      <fieldset className="category-icon-picker"><legend>Icono</legend><div className="category-icon-options">{categoryIcons.map(item => <label key={item.code} className={`category-icon-choice${icono === item.code ? ' selected' : ''}`}><input type="radio" name="categoria-icono" value={item.code} checked={icono === item.code} onChange={() => setIcono(item.code)} /><CategoryIcon code={item.code} /><span>{item.label}</span></label>)}
        {!categoryIcons.some(item => item.code === icono) && <label className="category-icon-choice selected"><input type="radio" name="categoria-icono" value={icono} checked readOnly /><CategoryIcon code={icono} /><span>Actual: {icono}</span></label>}
      </div></fieldset><div className="category-form-actions"><button type="submit">{ocupado ? 'Guardando…' : editando ? 'Guardar cambios' : 'Crear categoría'}</button>{editando && <button type="button" onClick={limpiar}>Cancelar</button>}</div>
    </fieldset></form><aside className="category-preview" aria-label="Vista previa"><p className="page-eyebrow">VISTA PREVIA</p><CategoryIcon code={icono} /><h2>{nombre.trim() || 'Nombre de la categoría'}</h2></aside></div>
    <h2>Categorías guardadas</h2>{ocupado && <p role="status">Procesando…</p>}{!ocupado && !categorias.length && <p>No hay categorías registradas.</p>}
    {categorias.length > 0 && <div className="category-table-wrap"><table><thead><tr><th scope="col">Categoría</th><th scope="col">Icono</th><th scope="col">Estado</th><th scope="col">Acciones</th></tr></thead><tbody>{categorias.map(item => <tr key={item.categoria_id}><td><strong>{item.nombre || item.codigo.replaceAll('_', ' ')}</strong></td><td><span className="category-table-icon"><CategoryIcon code={item.icono_codigo} />{categoryIcons.find(icon => icon.code === item.icono_codigo)?.label || item.icono_codigo}</span></td><td>{item.activo ? 'Activa' : 'Inactiva'}</td><td><div className="user-row-actions"><button type="button" disabled={ocupado} onClick={() => editar(item)}>Editar</button><button type="button" disabled={ocupado} onClick={() => eliminar(item)}>Eliminar</button></div></td></tr>)}</tbody></table></div>}
  </section>
}
