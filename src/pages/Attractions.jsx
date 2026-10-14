import { attractions } from '../data/attractions'

function Attractions() {
  return (
    <section className="page attractions-page">
      <header className="page-heading">
        <p className="page-eyebrow">Descubre Casablanca</p>
        <h1>Atractivos turísticos</h1>
        <p className="page-intro">
          Conoce los espacios históricos, culturales y patrimoniales
          que forman parte de la identidad de Casablanca.
        </p>
      </header>

      <p className="demo-notice">Contenido de presentación: estos atractivos todavía proceden del catálogo local del prototipo.</p>
      <div className="attractions-grid">
        {attractions.map((attraction) => (
          <article className="content-card attraction-card" key={attraction.id}>
            <div className="card-media">
              <img
                src={attraction.image}
                alt={attraction.name}
                loading="lazy"
              />
            </div>

            <div className="card-body">
              <h2>{attraction.name}</h2>
              <p>{attraction.description}</p>
            </div>
          </article>
        ))}
      </div>
    </section>
  )
}

export default Attractions
