# Casablanca integrado

Actualización: 30/10/2026. Frontend React/Vite, API Node/Express y PostgreSQL/PostGIS. Se conserva el diseño de la página y se incorpora administración real de atractivos, rutas y paradas.

## Esta actualización

Antes de usar los paneles nuevos, aplicar **una vez** `bd/actualizar_bd_contenidos.sql` sobre la BD existente como postgres. El procedimiento completo está en [docs/ADMIN_CONTENIDOS.md](docs/ADMIN_CONTENIDOS.md). No reinstalar ni borrar casablanca. `bd/casablanca_instalador_actualizado.sql` es únicamente para instalaciones futuras en una base vacía.

El aplicador conserva respaldos y no cambia `.env`, cuentas, contraseñas ni sesiones. No hace commit, push ni abre el túnel. No agrega dependencias. Los resultados y límites comprobados están en [docs/RESULTADOS_ADMIN_CONTENIDOS.md](docs/RESULTADOS_ADMIN_CONTENIDOS.md).

## Ejecutar y desarrollar

- Carpeta activa: `casablanca_publicacion`. Conservar el respaldo anterior y el respaldo PostgreSQL por separado.
- Dependencias, si se instala una copia nueva: `npm.cmd ci` en la raíz y `npm.cmd ci` en backend. Copiar PRIVADAMENTE el `backend/.env` vigente; no reemplazarlo por valores de ejemplo ni subirlo a GitHub.
- Detener las APIs antiguas con Ctrl+C antes de iniciar la nueva. Una API vieja que ocupe 3001 puede responder sin tener las funciones nuevas.
- Para revisar cambios locales, usar **`iniciar-demo.cmd`**. Abrir la dirección exacta de Vite; suele ser `http://localhost:5173/proyecto_casablanca/`, pero puede cambiar de puerto si está ocupado.
- Si se trabaja con terminales manuales, conservar la estructura **FRONT**, **API** y **COMANDOS**. FRONT mantiene Vite; API mantiene Node; COMANDOS ejecuta pruebas y Git. No cerrar API para enviar una petición desde la misma terminal.
- Verificar: `npm.cmd run build`, `npm.cmd run lint`, `node --test tests/*.test.mjs`.
- Publicar es un paso separado: revisar cambios, hacer commit y push con el procedimiento acordado. `iniciar-publicacion.cmd` conserva su mecanismo de API, túnel y actualización de conexión; exige preparar el repositorio antes de iniciarlo.

No dejar una copia anterior ejecutándose a la vez en los mismos puertos. Los avisos de bloqueo del lanzador y los límites de los túneles no se modificaron en este paquete.

## Acceso y cuentas

- Visitante: contenido público, mapas, atractivos, rutas e inicio de sesión. No puede iniciar un recorrido real sin cuenta habilitada.
- Turista: lo anterior, Mi cuenta, su perfil y sus recorridos. No aparece Administración; escribir su URL también está protegido.
- Admin: lo anterior más Categorías, Usuarios, Atractivos y Rutas/Paradas dentro de Administración.

El backend y las funciones SQL comprueban permisos en cada operación. La interfaz no concede permisos por ocultar o mostrar botones. El registro normal crea una cuenta pendiente. No se envían correos todavía; la habilitación manual conserva su configuración opcional de demostración y no prueba que la persona sea dueña del correo. No se habilitan cuentas automáticamente al aplicar esta actualización.

Para probar admin y turista simultáneamente usar perfiles separados o incógnito. Mantener el mismo host durante una prueba local: la cookie de localhost no es la de 127.0.0.1.

## Datos administrados y catálogo de presentación

Registro, login, sesiones, perfil, cuentas, categorías y los nuevos paneles de contenido usan PostgreSQL real. La carga inicial se solicita desde el panel: seis atractivos, tres rutas y catorce paradas, como borradores, conservando ediciones existentes. No se carga al instalar las funciones.

Las rutas reales publicadas se consultan con `GET /api/rutas` y `GET /api/rutas/:uuid`; el turista inicia su propio recorrido mediante `POST /api/rutas/:uuid/recorridos`. Volver del login no inicia un recorrido automáticamente: se requiere confirmar. El historial se consulta desde Mi cuenta y abandonar lo cierra sin borrarlo.

El Inicio, las fichas numéricas de atractivos, las tres rutas del catálogo local y el mapa de presentación **siguen leyendo sus datos locales**. Sus IDs numéricos/claves no son UUID de PostgreSQL. Editar un registro de BD no modifica automáticamente esas vistas; unificar el catálogo público completo quedó fuera de esta entrega. Las rutas reales publicadas sí se agregan al listado público existente.

El antiguo `bd/poblacion_ruta_demo.sql` es opcional y crea otra ruta DEMO publicada. No hace falta ejecutarlo para esta carga inicial. Los recorridos reales que se inicien dejan historial; una ruta con historial se archiva y no se elimina.

## Mapas

Abrir `#/mapas` para consultar **Mapas interactivos** y entrar al Casco Histórico. Tiene vista ilustrada y geográfica con doce paradas. Seleccionar una parada la destaca en rojo y mantiene su selección al cambiar de vista. Los enlaces antiguos `#/map` redirigen al circuito.

La ilustración es del circuito, no un mapa general ni un plano a escala. La geografía distingue siete referencias cartográficas y cinco aproximaciones. Las aproximaciones no se cargan como GPS confirmado en BD. Las fuentes y validaciones pendientes están en [docs/UBICACIONES_CASCO_HISTORICO.md](docs/UBICACIONES_CASCO_HISTORICO.md); su estructura y adaptador a BD en [docs/MAPA_CASCO_HISTORICO.md](docs/MAPA_CASCO_HISTORICO.md).

No se añadió navegación GPS, ubicación del visitante, acreditación QR, descarga offline ni sincronización. La ilustración se mantiene manualmente cuando cambie el circuito. Las imágenes existentes se conservan; la subida de imágenes queda para después.

## Publicación y recuperación

GitHub Pages aloja el frontend estático; no ejecuta Node ni PostgreSQL. Durante la presentación el navegador consulta la API del PC mediante HTTPS y cloudflared. API, túnel, PostgreSQL y PC deben permanecer activos. La parte estática puede seguir abriendo con el backend apagado; las operaciones de cuenta y BD necesitan la conexión.

Se conserva `demoTransport`, la cookie de sesión local y el Bearer en publicación. Una edición de código requiere publicarla mediante Git para llegar a Pages. Una edición de datos en BD no necesita recompilar el frontend que ya consulta ese dato; el catálogo local sí requiere cambiar su archivo y publicarlo.

Para restaurar código, cerrar servicios y abrir el respaldo anterior. Restaurar datos editados requiere el respaldo PostgreSQL; un respaldo de la carpeta del proyecto no contiene la BD. No borrar respaldos antes de validar la entrega en el PC.
