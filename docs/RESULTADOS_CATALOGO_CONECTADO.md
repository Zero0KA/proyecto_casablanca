# Resultados del catálogo conectado

Campaña del 19/11/2026 sobre la actualización preparada desde main `a3e605f`. Las pruebas se ejecutaron sobre copias y BD temporales. No se conectó con la BD del PC de Zero ni se abrió un túnel público real para esta entrega.

## Resultados finales

| Comprobación | Resultado |
| --- | --- |
| Pruebas de código | 73 correctas, cero fallos: 38 anteriores, 25 del catálogo y 10 del bloqueo. |
| Regresión API y BD reales | 27 grupos correctos: roles, CRUD, rollback, publicación, QR, historial y concurrencia. |
| Integración del catálogo con BD real | 24 grupos correctos: login, publicación, filtros, edición, retiro, privacidad, lectura consistente y recuperación de conexiones. |
| Aplicador del paquete | 9 grupos correctos: respaldo, integridad, idempotencia, conflictos, BOM/CRLF, enlaces simbólicos y restauración tras fallo. |
| Navegador | Revisión de pantallas públicas y controles con API/BD reales, descrita abajo. |
| Lint y compilación | Correctos. Código de mapas dividido en cargas diferidas. |

Entorno: Node 24.22.3, PostgreSQL 17.11 y PostGIS 3.5.2, sobre Linux. La instalación del usuario y su entorno Windows requieren la comprobación de aceptación indicada en el LEEME. No se atribuye esta campaña a PostgreSQL 18 ni al PC del usuario.

## Cobertura funcional real

La campaña de regresión repitió el CRUD administrativo, errores de validación y transacciones que revierten una operación incompleta. Comprobó la protección de QR/paradas de recorridos abiertos, el historial conservado al cerrar, el rechazo de borrado de rutas con historial, las categorías y la espera a bloqueos.

La campaña nueva comprobó BD vacía sin catálogo ficticio; carga inicial privada; rechazo de visitante y turista en vista previa; login Argon2 de cuenta temporal; requisitos existentes de publicación; cinco atractivos y tres rutas publicados sin duplicados; doce paradas de Casco con siete GPS y cinco NULL; compatibilidad de endpoints; edición de nombre/categoría; desactivación de categoría; y texto con sintaxis SQL guardado literalmente.

También comprobó retiro de una ruta sin perder el recorrido de la persona, edición de GPS y orden, conservación del orden histórico, lecturas REPEATABLE READ ante una edición concurrente y borrado real sin reconstruir la copia local. La respuesta pública no contiene datos de cuentas ni secretos. Se verificó el modo de publicación con Bearer y origen permitido, sin abrir un túnel de Cloudflare real.

Se terminó expresamente una conexión inactiva de la API mediante PostgreSQL. Sin manejo del evento de pool la prueba reprodujo una interrupción del proceso; después del ajuste la API permaneció activa y pudo abrir otra conexión. Esto no sustituye una prueba de caída total o restauración del servidor.

## Revisión en navegador

Con una BD aislada y contenido de prueba publicado se revisaron Inicio, cinco atractivos, filtro de categoría, búsqueda de un resultado, cero resultados y limpieza. La ficha de Plaza mostró sus dos rutas asociadas. Casco presentó las doce paradas con enlaces UUID. La dirección antigua del catálogo resolvió la ficha real y el inicio sin cuenta condujo al formulario de login.

La vista previa sin sesión rechazó el acceso sin mostrar borradores. Mapas interactivos mostró tres rutas. El enlace antiguo de Biblioteca resolvió el UUID correcto. Se revisaron las dos vistas del Casco, selección conservada y GPS ausente. El geográfico cargó el fondo y siete marcadores; la lista mantuvo las doce paradas. Se midieron doce puntos ilustrados, selección `rgb(192, 32, 38)` y ausencia de desborde horizontal en 1348 px.

Durante la revisión se corrigieron una advertencia por prop key propagada, el vaciado visual al recuperar el foco, un enlace duplicado al detalle y el mensaje de red genérico en inglés. La actualización en curso conserva la lectura existente; el error confirmado retira el catálogo y permite reintentar.

La revisión de navegador de esta entrega fue como visitante. Las operaciones autenticadas y el login se verificaron mediante API/BD, no introduciendo credenciales personales del usuario en el navegador. No es una nueva campaña móvil completa ni una certificación WCAG. Las pruebas móviles previas siguen siendo antecedentes.

## Aplicador y reproducción

Se aplicó el paquete sobre archivos de la base Git y se compararon los bytes con el contenido entregado. Se verificaron respaldo de originales, `.env` intacto, segunda ejecución sin cambios, tolerancia de BOM/CRLF, rechazo previo de trabajo local desconocido y de archivos nuevos en conflicto. Un payload alterado y una ruta de escape se rechazaron. Un fallo de escritura simulado a mitad de la aplicación restauró los archivos ya reemplazados. No se ejecutaron Git, SQL ni un túnel desde el aplicador.

Comprobación habitual en la raíz:

```powershell
npm.cmd run lint
node --test tests/*.test.mjs
npm.cmd run build
```

`verificar-proyecto.cmd` agrupa esos pasos y no escribe en BD. Las pruebas reales son opcionales y requieren CASABLANCA_PRUEBAS=SI y conexión PostgreSQL administrativa mediante variables PG; crean y eliminan una BD/rol temporales propios:

```powershell
node tests/integracion-api.cjs
node tests/integracion-catalogo.cjs
```

No utilizan casablanca como BD de destino. Las cuentas y duraciones de esos ensayos son fixtures, no población nueva de la aplicación. No ejecutar contra una infraestructura ajena ni atribuir sus datos sintéticos a información turística validada.

Evidencias: `docs/evidencias/catalogo-integracion.json`, `catalogo-regresion-api.json`, `catalogo-navegador.json` y `catalogo-aplicador.json`. Se preservan las evidencias de octubre por separado.

## Límites de validación

No se ha ejecutado el workflow remoto, publicado el ZIP en GitHub, modificado la instalación del usuario ni verificado el túnel real con esta versión. Las acciones y sus tags se contrastaron con sus fuentes oficiales; el despliegue final continúa siendo un paso del usuario.

La rama Windows del control de procesos y los lanzadores CMD/PowerShell requieren aceptación en el PC. La lógica del bloqueo se comprobó con casos modelados y una identidad nativa Linux. No se realizaron pruebas de 205 usuarios, SLA, penetración integral, lector de pantalla, cámara/QR en teléfonos, offline/sincronización ni validación de GPS en terreno.
