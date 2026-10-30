# Ubicaciones del Casco Histórico

Investigación del 29/10/2026. El orden y las identidades proceden de las tres fotografías del folleto aportado. La ilustración es un esquema sin escala ni orientación geográfica uniforme: sus píxeles no se transforman directamente en GPS.

Se cruzó ese esquema con OpenStreetMap y documentación municipal/patrimonial. **No se realizó validación en terreno ni se certificó la precisión de acceso a cada inmueble.** Las siete referencias cartográficas identifican lugares; los centroides no representan necesariamente su puerta de entrada. Cinco sectores no pudieron asociarse de forma fiable a una puerta o inmueble exacto y se distinguen como aproximados.

| Nº | Parada | Latitud / longitud en la vista geográfica | Calidad y criterio |
| --- | --- | --- | --- |
| 1 | El Control | -33.3170602 / -71.4088361 | Referencia cartográfica: monolito del camino, OSM nodo 11596399847, junto a Constitución/Buin. |
| 2 | Plaza Bicentenario | -33.3182 / -71.4048 | **Aproximada**: sector Chacabuco/Chapito inferido del folleto. El acta municipal confirma la plaza en Chacabuco, no este punto exacto. |
| 3 | Casa Presidente Jorge Montt | -33.3195 / -71.4064 | **Aproximada**: sector de Chacabuco/Yungay inferido del folleto. Falta confirmar inmueble/numeración. |
| 4 | Casa Poeta Alejandro Galaz | -33.3216 / -71.4076 | **Aproximada**: Chacabuco entre Portales y Maipú, según el folleto. La historia municipal sobre el negocio familiar en Portales 341 no demuestra que sea esta casa. |
| 5 | Almacén Don Lalo | -33.321789 / -71.4076913 | Referencia cartográfica: OSM nodo 2630721529; comercio tradicional de Chacabuco también mencionado en fuentes municipales. |
| 6 | Casa Julio Montt Salamanca | -33.3217 / -71.4084 | **Aproximada**: tramo de Portales entre Membrillar y Chacabuco. Falta confirmar el edificio y acceso precisos. |
| 7 | Cooperativa Agrícola | -33.321371 / -71.4097634 | Referencia cartográfica: OSM nodo 2626982612; identificación patrimonial en Diego Portales. |
| 8 | Plaza de Armas | -33.32052365 / -71.41010835 | Referencia cartográfica: centro del polígono OSM 27654834. |
| 9 | 1.ª Compañía de Bomberos | -33.32035 / -71.4096 | **Aproximada**: antiguo cuartel en Maipú frente a Plaza de Armas, confirmado por noticia municipal. No confundir con el cuartel actual, alejado del circuito del folleto. |
| 10 | I. Municipalidad | -33.3197300133 / -71.4105246733 | Referencia cartográfica: edificio consistorial de Constitución 111, polígono OSM 282697152. |
| 11 | Parroquia Santa Bárbara | -33.3204394615 / -71.4108943538 | Referencia cartográfica: polígono OSM 132380618. |
| 12 | Centro Cultural y Museo | -33.3207206875 / -71.41119225 | Referencia cartográfica: Centro Cultural, polígono OSM 1233828224; conjunto de Portales 02. El Museo tiene punto propio contiguo. |

La carga inicial de BD incorpora **solo las siete referencias cartográficas**, sin tratar las otras cinco inferencias como coordenadas confirmadas. Las cinco quedan NULL y el administrador puede completarlas en el formulario. La vista de presentación sí muestra los doce números; las aproximaciones llevan texto y símbolo diferenciado. El círculo que aparece al seleccionar una aproximación es orientativo, no un margen de error medido ni una zona garantizada.

No se dibuja una línea GPS uniendo los puntos: una línea recta entre marcadores no demuestra que exista un itinerario peatonal transitable. El trazado del folleto permanece en la vista ilustrada. No se calculan distancias, tiempos, accesos, horarios o instrucciones de giro sin una fuente y validación adecuadas.

## Fuentes y comprobación

- [Datos cartográficos OpenStreetMap del centro de Casablanca](https://www.openstreetmap.org/api/0.6/map?bbox=-71.415,-33.326,-71.400,-33.316), consultados el 29/10/2026. [Licencia y atribución](https://www.openstreetmap.org/copyright). Los IDs indicados permiten volver a inspeccionar cada elemento.
- [Municipalidad: monolito de la Primera Compañía, 11/06/2025](https://municipalidadcasablanca.cl/index.php?Itemid=109&catid=8&id=1640%3Amunicipalidad-de-casablanca-instala-monolito-en-conmemoracion-de-los-76-anos-de-la-primera-compania-de-bomberos&option=com_content&view=article). Confirma el antiguo cuartel de Maipú frente a la plaza.
- [Acta municipal 628, 02/01/2007](https://ftptransp.municipalidadcasablanca.cl/Concejo%20Municipal/Actas/ACTAS%202007/ACTAS%20PDF/ACTA_628.pdf), pp. 11–12. Confirma referencia de Plaza Bicentenario en Chacabuco, sin una coordenada precisa.
- [Historia de Casablanca, Municipalidad](https://municipalidadcasablanca.cl/index.php?Itemid=117&id=4&option=com_content&view=article). Antecedentes de Alejandro Galaz y Julio Montt; no se usaron como prueba de una coordenada de vivienda.
- [Turismo Casablanca 2023, Municipalidad](https://municipalidadcasablanca.cl/phocadownload/Turismo/Turismo_Casablanca_2023.pdf). Referencias de lugares y servicios; no permite fijar por sí solo todas las puertas históricas.
- [Inventario de inmuebles y zonas de conservación histórica, MINVU](https://www.patrimoniourbano.gob.cl/inmuebles-y-zonas-patrimoniales/). Apoyo a la identificación de inmuebles de Portales. Una dirección de inventario sin nombre no se equiparó automáticamente con una casa del folleto.

Antes de activar el mapa desde BD: confirmar con Turismo o levantamiento en terreno las cinco referencias pendientes, verificar puertas/accesos de las demás y contrastar el circuito con la señalética actual. El administrador de contenido incorpora la corrección; quien valide la ubicación debe quedar registrado en la documentación del proyecto. No se inventa esa validación.
