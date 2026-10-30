export const existingImages = [
  ['images/museo.jpg','Museo'], ['images/plaza.jpg','Plaza de Armas'],
  ['images/parroquia.jpg','Parroquia'], ['images/biblioteca.jpg','Biblioteca'],
  ['images/centroCultural.jpg','Centro Cultural'], ['images/teatro.png','Teatro'],
  ['maps/casco-historico.svg','Ilustración del Casco Histórico'],
]
export function newContent(kind) {
  return { traducciones: { es: { nombre:'',descripcion:'',imagen_texto_alternativo:'' }, en: { nombre:'',descripcion:'',imagen_texto_alternativo:'' } }, imagen_principal:'',latitud:'',longitud:'',categoria_ids:[],duracion_estimada_minutos:'',atractivo_id:'',orden:1,kind }
}
export function contentPayload(form, kind) {
  const traducciones = { es: form.traducciones.es }
  const english = form.traducciones.en
  if (form.englishExists || english.nombre.trim() || english.descripcion.trim()) traducciones.en = english
  const result = { traducciones, imagen_principal: form.imagen_principal || null }
  if (kind === 'ruta') result.duracion_estimada_minutos = form.duracion_estimada_minutos === '' || form.duracion_estimada_minutos == null ? null : Number(form.duracion_estimada_minutos)
  else { result.latitud = form.latitud === '' || form.latitud == null ? null : Number(form.latitud); result.longitud = form.longitud === '' || form.longitud == null ? null : Number(form.longitud) }
  if (kind === 'atractivo') result.categoria_ids = form.categoria_ids
  if (kind === 'parada') { result.atractivo_id = form.atractivo_id || null; result.orden = Number(form.orden) }
  return result
}
