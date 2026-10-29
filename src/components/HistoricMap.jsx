import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import './HistoricMap.css'

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

export function LandmarkIcon({ symbol, ...props }) {
  const common = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round' }
  const drawings = {
    monument: <><path d="M15 5h6v23h-6zM12 29h12v4H12M9 34h18M16 5l2-3 2 3" /><path d="M18 10v13" /></>,
    park: <><path d="M12 28V16m-4 4h8M25 28V12m-5 5h10M7 32h24" /><path d="M12 5C4 5 4 17 12 17S20 5 12 5Zm13-2c-7 0-7 11 0 11s7-11 0-11Z" /></>,
    church: <><path d="M7 32V15h10v17m0-16h7l7 7v9H7M9 15V8h6v7m-3-7V3m-3 2h6M11 32v-9h4v9m7-2v-7h5v7" /></>,
    museum: <><path d="m5 13 13-8 13 8H5Zm3 3v13m7-13v13m7-13v13m7-13v13M5 32h26M4 35h28" /></>,
    civic: <><path d="M5 15h27v17H5Zm-1 0 14-9 15 9M10 20v8m8-8v8m8-8v8M4 33h29M18 6V2h9v5h-9" /></>,
    shop: <><path d="M7 18v15h24V18M5 13h28l-3-7H8Zm0 0v4c3 4 6 0 6 0s3 4 7 0c4 4 7 0 7 0s4 4 8 0v-4M12 33V23h7v10m4-10h5v5h-5" /></>,
    firehouse: <><path d="M5 14h28v19H5Zm2 0V7h24v7M10 33V20h8v13m5 0V20h6v13M11 24h6m7 0h4M13 10h12" /></>,
    house: <><path d="m4 16 14-11 15 11M7 15v18h24V15M15 33V22h7v11M10 18h3v4h-3m14-4h3v4h-3" /></>,
  }
  return <svg viewBox="0 0 38 38" aria-hidden="true" {...common} {...props}>{drawings[symbol] || drawings.house}</svg>
}

function constrainBox(box, width, height) {
  return { ...box, x: clamp(box.x, -width * .08, width - box.width + width * .08), y: clamp(box.y, -height * .08, height - box.height + height * .08) }
}

export default function HistoricMap({ route, selectedKey, onSelect }) {
  const { width, height, image } = route.illustration
  const [box, setBox] = useState({ x: 0, y: 0, width, height })
  const [showPath, setShowPath] = useState(true)
  const [dragging, setDragging] = useState(false)
  const [imageFailed, setImageFailed] = useState(false)
  const [imageRevision, setImageRevision] = useState(0)
  const [viewport, setViewport] = useState({ width, height })
  const stage = useRef(null)
  const pointers = useRef(new Map())
  const gesture = useRef(null)
  const moved = useRef(false)
  const selected = route.stops.find(stop => stop.key === selectedKey) || route.stops[0]
  const selectedIndex = route.stops.findIndex(stop => stop.key === selected.key)
  const zoom = width / box.width
  const imageUrl = `${import.meta.env.BASE_URL}${image}${imageRevision ? `?reintento=${imageRevision}` : ''}`
  const pinScale = Math.max(1, Math.max(box.width / viewport.width, box.height / viewport.height) * .86)

  useEffect(() => {
    const observer = new ResizeObserver(entries => {
      const rect = entries[0]?.contentRect
      if (rect?.width && rect.height) setViewport({ width: rect.width, height: rect.height })
    })
    observer.observe(stage.current)
    return () => observer.disconnect()
  }, [])

  function changeZoom(nextZoom) {
    const next = clamp(nextZoom, 1, 3.5)
    setBox(current => constrainBox({ x: current.x + (current.width - width / next) / 2, y: current.y + (current.height - height / next) / 2, width: width / next, height: height / next }, width, height))
  }

  function reset() { setBox({ x: 0, y: 0, width, height }) }

  function beginGesture(svg) {
    const points = [...pointers.current.values()]
    const rect = svg.getBoundingClientRect()
    gesture.current = { box, points, scale: Math.max(box.width / rect.width, box.height / rect.height) }
  }

  function pointerDown(event) {
    if (event.button !== 0) return
    if (!pointers.current.size) moved.current = false
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY })
    const onStop = event.target.closest('[data-map-stop]')
    if (!onStop) event.currentTarget.setPointerCapture(event.pointerId)
    if (pointers.current.size >= 2) for (const id of pointers.current.keys()) event.currentTarget.setPointerCapture(id)
    beginGesture(event.currentTarget)
    setDragging(!onStop)
  }

  function pointerMove(event) {
    if (!pointers.current.has(event.pointerId) || !gesture.current) return
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY })
    const current = [...pointers.current.values()]
    const start = gesture.current
    if (current.length >= 2 || Math.hypot(current[0].x - start.points[0].x, current[0].y - start.points[0].y) > 3) moved.current = true
    if (!moved.current) return
    if (!event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.setPointerCapture(event.pointerId)
    setDragging(true)
    if (current.length === 1 && start.points.length === 1) {
      setBox(constrainBox({ ...start.box, x: start.box.x - (current[0].x - start.points[0].x) * start.scale, y: start.box.y - (current[0].y - start.points[0].y) * start.scale }, width, height))
    } else if (current.length >= 2 && start.points.length >= 2) {
      const distance = points => Math.hypot(points[1].x - points[0].x, points[1].y - points[0].y)
      const factor = distance(start.points) > 0 ? distance(current) / distance(start.points) : 1
      const nextZoom = clamp(width / start.box.width * factor, 1, 3.5)
      const mid = points => ({ x: (points[0].x + points[1].x) / 2, y: (points[0].y + points[1].y) / 2 })
      const from = mid(start.points), to = mid(current)
      setBox(constrainBox({ width: width / nextZoom, height: height / nextZoom, x: start.box.x + (start.box.width - width / nextZoom) / 2 - (to.x - from.x) * start.scale, y: start.box.y + (start.box.height - height / nextZoom) / 2 - (to.y - from.y) * start.scale }, width, height))
    }
  }

  function pointerEnd(event) {
    pointers.current.delete(event.pointerId)
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId)
    if (pointers.current.size) beginGesture(event.currentTarget)
    else { gesture.current = null; setDragging(false) }
  }

  function keyboardMove(event) {
    if (event.target !== event.currentTarget) return
    const movements = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }
    if (movements[event.key]) {
      event.preventDefault()
      const [x, y] = movements[event.key]
      setBox(current => constrainBox({ ...current, x: current.x + x * current.width / 10, y: current.y + y * current.height / 10 }, width, height))
    } else if (['+', '=', '-', 'Home'].includes(event.key)) {
      event.preventDefault()
      if (event.key === 'Home') reset()
      else changeZoom(zoom + (event.key === '-' ? -.3 : .3))
    }
  }

  function revealStop(stop) {
    onSelect(stop.key)
    if (zoom > 1.1) setBox(current => constrainBox({ ...current, x: stop.position.x - current.width / 2, y: stop.position.y - current.height / 2 }, width, height))
  }

  return <div className="historic-explorer">
    <div className="historic-map-column">
      <div className="historic-map-bar"><span><i aria-hidden="true" /> Ruta del Casco Histórico</span><label className="historic-path-toggle"><input type="checkbox" checked={showPath} onChange={event => setShowPath(event.target.checked)} /> Mostrar trazado</label></div>
      <div ref={stage} className={`historic-map-stage${dragging ? ' is-dragging' : ''}`}>
        <svg className="historic-map-svg" viewBox={`${box.x} ${box.y} ${box.width} ${box.height}`} tabIndex={0} role="group" aria-label="Mapa ilustrado del Casco Histórico. Doce paradas seleccionables." aria-describedby="historic-map-help" onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={pointerEnd} onPointerCancel={pointerEnd} onKeyDown={keyboardMove}>
          <image key={imageRevision} href={imageUrl} x="0" y="0" width={width} height={height} aria-hidden="true" onError={() => setImageFailed(true)} onLoad={() => setImageFailed(false)} />
          {showPath && <g className="historic-walkway" aria-hidden="true" fill="none" strokeLinecap="round" strokeLinejoin="round"><path d={route.path} stroke="#d2ae59" strokeWidth="24" /><path d={route.path} stroke="#eed591" strokeWidth="18" /><path d={route.path} stroke="#72523d" strokeWidth="2.3" strokeDasharray="5 8" /></g>}
          {showPath && <g aria-hidden="true" pointerEvents="none"><rect x="438" y="605" width="160" height="20" rx="3" fill="#eed591" /><text x="518" y="619" textAnchor="middle" fill="#596f70" fontFamily="Arial,sans-serif" fontSize="11" fontWeight="700" letterSpacing="1.1">CHACABUCO</text></g>}
          {route.stops.map(stop => <g key={stop.key} data-map-stop={stop.key} className={`historic-stop-pin${selected.key === stop.key ? ' is-selected' : ''}`} transform={`translate(${stop.position.x} ${stop.position.y}) scale(${pinScale})`} role="button" tabIndex={0} aria-label={`Parada ${stop.order}: ${stop.name}`} aria-pressed={selected.key === stop.key} onClick={() => { if (!moved.current) revealStop(stop) }} onKeyDown={event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); revealStop(stop) } }}>
            <title>{`${stop.order}. ${stop.name}`}</title><circle className="historic-stop-hit" r="29" /><circle className="historic-stop-halo" r="24" /><circle className="historic-stop-disc" r="16" /><text textAnchor="middle" dominantBaseline="central" y="1">{stop.order}</text>
          </g>)}
          <g className="historic-start-label" transform="translate(862 180)" aria-hidden="true"><rect x="-34" y="-14" width="68" height="26" rx="13" /><text textAnchor="middle" y="3">INICIO</text></g>
        </svg>
        <div className="historic-zoom" aria-label="Controles del mapa">
          <button type="button" onClick={() => changeZoom(zoom + .35)} disabled={zoom >= 3.5} aria-label="Acercar mapa" title="Acercar">+</button>
          <button type="button" onClick={() => changeZoom(zoom - .35)} disabled={zoom <= 1} aria-label="Alejar mapa" title="Alejar">−</button>
          <button type="button" className="historic-reset" onClick={reset} aria-label="Ver mapa completo" title="Ver mapa completo"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 9V4h5m6 0h5v5m0 6v5h-5M9 20H4v-5" /></svg></button>
        </div>
        <span className="historic-scale" aria-hidden="true">{Math.round(zoom * 100)} %</span>
        {imageFailed && <div className="historic-image-error" role="alert"><p>No se pudo cargar la ilustración. Las paradas siguen disponibles en la lista.</p><button type="button" onClick={() => setImageRevision(value => value + 1)}>Reintentar</button></div>}
      </div>
      <div className="historic-map-caption"><div className="historic-legend"><span><i className="legend-start" aria-hidden="true" /> Inicio</span><span><i className="legend-stop" aria-hidden="true">1</i> Parada</span><span><i className="legend-path" aria-hidden="true" /> Recorrido</span></div><span>Mapa ilustrado · Sin escala</span></div>
      <p id="historic-map-help" className="historic-map-help">Selecciona una parada para conocerla. Amplía y arrastra para explorar el mapa.<span className="sr-only"> Con el teclado: Tab para elegir paradas, Enter para seleccionarlas; sobre el mapa, más y menos para acercar y alejar, flechas para desplazarte e Inicio para volver a la vista completa.</span></p>
    </div>
    <aside className="historic-sidebar" aria-label="Paradas del Casco Histórico">
      <section className="historic-selected" aria-labelledby="selected-stop-name">
        <div className="historic-selected-top"><span className="historic-stop-position">PARADA {String(selected.order).padStart(2, '0')} <span>/ {route.stops.length}</span></span><LandmarkIcon symbol={selected.symbol} /></div>
        <div className="historic-selected-copy" aria-live="polite" aria-atomic="true"><p className="historic-stop-kind">{selected.kind}</p><h2 id="selected-stop-name">{selected.name}</h2><p>{selected.description}</p></div>
        {selected.attractionId && <Link className="historic-detail-link" to={`/attractions/${selected.attractionId}`}>Conocer el lugar <span aria-hidden="true">↗</span></Link>}
        <div className="historic-stop-navigation"><button type="button" disabled={selectedIndex === 0} onClick={() => revealStop(route.stops[selectedIndex - 1])}><span aria-hidden="true">←</span> Anterior</button><button type="button" disabled={selectedIndex === route.stops.length - 1} onClick={() => revealStop(route.stops[selectedIndex + 1])}>Siguiente <span aria-hidden="true">→</span></button></div>
      </section>
      <section className="historic-stop-list-section" aria-labelledby="historic-stops-title"><div className="historic-list-heading"><h2 id="historic-stops-title">Las doce paradas</h2><span>En orden</span></div>
        <ol className="historic-stop-list">{route.stops.map(stop => <li key={stop.key}><button type="button" aria-current={selected.key === stop.key ? 'location' : undefined} onClick={() => revealStop(stop)}><span className="historic-list-number">{stop.order}</span><span>{stop.name}</span><span className="historic-list-arrow" aria-hidden="true">↗</span></button></li>)}</ol>
      </section>
    </aside>
    <div className="historic-route-footer"><span><strong>Casco Histórico</strong><span>Un recorrido por el centro de Casablanca</span></span><Link to="/routes/catalogo/2">Detalle del recorrido <span aria-hidden="true">→</span></Link></div>
  </div>
}
