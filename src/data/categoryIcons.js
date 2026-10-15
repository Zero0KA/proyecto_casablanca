export const categoryIcons = [
  { code: 'landmark', label: 'Museo' }, { code: 'book', label: 'Libro' },
  { code: 'tree', label: 'Naturaleza' }, { code: 'church', label: 'Iglesia' },
  { code: 'theater', label: 'Teatro' }, { code: 'camera', label: 'Fotografía' },
  { code: 'map_pin', label: 'Ubicación' }, { code: 'utensils', label: 'Gastronomía' },
  { code: 'wine', label: 'Vino' }, { code: 'building', label: 'Edificio' },
]
export function categoryCode(nombre, existing) {
  const stem = nombre.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').replace(/^[^a-z]+/, '').slice(0, 43) || 'categoria'
  let code = stem, suffix = 2
  const used = new Set(existing.map(item => item.codigo))
  while (used.has(code)) code = `${stem}_${suffix++}`
  return code
}
