
export default function Footer() {
  function goTop() {
    window.scrollTo({ top: 0, behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
    document.getElementById('contenido')?.focus({ preventScroll: true })
  }
  return <footer className="site-footer refreshed-footer"><div className="footer-inner">
    <div className="footer-identity"><p className="footer-brand">Casablanca</p><p className="footer-description">Atractivos y rutas de la comuna.</p><p className="footer-department">Proyecto para el Departamento de Turismo de Casablanca.</p></div>
  </div><div className="footer-bottom"><p>Casablanca, Región de Valparaíso · Chile</p><button type="button" onClick={goTop}>Volver arriba ↑</button></div></footer>
}
