# Resultados de la actualización de contenido

Fecha: 30/10/2026. Código base publicado: `4053285`. Entorno de prueba: Node 24.22.1, PostgreSQL **16.15**, PostGIS **3.4.2**, Chromium y axe-core. El instalador del proyecto está orientado a PostgreSQL 18/PostGIS; la ejecución y aceptación final en esa versión y en el PC del usuario siguen siendo la comprobación local. No se accedió al PostgreSQL del PC ni se publicó en GitHub.

## Resultado final

| Verificación | Resultado |
| --- | --- |
| Compilación de producción | Correcta. Vite avisa de un bloque JS de unos 504 kB sin comprimir (unos 152 kB gzip); no impide compilar. Separar cargas y optimizar fotografías sigue pendiente de una revisión de rendimiento. |
| ESLint | Correcto, sin errores del código. |
| Tests Node | **38/38**: catálogo, validación, asociación de UUID, cancelación, coordenadas y errores del adaptador. |
| SQL transaccional | **17/17**, cero diferencias. `ROLLBACK` confirmado y conteos de usuarios/rutas iguales a los iniciales. |
| Integración API + PostgreSQL/PostGIS reales | **27 grupos correctos**. El instalador completo funcionó en una BD vacía; la migración también se aplicó sobre la base del instalador anterior y se volvió a ejecutar sin perder usuarios, sesiones o contenido. |
| Navegador con API y BD reales | **17 grupos correctos**: login, permisos, CRUD, orden de paradas y mapas. |
| Aplicador del paquete | Correcto: coincidencia de hashes, respaldo, preservación de `.env`, segunda aplicación sin cambios, CRLF/BOM, rechazo de conflictos y restauración tras fallo de escritura. |
| Accesibilidad automática seleccionada | Sin infracciones detectadas en las reglas WCAG A/AA revisadas para listado administrativo, formulario bilingüe y vista geográfica. No equivale a certificación. |

Las agrupaciones de integración y navegador contienen varias aserciones; no se presentan como 27 o 17 clics ni como una prueba exhaustiva de todas las combinaciones posibles. Las evidencias, sin credenciales, están en `docs/evidencias/admin-api.json`, `admin-navegador.json` y `admin-sql.json`.

## Qué se comprobó

La carga inicial creó exactamente seis atractivos, tres rutas y catorce paradas. Una segunda carga creó cero duplicados. Se conservaron las ediciones realizadas antes de repetirla. Las rutas quedaron en borrador y sin una duración inventada. Casco conservó las doce paradas y el orden del folleto.

Las solicitudes sin sesión, con cuenta turista o con origen ajeno fueron rechazadas. El rol de conexión API no pudo insertar directamente en las tablas ni leer la tabla de sesiones. En modo público funcionaron Bearer, autorización administrativa y preflight para PUT desde el origen autorizado. No se abrió un túnel real para esta verificación.

Se probaron crear, editar, publicar, retirar, archivar y eliminar con funciones reales. La publicación incompleta falló. Una asociación de categoría inválida, detectada después de crear el atractivo y sus textos, revirtió toda la operación. Un texto con sintaxis de inyección SQL se almacenó literalmente y no alteró las tablas. Se rechazaron coordenadas fuera de rango/incompletas, campos extra, UUID de tipo incorrecto, textos vacíos y referencias de imagen no admitidas.

La reordenación conservó posiciones consecutivas, rechazó IDs repetidos o incompletos y no permitió editar una parada a través de la URL de otra ruta. Una operación concurrente esperó al bloqueo de la fila y continuó tras liberarlo.

Un atractivo asociado no pudo eliminarse. Una ruta publicada no pudo eliminarse. El borrado de una ruta sin historial limpió paradas, traducciones y QR. Un recorrido abierto impidió borrar su parada; después de abandonarlo, el borrado conservó el paso con origen NULL. La ruta con historial continuó protegida y pudo archivarse.

Desde el navegador se crearon, editaron y eliminaron atractivos; se creó una parada intermedia, se movió y se eliminó conservando el orden. El login de admin volvió al panel solicitado. Al cerrar sesión y entrar como turista no apareció Administración y la URL administrativa volvió al perfil.

Se revisaron selección ilustrada y geográfica, doce marcadores, conservación de la parada al cambiar de vista, rojo de selección, aproximaciones visibles y redirección de enlaces antiguos. La revisión responsive del mapa cubrió 320, 390, 768, 1024 y 1440 px. La tabla administrativa desplaza su propio contenido en móvil sin desbordar la página. Se inspeccionaron capturas de computador y móvil. No se observaron errores JavaScript en esos recorridos.

La comprobación adicional del fondo cargó al menos 20 teselas reales de OpenStreetMap con respuesta HTTP 200. Se verificó también la lista disponible cuando falla el fondo. La sesión automatizada adicional usó una excepción de certificado para el proxy del entorno de prueba; no se cambió la aplicación ni se propone desactivar esa validación en el PC. Esta verificación de carga no certifica HTTPS de producción ni garantiza disponibilidad del proveedor. Las paradas próximas pueden superponerse al alejar el mapa; la selección se muestra por delante y también se puede elegir desde la lista.

## Fallos detectados y corregidos antes de cerrar

- El instalador recibido contenía preparación de cuentas que exigía datos de demo y cambiaba contraseñas. Se excluyó del instalador actualizado; la migración no la ejecuta.
- Las validaciones diferidas de publicación fallaban al COMMIT con el rol API limitado. Se les dio propietario interno NOLOGIN y SECURITY DEFINER con ruta de búsqueda fija, manteniendo al backend sin escritura directa.
- La carga con UUID fijos necesitaba permisos INSERT específicos de columnas para el propietario interno. Se ajustaron sin otorgarlos al rol API.
- Se reforzó la validación de UUID para rechazar arreglos que JavaScript podía convertir implícitamente a texto.
- Al editar una traducción inglesa existente no se permite vaciarla aparentando que se eliminó: debe mantenerse completa. Cambiar entre paneles o rutas reinicia su formulario.

## Repetir las pruebas

Pruebas rápidas, desde la raíz, con las dependencias instaladas:

```powershell
npm.cmd run build
npm.cmd run lint
node --test tests/*.test.mjs
```

Prueba SQL adicional: abrir **`tests/pruebas_contenidos.sql`** en pgAdmin como postgres y ejecutar TODO. Finaliza en ROLLBACK; el resultado esperado es 17 correctos y cero diferencias. Si se interrumpe por un error inesperado, ejecutar ROLLBACK. Los resultados están comentados al final del archivo. Las pruebas anteriores de población caótica permanecen como antecedentes separados.

La suite completa de API es opcional para repetir la verificación técnica. `tests/integracion-api.cjs` crea su propia BD `casablanca_pruebas_<identificador>` y un rol temporal; los elimina al terminar. No usa `casablanca` como destino ni carga el `.env` del backend para obtener la conexión administrativa. Requiere PostgreSQL con PostGIS instalado y una conexión administrativa mediante las variables PGHOST, PGPORT, PGUSER y PGPASSWORD de la terminal de pruebas. No guardar esas credenciales en archivos del repositorio ni mostrarlas en capturas.

```powershell
$env:CASABLANCA_PRUEBAS = 'SI'
node tests/integracion-api.cjs
Remove-Item Env:CASABLANCA_PRUEBAS
```

La autorización explícita de pruebas evita iniciarla accidentalmente. La suite levanta APIs de prueba solo en loopback, puertos 13011 y 13012. No modifica las APIs de 3001 ni los lanzadores. Si falta permiso para crear la BD/rol, se detiene. Su reporte local `tests/resultado-api.json` está excluido de Git; revisar y trasladar solo la evidencia sin secretos si se necesita documentar otra ejecución.

## Límites de esta aceptación

No se midió la carga de 205 usuarios del SLA, penetración completa, producción, envío real de correo, QR en frontend, subida de imágenes, navegación GPS, offline ni sincronización. No se validaron ubicaciones en terreno. Cinco referencias del mapa siguen siendo aproximadas y no se cargan como GPS confirmado en BD.

La unificación de todas las vistas públicas con PostgreSQL quedó fuera: el panel administrativo guarda datos reales y las rutas publicadas usan su API existente; el catálogo local y los mapas de presentación no reflejan automáticamente esas ediciones. Los UUID preparados facilitan la conexión posterior, pero no se activó implícitamente.
