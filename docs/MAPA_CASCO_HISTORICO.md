# Mapas de Casablanca y Casco Histórico

Actualización del 19/11/2026. El catálogo público, el detalle de ruta y sus mapas leen PostgreSQL a través de la API. Se conserva la ilustración anterior y su apariencia. Esta etapa sustituye las instrucciones de activar en el futuro el proveedor local.

## Funcionamiento actual

`#/mapas` lista las rutas disponibles y muestra su nombre, descripción y número real de paradas. El visitante ve rutas publicadas; el administrador puede abrir una vista previa privada de los borradores desde su panel. Cualquier ruta puede tener una vista geográfica; solo Casco dispone por ahora de ilustración propia.

`#/mapas/casco-historico` identifica el UUID inicial del circuito. Los textos, orden, asociaciones y GPS llegan del mismo catálogo que alimenta las fichas y los resúmenes. No se fusionan rutas por su nombre ni se agrega la antigua copia local. `#/mapas/rutas/:uuid` muestra el mapa de cualquier otra ruta. `#/mapas/atractivos/:uuid` muestra la ubicación del lugar correspondiente.

La selección utiliza el UUID de la parada y se conserva entre Ilustrado y Geográfico. Los parámetros antiguos con claves como `el_control` se resuelven mediante la asociación explícita. El punto seleccionado conserva su rojo `#c02026`; en Leaflet se dibuja por encima de los demás marcadores.

La semilla sigue incluyendo las doce paradas del folleto, pero solamente siete tienen GPS. La vista geográfica marca esas siete y conserva las doce entradas en la lista. Elegir una de las cinco sin GPS muestra su información y la ausencia de ubicación, sin inventar un marcador. Las aproximaciones históricas de `historicLocations.js` son antecedentes, no datos actuales sustitutos.

## Correspondencia de la ilustración

El SVG de `public/maps/casco-historico.svg` contiene fachadas, calles y vegetación. Las posiciones x/y y el trazado se mantienen manualmente; no son coordenadas geográficas. Los metadatos del dibujo están en `historicRoute.js` y los UUID asociados en `catalogBindings.js`.

La ilustración solo se ofrece si coinciden el UUID de la ruta, las doce paradas originales y sus órdenes. Cambiar nombres, descripciones, imágenes o GPS no mueve automáticamente las fachadas. Reordenar, añadir, eliminar o recrear una parada hace que el catálogo utilice la lista y geografía actuales sin presentar el trazado viejo como válido. Para recuperar la ilustración debe revisarse el dibujo, el camino y las asociaciones. No se genera automáticamente un nuevo mapa artístico.

Las etiquetas de tipo y símbolos del dibujo son recursos de presentación. No crean categorías ni sustituyen las asociaciones entre atractivo y categoría guardadas en PostgreSQL.

## Componentes

| Archivo | Responsabilidad |
| --- | --- |
| `backend/catalogo.cjs` | Lectura pública y vista previa autorizada mediante funciones SQL existentes. |
| `src/hooks/useCatalog.js` | Consulta cancelable; estados de carga/error y actualización al volver a la pestaña. |
| `src/services/catalogModel.js` | Identidades, normalización, GPS, comprobación del dibujo y enlaces. |
| `src/data/catalogBindings.js` | UUID y compatibilidad de enlaces anteriores. |
| `HistoricMap.jsx` | Ilustración, selección, lista, teclado, arrastre y zoom. |
| `GeographicMap.jsx` | Coordenadas de BD sobre Leaflet, lista y detalle de paradas. |
| `MapPage.jsx` | Tipo de mapa y selección conservada en URL. |
| `InteractiveMaps.jsx` | Mapas de las rutas disponibles. |
| `AttractionMap.jsx` | Mapa individual de un atractivo. |

`historicRouteRepository.js` conserva el adaptador estricto como utilidad de compatibilidad y su exportación activa apunta a la API. Las pantallas actuales utilizan `useCatalog` para compartir el contrato del catálogo completo; no dependen de activar ese adaptador manualmente. El proveedor local permanece como fixture de pruebas, no como respaldo silencioso ante una caída.

## Enlaces y permisos

Las fichas de atractivos enlazan con rutas que realmente los incluyen. Una parada puede existir sin atractivo; se presenta igualmente. Las relaciones llegan por UUID. Los enlaces `/routes/catalogo/1`, `/2`, `/3` se redirigen a las fichas reales. `#/map?lugar=4` abre la Biblioteca por su UUID; el enlace antiguo general `#/map` conserva acceso al circuito del Casco.

Consultar y seleccionar una parada no inicia un recorrido ni acredita una visita. Iniciar un recorrido requiere una cuenta habilitada y confirmación. Vista previa no inicia recorridos. El backend y la BD siguen aplicando los permisos y las reglas de conservación.

## Dependencias y límites

Leaflet se carga cuando se abre un mapa geográfico. El fondo utiliza teselas de OpenStreetMap y conserva su atribución. Si falla el fondo, la lista sigue disponible. No se descargan masivamente teselas ni se instala un mapa offline.

Si la API o el túnel fallan, se muestra un estado de error y Reintentar. El catálogo no se reconstruye desde los textos antiguos del frontend. Una pantalla ya cargada puede conservar su última lectura durante una actualización en curso; un fallo confirmado no se presenta como información actualizada. No hay caché persistente offline ni cola QR.

No se añadieron navegación giro a giro, ubicación del visitante, medición de distancias, tiempos verificados, nuevos contenidos históricos, subida de imágenes ni confirmación de coordenadas en terreno. Los pendientes y fuentes cartográficas siguen en [UBICACIONES_CASCO_HISTORICO.md](UBICACIONES_CASCO_HISTORICO.md).

## Verificación

Las pruebas de esta etapa están en [RESULTADOS_CATALOGO_CONECTADO.md](RESULTADOS_CATALOGO_CONECTADO.md). Se comprobaron con BD real y en navegador la consulta del circuito, selección, enlaces y ausencia de GPS inventado. Las campañas anteriores de 29 y 30 de octubre permanecen registradas en sus documentos y no se contabilizan como nuevas revisiones móviles de esta entrega.
