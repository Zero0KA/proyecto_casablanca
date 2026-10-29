# Mapa interactivo del Casco Histórico

Actualización: 29 de octubre de 2026. Integración sobre `origin/main`, commit `e2c72ac`.

## Qué se implementó

La sección Mapa abre un circuito ilustrado basado en las tres fotografías del folleto aportado. Tiene doce marcadores numerados, selección mediante mapa o lista, ficha de parada, anterior/siguiente, acercamiento, alejamiento, arrastre, gesto de dos dedos y vista completa. La selección se conserva en la URL. Se puede mostrar u ocultar el trazado.

Se conserva la vista geográfica anterior con Leaflet y OpenStreetMap. El enlace antiguo `#/map?lugar=4` sigue abriendo Biblioteca. No se añadieron coordenadas para los otros lugares.

La ficha `#/routes/catalogo/2` ahora muestra las doce paradas y enlaza cada una con el mapa. Los resúmenes de Inicio y Rutas indican doce paradas. Las fichas existentes de Plaza de Armas, Parroquia, Centro Cultural y Museo enlazan con su parada. No se inventaron fichas de atractivo para las demás casas: una parada de ruta puede existir sin un atractivo asociado.

Orden transcrito del folleto:

1. El Control.
2. Plaza Bicentenario.
3. Casa Presidente Jorge Montt.
4. Casa Poeta Alejandro Galaz.
5. Almacén Don Lalo.
6. Casa Julio Montt Salamanca.
7. Cooperativa Agrícola.
8. Plaza de Armas.
9. 1.ª Compañía de Bomberos.
10. I. Municipalidad de Casablanca.
11. Parroquia Santa Bárbara.
12. Centro Cultural y Museo.

## Documentación considerada

- Formulación del proyecto, evaluación 1: solicita un mapa interactivo derivado del mapa ilustrativo existente y contempla el circuito del Casco Histórico.
- Informe de la segunda unidad, versión disponible de 52 páginas: arquitectura, permisos, calidad, disponibilidad y continuidad. Lo planificado no se considera automáticamente implementado.
- `documentacion_casablanca_mapa_interfaz_rutas_categorias`: distingue el catálogo local de las rutas publicadas con UUID y conserva Biblioteca como único punto geográfico aportado.
- Documentación de registro, sesiones e integración, y de túnel y GitHub Pages: se conserva el transporte de API, las sesiones y los controles de acceso.
- Código actual de `backend/turismo.cjs` e instalador SQL disponible: se verificaron las funciones públicas de rutas y los campos de sus paradas.
- Las tres fotografías aportadas en esta solicitud: referencia del orden, trazado, calles y aspecto del circuito.

La ilustración es una reconstrucción vectorial del esquema, no una digitalización exacta ni un plano a escala. Los nombres y el orden provienen del folleto; las descripciones son breves y no añaden fechas ni relatos históricos sin una fuente. No se incorporaron servicios comerciales, horarios o información de accesibilidad que no estuvieran verificados.

## Organización y conexión futura a la BD

| Archivo | Responsabilidad |
| --- | --- |
| `public/maps/casco-historico.svg` | Ilustración vectorial, fachadas, calles y vegetación. Sin coordenadas GPS. |
| `src/data/historicRoute.js` | Una definición del circuito: nombres, orden, claves locales, puntos del dibujo y trazado. |
| `src/services/historicRouteRepository.js` | Proveedor local activo y adaptador preparado para la API existente. |
| `src/hooks/useHistoricRoute.js` | Carga cancelable compartida por mapa e itinerario del Casco Histórico. |
| `src/components/HistoricMap.jsx` y su CSS | Interacción, selección, gestos, teclado, leyenda y lista. |
| `src/components/GeographicMap.jsx` | Vista Leaflet anterior, separada de la ilustración. |
| `src/pages/MapPage.jsx` | URL, elección de vista y carga del mapa. |
| `src/pages/CatalogRoute.jsx` | Itinerario y enlaces a las paradas. |
| `tests/historic-route.test.mjs` | Comprobaciones del contrato de datos y del adaptador. |

Cada parada tiene una `key` local estable, `order`, `position: { x, y }` en el dibujo, `databaseId: null` y `coordinates: null`. `attractionId`, cuando existe, identifica exclusivamente una ficha numérica del catálogo local. Estos números no son UUID de PostgreSQL.

`kind` y `symbol` son etiquetas e ilustraciones del catálogo local. No crean categorías en la BD ni sustituyen la relación `atractivo_categoria` o el CRUD de categorías existente.

Las tablas actuales ya separan `ruta`, `ruta_parada`, sus traducciones y el atractivo opcional. `ruta_parada.ubicacion` es `geometry(Point,4326)`: X es longitud e Y latitud. Las posiciones del dibujo jamás se guardan en ese campo. Esta entrega no requiere cambiar tablas, relaciones, funciones SQL ni el diagrama de datos.

El backend ya ofrece `GET /rutas/:uuid`, que devuelve `{ ruta, paradas }` mediante `listar_rutas_publicadas` y `listar_paradas_ruta_publicada`. El adaptador usa esa respuesta; no se creó una API alternativa ni se necesita acceso directo del navegador a PostgreSQL.

Para activar la lectura desde BD más adelante:

1. Preparar y publicar la ruta real y sus doce paradas mediante el flujo administrativo autorizado. Confirmar textos, orden e identidades. Esta entrega no ejecuta una carga SQL.
2. Obtener el UUID de la ruta y de cada parada. Asociar expresamente cada UUID con su clave del dibujo; no buscar coincidencias por nombre ni confundir UUID de atractivo con UUID de parada.
3. En `historicRouteRepository.js`, importar `apiFetch` de `../components/SessionContext` y sustituir únicamente la exportación del proveedor local por el adaptador:

```js
export const historicRouteRepository = createApiHistoricRouteRepository({
  routeId: uuidRealDeLaRuta,
  stopBindings: asociacionesUuidDeParadaAClaveLocal,
  fetchRoute: apiFetch,
})
```

`asociacionesUuidDeParadaAClaveLocal` es un objeto con doce entradas: el UUID real de cada parada como clave y, por ejemplo, `el_control` como valor. Las doce claves están en `historicRoute.js`. Los identificadores son públicos; las credenciales y tokens permanecen en su flujo actual.

El mapa y el itinerario pasarán a leer los nombres y descripciones de esa API. El adaptador valida ruta, asociaciones, orden, duplicados y rangos de coordenadas. Rechaza discrepancias para evitar dibujar una parada sobre otra. Si cambia el número u orden real del circuito, se debe revisar también el dibujo y el trazado. No sustituye un error de API por datos locales haciéndolos pasar por datos de BD.

Los resúmenes de Inicio/Rutas y las fichas de atractivos continúan usando el catálogo local existente. Centralizar también ese catálogo completo será un paso posterior; activar este adaptador no convierte toda la aplicación en contenido administrado desde BD.

## Comportamiento, permisos y límites

- Consultar el mapa es público. Cambiar la selección no inicia un recorrido, no acredita visitas y no envía escrituras a la API.
- Las rutas reales con UUID conservan el flujo existente de inicio con sesión. No se simula un UUID ni un registro de progreso para este circuito local.
- No se modificaron el login, los roles, el CRUD de categorías, las funciones de PostgreSQL, el backend, `.env`, el transporte del túnel ni el lanzador de publicación.
- La ilustración y sus datos se sirven con el frontend. No necesitan teselas ni la API para ser consultados después de cargar la página. Esto no implementa descarga offline ni garantiza abrir la aplicación sin conexión.
- La vista geográfica conserva sus dependencias externas y la atribución a OpenStreetMap. Una caída de teselas muestra el aviso y conserva la lista de lugares.
- No hay geolocalización del visitante, navegación GPS, estimación de distancia/tiempo ni acreditación de visitas. Tampoco se implementan aquí QR ni sincronización.
- Las coordenadas existentes de Biblioteca siguen pendientes de validación para uso real, como indicaba la documentación previa.
- Hay controles por teclado y áreas táctiles ampliadas en pantallas pequeñas. La revisión automática de accesibilidad complementa la revisión visual; no constituye certificación.

## Instalación y revisión local

El paquete de integración incorpora un aplicador con verificación de archivos y respaldo. No agrega dependencias: usa las versiones de React y Leaflet ya presentes.

Después de aplicar el paquete, en la raíz de `casablanca_publicacion`:

```powershell
npm.cmd run build
npm.cmd run lint
node --test tests/historic-route.test.mjs
```

Para verlo localmente, usar `iniciar-demo.cmd` como antes o el frontend ya abierto. Abrir la dirección que Vite muestre y añadir `#/map`. La ficha completa está en `#/routes/catalogo/2`. No es necesario iniciar un túnel para desarrollar el dibujo.

Publicar sigue siendo un paso separado: revisar cambios, comprobar build/lint y usar el procedimiento Git del proyecto. El aplicador no hace commit, push ni inicia el túnel.

## Resultado de verificación

El 29/10/2026 pasaron la compilación de producción y ESLint, 19 pruebas del catálogo/adaptador y 43 comprobaciones en Chromium con API simulada. Se revisaron selección, enlaces, lista e itinerario, teclado, arrastre, zoom, gesto de dos dedos, fallos de imagen/teselas, recuperación y navegación de visitante, turista y administrador. No se observaron errores JavaScript.

La revisión responsive cubrió anchos de 320, 390, 768, 1024 y 1440 píxeles, sin desborde horizontal del mapa. Se comprobó un área táctil de al menos 44 píxeles en los marcadores móviles. La auditoría automática seleccionada de reglas WCAG A/AA no detectó infracciones en la vista ilustrada tras ajustar el contraste. Se revisaron visualmente las capturas de computador y móvil.

Estas pruebas no son una medición de carga del SLA, una validación cartográfica en terreno ni una prueba contra el PostgreSQL del PC. El adaptador se verificó con el formato real del endpoint y respuestas de prueba; activar y validar la lectura de los UUID reales sigue siendo un paso posterior.
