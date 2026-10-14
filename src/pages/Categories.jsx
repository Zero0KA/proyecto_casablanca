import { fetchApi } from '../components/demoTransport'
import { useEffect, useState } from 'react'

const API = `${import.meta.env.BASE_URL}api/categorias`

async function consultarApi(url, opciones = {}) {
  const respuesta = await fetchApi(url, opciones)
  const datos = await respuesta.json()

  if (!respuesta.ok) {
    throw new Error(datos.mensaje || 'No se pudo completar la operación.')
  }

  return datos
}

function Categories() {
  const [categorias, setCategorias] = useState([])
  const [codigo, setCodigo] = useState('')
  const [icono, setIcono] = useState('')
  const [editando, setEditando] = useState(null)
  const [ocupado, setOcupado] = useState(true)
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')

  useEffect(() => {
    const controlador = new AbortController()

    consultarApi(API, { signal: controlador.signal })
      .then(setCategorias)
      .catch((fallo) => {
        if (fallo.name !== 'AbortError') setError(fallo.message)
      })
      .finally(() => {
        if (!controlador.signal.aborted) setOcupado(false)
      })

    return () => controlador.abort()
  }, [])

  function limpiarFormulario() {
    setCodigo('')
    setIcono('')
    setEditando(null)
  }

  async function guardar(evento) {
    evento.preventDefault()
    setOcupado(true)
    setError('')
    setMensaje('')

    try {
      const esEdicion = editando !== null

      await consultarApi(
        esEdicion ? `${API}/${editando}/icono` : API,
        {
          method: esEdicion ? 'PATCH' : 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(
            esEdicion
              ? { icono_codigo: icono }
              : { codigo, icono_codigo: icono }
          ),
        }
      )

      limpiarFormulario()
      setMensaje(esEdicion ? 'Icono actualizado.' : 'Categoría creada.')
      setCategorias(await consultarApi(API))
    } catch (fallo) {
      setError(fallo.message)
    } finally {
      setOcupado(false)
    }
  }

  async function eliminar(categoria) {
    if (!window.confirm(`¿Eliminar la categoría "${categoria.codigo}"?`)) {
      return
    }

    setOcupado(true)
    setError('')
    setMensaje('')

    try {
      await consultarApi(`${API}/${categoria.categoria_id}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: '{}',
      })

      if (editando === categoria.categoria_id) limpiarFormulario()

      setMensaje('Categoría eliminada.')
      setCategorias(await consultarApi(API))
    } catch (fallo) {
      setError(fallo.message)
    } finally {
      setOcupado(false)
    }
  }

  function editar(categoria) {
    setEditando(categoria.categoria_id)
    setCodigo(categoria.codigo)
    setIcono(categoria.icono_codigo)
    setError('')
    setMensaje('')
  }

  return (
    <section className="page admin-page">
      <h1>Administrar categorías</h1>
      <p>Gestiona las categorías con tu cuenta administradora.</p>

      {error && <p role="alert">{error}</p>}
      {mensaje && <p role="status">{mensaje}</p>}

      <form onSubmit={guardar}>
        <fieldset disabled={ocupado}>
          <legend>
            {editando ? 'Editar icono' : 'Crear categoría'}
          </legend>

          <p>
            <label htmlFor="categoria-codigo">Identificador de categoría</label>
            <br />
            <input
              id="categoria-codigo"
              value={codigo}
              onChange={(evento) => setCodigo(evento.target.value)}
              disabled={editando !== null}
              maxLength={50}
              pattern="[a-z][a-z0-9_]{0,49}"
              placeholder="cultura"
              required
            />
          </p>

          <p>
            <label htmlFor="categoria-icono">Código del icono</label>
            <br />
            <input
              id="categoria-icono"
              value={icono}
              onChange={(evento) => setIcono(evento.target.value)}
              maxLength={50}
              pattern="[a-z][a-z0-9_]{0,49}"
              placeholder="landmark"
              required
            />
          </p>

          <p>Usa minúsculas, números o guion bajo; comienza con una letra.</p>

          <button type="submit">
            {editando ? 'Guardar icono' : 'Crear'}
          </button>

          {editando && (
            <button type="button" onClick={limpiarFormulario}>
              Cancelar
            </button>
          )}
        </fieldset>
      </form>

      <h2>Categorías guardadas</h2>

      {ocupado && <p role="status">Procesando…</p>}

      {!ocupado && categorias.length === 0 && (
        <p>No hay categorías registradas.</p>
      )}

      {categorias.length > 0 && (
        <table>
          <thead>
            <tr>
              <th scope="col">Código</th>
              <th scope="col">Icono</th>
              <th scope="col">Estado</th>
              <th scope="col">Acciones</th>
            </tr>
          </thead>
          <tbody>
            {categorias.map((categoria) => (
              <tr key={categoria.categoria_id}>
                <td>{categoria.codigo}</td>
                <td>{categoria.icono_codigo}</td>
                <td>{categoria.activo ? 'Activa' : 'Inactiva'}</td>
                <td>
                  <button
                    type="button"
                    disabled={ocupado}
                    onClick={() => editar(categoria)}
                  >
                    Editar icono
                  </button>
                  <button
                    type="button"
                    disabled={ocupado}
                    onClick={() => eliminar(categoria)}
                  >
                    Eliminar
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}

export default Categories