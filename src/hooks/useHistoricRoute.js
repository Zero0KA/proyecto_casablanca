import { useEffect, useState } from 'react'
import { historicRouteRepository } from '../services/historicRouteRepository'

export function useHistoricRoute() {
  const [route, setRoute] = useState(null)
  const [error, setError] = useState('')
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    const controller = new AbortController()
    historicRouteRepository.getRoute({ signal: controller.signal }).then(value => {
      if (!controller.signal.aborted) { setRoute(value); setError('') }
    }).catch(failure => {
      if (!controller.signal.aborted) setError(failure.message || 'No se pudo cargar el recorrido.')
    })
    return () => controller.abort()
  }, [revision])
  return { route, error, retry: () => { setRoute(null); setError(''); setRevision(value => value + 1) } }
}
