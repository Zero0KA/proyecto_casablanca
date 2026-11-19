import { useEffect, useState } from 'react'
import { useLocation } from 'react-router-dom'
import { apiFetch, useSession } from '../components/SessionContext'
import { normalizeCatalog } from '../services/catalogModel.js'

export function useCatalog() {
  const location = useLocation()
  const { usuario } = useSession()
  const preview = new URLSearchParams(location.search).get('vista_previa') === '1'
  const [revision, setRevision] = useState(0)
  const [result, setResult] = useState({ key: '', catalog: null, error: '', status: 'loading' })
  const key = `${location.pathname}:${preview ? `admin:${usuario?.usuario_id || usuario?.id || usuario?.email || ''}:${usuario?.administrador === true}` : 'public'}`
  useEffect(() => {
    const controller = new AbortController()
    const endpoint = preview ? '/admin/vista-previa/catalogo' : '/catalogo'
    apiFetch(endpoint, { signal: controller.signal, cache: 'no-store' }).then(payload => {
      const catalog = normalizeCatalog(payload, preview)
      if (!controller.signal.aborted) setResult({ key, catalog, error: '', status: 'ready' })
    }).catch(error => {
      if (!controller.signal.aborted) setResult({ key, catalog: null, error: error.message, status: 'error' })
    })
    return () => controller.abort()
  }, [key, preview, revision])
  useEffect(() => {
    const refresh = () => setRevision(value => value + 1)
    window.addEventListener('focus', refresh)
    return () => window.removeEventListener('focus', refresh)
  }, [])
  const current = result.key === key ? { catalog: result.catalog, error: result.error, status: result.status } : { catalog: null, error: '', status: 'loading' }
  return { ...current, preview, retry: () => setRevision(value => value + 1) }
}
