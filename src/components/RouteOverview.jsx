import { Link } from 'react-router-dom'
export default function RouteOverview({ route, position, headingLevel = 3 }) {
  const Heading = headingLevel === 2 ? 'h2' : 'h3'
  return <article className="route-overview">
    <div className="route-overview-marker" aria-hidden="true"><span>{String(position + 1).padStart(2, '0')}</span><svg viewBox="0 0 48 64"><circle cx="12" cy="8" r="4" /><path d="M12 12v12c0 15 24 6 24 20v8" /><circle cx="36" cy="56" r="4" /></svg></div>
    <div className="route-overview-copy"><Heading>{route.name}</Heading><p>{route.description}</p><div className="route-overview-meta">{route.minutes != null && <span>{route.minutes} min estimados</span>}{route.places.length > 0 && <span>{route.places.length} {route.places.length === 1 ? 'lugar' : 'lugares'}</span>}</div>{route.places.length > 0 && <ul className="route-overview-stops" aria-label="Lugares del recorrido">{route.places.map(place => <li key={place.id}>{place.name}</li>)}</ul>}</div>
    <Link className="home-link route-overview-link" to={route.to}>Ver recorrido <span aria-hidden="true">→</span></Link>
  </article>
}
