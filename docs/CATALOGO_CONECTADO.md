# Catálogo conectado a PostgreSQL

Entrega del 19 de noviembre de 2026. Se parte de `main` en `a3e605f636f7aa2d465122905e6efeb0bc1be73c`, que ya incluye la administración de atractivos, rutas y paradas publicada en `1123097`. Se retoma el pendiente descrito en el resumen del 30 de octubre: conectar las vistas públicas sin borrar la BD.

## Resultado

Inicio, Atractivos, fichas, Rutas y Mapas interactivos leen el mismo catálogo de PostgreSQL. Se eliminó la unión entre rutas de API y copias locales. Nombre, descripción, imagen existente, asociaciones, orden y coordenadas se obtienen de los registros reales. Una modificación de datos no exige recompilar el frontend; se consulta al entrar, volver, recargar o recuperar el foco. La actualización en segundo plano conserva la lectura mientras espera y retira el contenido si se confirma un error. No se implementa actualización continua por WebSocket.

El contenido nuevo o retirado a borrador no aparece públicamente. La vista previa del administrador permite comprobarlo sin publicarlo ni inventar datos para superar los requisitos. El cliente no decide sus permisos: `/api/admin/vista-previa/catalogo` comprueba la sesión y utiliza funciones administrativas que verifican el rol en BD. Un turista o visitante que copie esa URL recibe rechazo.

## BD y transacciones

Esta entrega no añade ni elimina tablas, columnas, claves, relaciones, funciones o privilegios. No cambia el ERD y no necesita SQL nuevo sobre la BD instalada. Reutiliza `listar_atractivos_publicados`, `listar_categorias_activas`, `listar_categorias_atractivo_publicado`, `listar_rutas_publicadas`, `listar_paradas_ruta_publicada` y los listados administrativos existentes.

El instalador completo y `actualizar_bd_contenidos.sql` permanecen sin cambios: el primero corresponde a una BD vacía y el segundo a la ampliación administrativa anterior. No reinstalar la BD. No se sustituyen cuentas, contraseñas, sesiones, UUID, contenidos, QR ni recorridos al aplicar el código.

Cada lectura compuesta usa una conexión y una transacción `REPEATABLE READ READ ONLY`, con límite de sentencia de diez segundos. Así un cambio concurrente no combina la ficha de una versión con las paradas de otra. Esto garantiza consistencia de la lectura; no constituye una medición del rendimiento del SLA. Las escrituras conservan las transacciones y bloqueos de la administración anterior.

Los valores siguen separados del SQL mediante parámetros `pg`. No se amplían privilegios de tabla al rol de conexión. La respuesta pública contiene solamente contenido publicado y categorías activas; no contiene cuentas, contraseñas, hashes ni tokens. CORS, sesión, autorización y restricciones SQL continúan siendo controles distintos.

## Endpoints y estructura

| Consulta | Uso |
| --- | --- |
| `GET /api/catalogo` | Atractivos publicados con categorías activas y rutas publicadas con sus paradas. |
| `GET /api/catalogo?idioma=en` | Traducciones existentes; no traduce toda la interfaz. |
| `GET /api/atractivos/:uuid` | Ficha publicada por identidad real. |
| `GET /api/admin/vista-previa/catalogo` | Catálogo de trabajo, con sesión administrativa. |
| `GET /api/rutas` y `/api/rutas/:uuid` | Se conservan los formatos de acceso usados por los recorridos. |
| `GET /api/salud` | Comprobación local de servicio/conexión sin token fijo. |

El catálogo completo se utiliza por simplicidad con el volumen de esta demostración. El listado público compone consultas SQL; no hace una petición HTTP separada por tarjeta. La vista previa consulta las asociaciones de cada ficha. Si el volumen crece, deben dimensionarse y validarse paginación, consultas por detalle y límites; no se promete capacidad de 205 usuarios por esta elección.

Los modelos de `src/services/catalogModel.js` validan IDs, duplicados, órdenes y GPS antes de dibujar. `useCatalog` cancela peticiones anteriores, separa vista pública y privada y descarta resultados al cambiar de cuenta o pantalla. No convierte una caída en una copia local aparentemente actual. `CatalogStatus` presenta carga, error y reintento.

## Cambios visibles

- Las categorías de atractivos se muestran por su nombre e icono y sirven como filtro. El código permanece como identificador interno.
- Las fichas muestran las rutas que realmente incluyen ese atractivo.
- Rutas conserva una presentación de itinerarios con su número real de paradas, duración registrada y acceso al mapa/inicio.
- Mapas interactivos lista las rutas publicadas o, en vista previa autorizada, las disponibles para administrar.
- Atractivos, rutas y paradas incorporan acceso a Vista previa/Ver ficha desde sus paneles.
- Las direcciones numéricas anteriores resuelven sus UUID iniciales. Un registro eliminado no se recrea por tener un nombre conocido.

Se mantiene el diseño y las imágenes ya existentes. No se agregaron mensajes de prototipo ni explicaciones técnicas a las pantallas del visitante.

## Ilustración y GPS

La ilustración del Casco Histórico se ofrece cuando coinciden sus doce UUID y su orden con el dibujo. Los textos y GPS proceden de BD. Si cambia el circuito, se conserva su lista y geografía reales y se omite el dibujo hasta revisar las asociaciones/trazado. Los píxeles no se convierten en GPS.

Con la semilla actual existen siete coordenadas cartográficas y cinco NULL. Los doce nombres aparecen en la lista, pero solo los siete puntos existentes se sitúan geográficamente. Las cinco aproximaciones antiguas no sustituyen un NULL. Una coordenada válida en formato no demuestra que el acceso al lugar esté comprobado en terreno.

## Arranque y publicación

`iniciar-demo.cmd` conserva las tres ventanas habituales. `iniciar-demo.ps1` comprueba salud y catálogo mediante Vite. Deja de renovar automáticamente la sesión de `demo.admin@example.invalid`: el login real de cada persona es independiente de aquel token. El renovador y diagnóstico antiguos se conservan para uso manual.

El lanzador público mantiene su flujo: main limpio y sincronizado, API local, túnel HTTPS, actualización de `public/demo-api.json` y espera de Pages. El nuevo bloqueo guarda PID e identidad de arranque, acepta el formato anterior y distingue un PID reutilizado. Retira archivos huérfanos sin terminar programas ajenos; no elimina el bloqueo de otra instancia al cerrar.

GitHub Actions fija Ubuntu 24.04 y Node 24. Usa acciones oficiales con commit completo verificado: checkout 7.0.1, setup-node 7.1.0, configure-pages 6.0.0, upload-pages-artifact 5.0.0 y deploy-pages 5.0.1. Ejecuta lint, pruebas de código y build antes de subir `dist`. La API maneja las desconexiones de clientes inactivos del pool sin terminar todo el proceso y vuelve a obtener conexión al consultar. Esto no reemplaza la recuperación de una caída total de BD. Node/Express y PostgreSQL no pasan a ejecutarse en GitHub Pages. No se ha disparado ni validado un despliegue remoto de este paquete.

Referencias oficiales consultadas el 19/11/2026: [checkout](https://github.com/actions/checkout/releases), [setup-node](https://github.com/actions/setup-node/releases), [configure-pages](https://github.com/actions/configure-pages/releases), [upload-pages-artifact](https://github.com/actions/upload-pages-artifact/releases) y [deploy-pages](https://github.com/actions/deploy-pages/releases). Se comprobaron además los tags mediante Git. Las mejoras de esas acciones no garantizan resolver cualquier demora de infraestructura.

## Aplicar el ZIP

1. Conservar el respaldo previo y detener API/FRONT/publicación. Mantener PostgreSQL disponible.
2. Extraer `casablanca_catalogo_conectado.zip` en Descargas y aplicar con `aplicar-catalogo.cmd`, o ejecutar el comando del LEEME del paquete indicando `casablanca_publicacion`.
3. El aplicador verifica la integridad y todos los archivos antes de reemplazar. Si encuentra cambios desconocidos, se detiene; no fusiona a ciegas. Guarda respaldo en `.respaldo-catalogo/<fecha>/`. No toca `.env`, la BD, `public/demo-api.json` ni Git.
4. Desde la raíz ejecutar `verificar-proyecto.cmd` y después `iniciar-demo.cmd`.
5. Entrar como administrador y revisar Vista previa. Completar y publicar el contenido que se quiera mostrar al visitante. Los registros iniciales no se publican automáticamente.
6. Probar y después publicar por Git: revisar archivos preparados, commit y push a main. Cuando la copia esté limpia y sincronizada, usar `iniciar-publicacion.cmd`.

Si los archivos del PC difieren de la base revisada, conservarlos y revisar el conflicto señalado. No reemplazar a mano `.env` ni ejecutar el instalador completo para resolver un conflicto de código.

## Comprobación manual en el PC

| Acción | Resultado esperado |
| --- | --- |
| Abrir borrador desde Vista previa como admin | Ficha visible con aviso privado; puede volver a Administración. |
| Abrir esa dirección sin sesión o como turista | La API rechaza el acceso y no entrega el borrador. |
| Publicar una ficha completa y abrir el catálogo público | Aparece una sola vez con UUID real. |
| Editar nombre, descripción o categoría y volver a la ficha | Aparecen los valores nuevos sin recompilar. |
| Pasar la ruta a borrador y consultar su URL pública | Deja de estar disponible; los recorridos existentes se conservan. |
| Cambiar orden o cantidad de paradas | La ficha/geografía muestran el orden real; se omite la ilustración incompatible. |
| Elegir una parada sin GPS | Aparece su detalle en la lista sin inventar posición. |
| Detener API o túnel y volver a consultar | Error con reintento; no se presenta la copia local como dato actual. |

Estas acciones constituyen la aceptación en tu instalación; no se registran como ejecutadas en tu PC por haber pasado en el entorno aislado.

## Restauración y alcance pendiente

Para recuperar código, cerrar servicios y restaurar el respaldo anterior o los archivos reemplazados del respaldo del aplicador. El registro de respaldo identifica también archivos añadidos; quitarlos si se desea volver exactamente a la versión de código anterior. Como no hay SQL nuevo, no se necesita una reversión de esquema. Restaurar el código no deshace ediciones de BD.

Continúan pendientes: correo real y recuperación de contraseña; subida/gestión de multimedia; validar coordenadas y contenidos; QR y progreso completo en interfaz; acreditación de finalización; descarga offline/cola local/sincronización; traducción integral; pruebas móviles, carga y seguridad/accesibilidad más amplias; operación persistente, supervisión y respaldos según acuerdos. Ninguna consulta offline ni selección de mapa acredita una visita. Otros módulos requieren alcance confirmado, sin añadir tablas por si acaso.
