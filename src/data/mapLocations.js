// Coordenadas aportadas por el prototipo de Jack_elDes. No son datos de PostgreSQL.
export const mapLocations = { 4: [-33.320855, -71.410977] }
export function coordinatesFor(attraction) {
  const coords = attraction?.coords ?? mapLocations[attraction?.id]
  if (!Array.isArray(coords) || coords.length !== 2 || !coords.every(Number.isFinite)) return null
  return Math.abs(coords[0]) <= 90 && Math.abs(coords[1]) <= 180 ? coords : null
}
