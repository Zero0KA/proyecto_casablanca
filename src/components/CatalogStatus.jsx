import { Link } from 'react-router-dom'
import { useSession } from './SessionContext'

export function PreviewNotice({ preview }) {
  const { usuario } = useSession()
  if (!preview || usuario?.administrador !== true) return null
  return <aside className="catalog-preview" aria-label="Vista previa administrativa"><p><strong>Vista previa</strong> · Solo visible con una cuenta administradora. Incluye contenido sin publicar.</p><Link to="/admin">Volver a Administración</Link></aside>
}

export default function CatalogStatus({ status, error, retry }) {
  if (status === 'loading') return <p className="catalog-status" role="status">Cargando contenido…</p>
  if (status === 'error') return <div className="catalog-status cuenta-error" role="alert"><p>{error || 'No se pudo cargar el contenido.'}</p><button className="btn btn-outline" type="button" onClick={retry}>Reintentar</button></div>
  return null
}
