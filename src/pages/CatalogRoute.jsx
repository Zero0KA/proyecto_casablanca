import { Navigate, useLocation, useParams } from 'react-router-dom'
import { canonicalRouteId } from '../services/catalogModel.js'

// Conserva los enlaces antiguos sin volver a crear una copia local de la ficha.
export default function CatalogRoute() {
  const { id } = useParams(), location = useLocation()
  const canonical = canonicalRouteId(id)
  return canonical ? <Navigate replace to={`/routes/${canonical}${location.search}`} /> : <section className="page"><h1>Ruta no encontrada</h1></section>
}
