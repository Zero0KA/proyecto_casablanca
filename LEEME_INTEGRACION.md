# Ejecución de Casablanca

Actualización del 19/11/2026. La carpeta de trabajo es `casablanca_publicacion`. El frontend sigue en React/Vite y GitHub Pages; la API Node/Express y PostgreSQL/PostGIS siguen en el PC durante las presentaciones.

## Requisitos y configuración privada

Se mantienen Node.js, PostgreSQL/PostGIS, Git, GitHub CLI y cloudflared. La conexión vigente sigue en `backend/.env`; conservarla de forma privada. No copiarla a `public/`, no subirla a GitHub ni reemplazarla al aplicar un parche. El proyecto no incluye la BD dentro de su carpeta.

En una copia nueva se instalan las dependencias con `npm.cmd ci` en la raíz y `npm.cmd ci` dentro de backend. Esta entrega no añade dependencias ni cambia los archivos package-lock. La ampliación administrativa anterior debe estar instalada en la BD; no ejecutar el instalador completo sobre la BD existente.

## Comprobar y arrancar localmente

1. Detener el lanzador público y las APIs anteriores con Ctrl+C. Mantener PostgreSQL activo.
2. Ejecutar `verificar-proyecto.cmd` desde la raíz. Ejecuta lint, pruebas de código y compilación; se detiene si falla un paso. No realiza escrituras en PostgreSQL.
3. Ejecutar `iniciar-demo.cmd`. Abre API, FRONT y la ventana COMANDOS con la estructura habitual. Mantener API y FRONT abiertas.

El arranque local consulta `/api/salud` y comprueba el catálogo a través del proxy de Vite. Ya no llama automáticamente a `renovar-demo.cjs`, no necesita `DEMO_ADMIN_TOKEN` y no crea sesiones. Cada persona inicia sesión desde la web. El diagnóstico histórico `/api/estado` y el renovador se conservan para uso manual, pero no autorizan este catálogo ni sus paneles.

La dirección local conserva `/proyecto_casablanca/` y el puerto que muestre Vite. El lanzador elige uno libre entre 5173 y 5193. La API utiliza 3001. Para comandos manuales: FRONT ejecuta Vite, API ejecuta Node en backend y COMANDOS recibe pruebas/Git. No detener API para enviar una petición desde esa misma terminal.

## Contenido y cuentas

Un visitante puede consultar contenido publicado. Una cuenta habilitada puede iniciar su propio recorrido, consultarlo y abandonarlo. El administrador conserva esas funciones y administra cuentas, categorías, atractivos, rutas y paradas. El rol se comprueba en el servidor y en las funciones SQL; un parámetro de URL no otorga permisos.

El registro sigue creando cuentas pendientes. La habilitación manual mantiene su configuración opcional; no comprueba la propiedad real del correo. No se crean cuentas ni se cambian contraseñas al aplicar esta entrega.

La carga inicial continúa siendo una acción confirmada del administrador. Incorpora seis atractivos, tres rutas y catorce paradas como borradores. Conserva las ediciones existentes. No se ejecuta al abrir el sitio ni al aplicar el ZIP.

**Si no aparecen rutas al visitante, revisar su estado en Administración.** Vista previa permite comprobar borradores desde la cuenta administradora. Para hacerlos públicos se completan los requisitos existentes y se pulsa Publicar. El Teatro de la semilla no tiene GPS; las rutas iniciales no tienen duración definida. No se rellenan automáticamente datos desconocidos para forzar la publicación.

Las ediciones de BD se reflejan al entrar o volver a la pantalla, recargar o recuperar el foco de la pestaña. No requieren recompilar ni subir el código. No hay actualización mediante WebSocket ni funcionamiento offline persistente.

## Mapas

`#/mapas` lista las rutas disponibles y abre su mapa geográfico. El Casco Histórico conserva su ilustración cuando coinciden sus doce UUID y su orden. Las fichas y mapas leen textos, asociaciones y coordenadas de BD. Si una parada carece de GPS, permanece en la lista, sin marcador inventado.

Reordenar, añadir, eliminar o recrear una parada puede invalidar la correspondencia del dibujo. En ese caso se ofrece el mapa geográfico y la lista real; revisar manualmente la ilustración y sus asociaciones antes de habilitarla de nuevo. No se genera una ilustración automática ni una línea de navegación GPS.

Las direcciones anteriores de fichas numéricas y `routes/catalogo/1`, `2`, `3` resuelven los UUID originales. Si ese registro ya no existe o no está publicado, no se reconstruye una copia local. `#/map?lugar=4` abre la Biblioteca por su UUID y sus coordenadas actuales.

## Publicación mediante GitHub Pages

Primero probar localmente. Después, en COMANDOS, revisar `git status --short`, preparar los archivos del proyecto, hacer commit y `git push origin main`. La configuración privada, los respaldos y las salidas locales de pruebas están excluidos. Comprobar los archivos preparados antes de confirmar.

`iniciar-publicacion.cmd` exige rama main, ausencia de cambios sin guardar y coincidencia con origin/main. Inicia API y túnel, actualiza solo la conexión pública de `public/demo-api.json`, hace su commit/push y espera Pages. No publica automáticamente los demás archivos. Conservar PC, PostgreSQL, API, Internet y túnel activos; Ctrl+C detiene la presentación.

El bloqueo del lanzador ahora comprueba PID e identidad de arranque; reconoce archivos huérfanos y no termina otros programas. En Windows usa información de procesos mediante PowerShell. Si una instancia real sigue activa, la respeta.

El workflow fija Ubuntu 24.04, Node 24 y acciones oficiales identificadas por commit. Ejecuta lint, pruebas y build antes de desplegar `dist`. No instala PostgreSQL en Pages ni publica el backend como servicio. La actualización del workflow no garantiza eliminar demoras o incidencias externas de Actions.

## Restauración y límites

El aplicador deja copias en `.respaldo-catalogo/<fecha>/`. El respaldo de código y el respaldo PostgreSQL son distintos. Restaurar archivos no revierte datos editados desde la web. La BD actual se conserva y no se ejecuta SQL nuevo por este cambio.

Las operaciones administrativas compuestas mantienen transacciones y controles de historial. Una ruta con recorridos se archiva; no se borra para reiniciarla. El contenido público no contiene cuentas ni secretos de sesión.

El sitio sigue necesitando correo real y recuperación de contraseña, subida de imágenes, validación de coordenadas y contenido, flujo QR completo en la interfaz, offline/sincronización, pruebas móviles e integrales adicionales, carga y operación permanente según alcance. El mapa visible o una consulta sin conexión no acreditan una visita.

Procedimiento y pruebas detallados: [CATALOGO_CONECTADO.md](docs/CATALOGO_CONECTADO.md) y [RESULTADOS_CATALOGO_CONECTADO.md](docs/RESULTADOS_CATALOGO_CONECTADO.md).
