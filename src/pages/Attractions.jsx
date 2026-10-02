import { attractions } from '../data/attractions'

function Attractions() {
  return (
    <section className="page">
      <h1>Atracciones</h1>
      <ul>
        {attractions.map((attraction) => (
          <li key={attraction.id}>
            <h2>{attraction.name}</h2>
            <p>{attraction.description}</p>   
            <img
              src={attraction.image}
              alt={attraction.name}
            />         
          </li>
        ))}
      </ul>
    </section>
  )
}

export default Attractions
