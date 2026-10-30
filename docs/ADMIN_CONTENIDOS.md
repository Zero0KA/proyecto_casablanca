# Administración de atractivos, rutas y paradas

Entrega del 30/10/2026 sobre la versión publicada `4053285`. Se conserva el diseño claro, las sesiones, los controles de cuenta, el CRUD de categorías, los lanzadores y el transporte hacia GitHub Pages.

## Aplicación en la BD actual

1. Cerrar FRONT, API y el lanzador público con Ctrl+C. Mantener los respaldos del proyecto y de PostgreSQL fuera de la carpeta de trabajo.
2. Aplicar el paquete con `aplicar-admin.cjs`. Comprueba los archivos de partida y guarda los reemplazados en `.respaldo-admin-contenidos/<fecha>/`. No ejecuta SQL, modifica `.env`, crea cuentas ni publica cambios.
3. En pgAdmin, conexión administrativa, base **casablanca**, abrir **`bd/actualizar_bd_contenidos.sql`** y ejecutar el archivo completo. Debe terminar en COMMIT. No requiere eliminar ni volver a crear la BD.
4. En la raíz del proyecto: `npm.cmd run build`, `npm.cmd run lint` y `node --test tests/*.test.mjs`. Los tests de validación necesitan las dependencias del backend ya instaladas. No hay dependencias nuevas.
5. Abrir `iniciar-demo.cmd`. Debe iniciarse la API nueva; una API antigua que ocupe 3001 no incorpora estos endpoints. Entrar con la cuenta administradora existente.
6. Administración → Atractivos o Rutas. **Agregar catálogo inicial** solicita confirmación y carga solamente los registros iniciales que falten. Para editar paradas, abrir **Paradas** en la fila de una ruta.

`bd/casablanca_instalador_actualizado.sql` es la versión completa para una **BD vacía**, con PostgreSQL/PostGIS disponibles. Sustituye el instalador anterior para instalaciones futuras. **No ejecutarlo encima de casablanca instalada.** Ya incluye la actualización y la definición de carga inicial, pero no la ejecuta ni prepara cuentas.

Los archivos `03_admin_contenidos.sql` y `04_catalogo_inicial.sql` son las fuentes separadas de la actualización. Para instalar en la BD actual basta el archivo combinado; no ejecutar los tres como pasos distintos. Las pruebas están en `tests/`, fuera del instalador.

## Uso del panel

| Contenido | Operaciones |
| --- | --- |
| Atractivos | Listar/buscar, crear, editar nombre, descripción, textos alternativos, imagen existente, coordenadas y categorías; publicar, retirar a borrador, archivar y eliminar. |
| Rutas | Listar/buscar, crear, editar textos, imagen y duración; publicar, retirar, archivar y eliminar cuando sea admisible. |
| Paradas | Crear, editar textos, imagen, ubicación y atractivo opcional; elegir posición, subir/bajar y eliminar. La lista muestra su orden real en esa ruta. |

Un atractivo es una ficha de lugar; una parada pertenece a una ruta y puede tener o no un atractivo asociado. Cambiar el nombre de una parada no cambia automáticamente el del atractivo. Los nombres traducidos se editan por idioma; sus UUID conservan la identidad.

Se puede empezar con un borrador en español. Si se añade inglés, nombre y descripción deben estar completos. Una traducción existente se conserva y debe seguir completa; no hay eliminación de idiomas en este formulario. Publicar exige los requisitos existentes de la BD: español/inglés, imágenes y, para atractivos, ubicación; para rutas, duración y al menos una parada con textos e imagen. Los atractivos vinculados a una ruta publicada deben estar publicados. La BD decide si el conjunto final es válido.

La duración se expresa en minutos enteros positivos. Latitud y longitud se introducen juntas o se dejan ambas vacías; en PostGIS se guardan como X=longitud, Y=latitud, SRID 4326. Son coordenadas del lugar, nunca píxeles del dibujo. Confirmar los puntos antes de publicarlos como ubicación real.

Las imágenes se eligen entre las ya existentes. No hay subida, borrado de archivos ni almacenamiento multimedia nuevo. Si un registro conserva una referencia HTTPS válida, puede mantenerla. Un borrado de contenido elimina sus referencias en BD, no el archivo de imagen compartido.

## Reglas de eliminación

| Operación | Condición y resultado |
| --- | --- |
| Eliminar atractivo | Primero retirarlo de publicación. Si alguna parada lo referencia, se rechaza; editar o quitar esas asociaciones antes. Elimina traducciones y asociaciones de categoría, conservando las categorías. |
| Eliminar ruta | Primero retirarla. Si tiene **cualquier recorrido**, abierto o cerrado, se rechaza: archivar. Sin historial elimina sus textos, paradas, traducciones de parada y QR. Los atractivos asociados permanecen. |
| Eliminar parada | Ruta en **borrador**. Si la parada pertenece a un recorrido abierto, se rechaza y se revierten también los intentos de limpiar textos/QR. Si solo quedan recorridos cerrados, conserva el paso histórico con origen NULL. Elimina su QR/textos y compacta el orden restante. |
| Archivar | Conserva el contenido y el historial y lo retira del listado público de rutas reales. No elimina los recorridos existentes. |

Los recorridos guardan una copia de IDs de paradas y orden. El origen NULL conserva el paso y su posición histórica; **no es una copia íntegra del nombre, descripción y fotografía antiguos**. La edición de orden no altera el orden fijado en recorridos ya iniciados. No se implementó un sistema nuevo de versiones históricas.

Los botones piden confirmación para el borrado. Las protecciones también existen en SQL: no dependen de ocultar un botón. Si otro administrador cambia un dato mientras se trabaja, la operación puede fallar por conflicto; actualizar y revisar antes de repetir. No se implementó control de versiones para detectar toda sobrescritura entre administradores.

## Población inicial

Se incorporan como **borradores** los seis atractivos y tres rutas del catálogo existente: Museo, Casco Histórico y Plaza de Armas. Son catorce paradas: una en Museo, doce en Casco y una en Plaza. Hay textos es/en básicos e imágenes existentes. **No se inventan duraciones.** El Teatro queda sin ubicación precisa. En Casco se cargan siete coordenadas de referencia; las otras cinco quedan NULL hasta verificarlas. Revisar contenido, traducciones y localización antes de publicar.

Los UUID iniciales son estables y están en `bd/catalogo_inicial.json`. Este JSON es el inventario de la carga: el SQL instala su contenido dentro de la función y no lee el archivo en cada petición. Editarlo por sí solo no actualiza la función instalada. La función usa exclusión mutua para dos cargas simultáneas y omite los IDs existentes. **No sobrescribe** nombres, estados, orden ni coordenadas editados. Solo crea paradas cuando se crea su ruta inicial; repetir la carga no repone paradas eliminadas de una ruta existente. Si se borró por completo un atractivo o una ruta inicial, volver a pulsar la carga puede crearlo de nuevo. Los nombres no son identificadores únicos: una ficha creada manualmente con otro UUID no se fusiona por tener el mismo nombre.

## Cómo se conectan las piezas

El formulario React envía JSON por `apiFetch`. Localmente Vite reenvía la petición a Node en 3001; en publicación `demoTransport` conserva la configuración HTTPS y el Bearer de la sesión a través del túnel. Express valida campos y llama funciones SQL con parámetros `$1`, `$2`, etc. Todas las escrituras que componen un formulario comparten una conexión y una transacción: imagen, traducciones, categorías y orden se confirman juntas o se deshacen juntas.

El router nuevo es `backend/contenidos.cjs`, montado en `/api/admin`. GET consulta, POST crea, PUT guarda/reordena, PATCH cambia estado y DELETE elimina. Rutas principales:

- `/api/admin/atractivos` y `/api/admin/atractivos/:id`.
- `/api/admin/rutas` y `/api/admin/rutas/:id`.
- `/api/admin/rutas/:id/paradas` y `/api/admin/rutas/:id/paradas/:parada`.
- `/api/admin/rutas/:id/orden`; los cambios de estado usan `/:id/estado`.
- `POST /api/admin/catalogo-inicial`, con confirmación explícita.

Se usa la sesión personal vigente. No se otorga el rol mediante un campo del formulario ni se usa `DEMO_ADMIN_TOKEN` como respaldo de estas operaciones. Cada función administrativa exige administrador en la BD. El diagnóstico antiguo `/api/estado` conserva su token fijo y no es el mecanismo del panel.

Se mantienen protección de origen, cookie HttpOnly en local/Bearer en publicación, consultas parametrizadas, validación SQL y privilegios mínimos. Los nombres de funciones en las consultas dinámicas proceden de una selección interna cerrada; los datos del usuario van separados como parámetros. El navegador no recibe las credenciales PostgreSQL. Se rechazan campos extra, UUID inválidos, coordenadas parciales, posiciones inválidas y referencias de imagen no admitidas. La API no descarga URLs de imágenes.

Se bloquea la fila de la ruta durante las operaciones compuestas y se limita la espera de bloqueo a cinco segundos. La reordenación reutiliza la restricción UNIQUE diferible de `(ruta_id, orden)` y exige todas las paradas, sin repetidos. Esto protege consistencia; no demuestra todavía la capacidad de 205 usuarios del SLA.

## Cambios permanentes de BD y correcciones detectadas

Se agregan cuatro funciones: `admin_bloquear_ruta_edicion`, `admin_eliminar_atractivo`, `admin_eliminar_ruta` y `admin_cargar_catalogo_inicial`. Las demás operaciones reutilizan las funciones existentes. Se ajustan permisos de los propietarios internos; `casablanca_api` no obtiene INSERT/UPDATE/DELETE directo sobre contenido.

Las tres comprobaciones diferidas de ruta, atractivo y categoría ahora son SECURITY DEFINER, propiedad del rol interno NOLOGIN `casablanca_admin_owner`, con `search_path=pg_catalog,pg_temp` y sin ejecución pública. La prueba con el rol API detectó que antes intentaban consultar tablas al COMMIT con permisos insuficientes. Este ajuste permite verificar integridad al confirmar la transacción sin dar acceso de tabla al backend.

El instalador recibido incluía además un bloque de preparación que exigía cuentas de demo ya existentes, cambiaba sus contraseñas y revocaba sesiones. Se retiró del instalador nuevo. **La migración para tu BD actual no ejecuta ese bloque ni modifica cuentas, contraseñas o sesiones.**

**El ERD no cambia:** no se añaden tablas ni columnas, tipos, valores por defecto, nulabilidad, claves o relaciones. Documentar las funciones, permisos y política de borrado sí requiere actualizar la explicación técnica. La población cambia datos, no el modelo.

## Alcance público y pendientes acordados

La administración nueva usa PostgreSQL real. Las rutas que se publiquen en BD ya aparecen en el apartado público de rutas reales y permiten iniciar recorridos mediante el flujo existente.

**El Inicio, las fichas numéricas de atractivos, las tres rutas del catálogo local y el mapa ilustrado/geográfico de presentación siguen leyendo sus datos locales. Editar sus registros iniciales en BD no cambia automáticamente esas vistas.** Unificar completamente el catálogo público con BD quedó fuera de esta entrega. Por ello, publicar una copia real de una ruta del catálogo puede mostrar ambas hasta resolver esa unificación.

Se aporta `src/data/catalogBindings.js` con los UUID iniciales de Casco y sus doce asociaciones para facilitar el adaptador existente. Activarlo requiere confirmar ubicaciones, publicar el contenido y mantener coincidentes las doce paradas y su orden. El dibujo y el trazado se actualizan manualmente al cambiar el circuito. Las ediciones de coordenadas no redibujan calles ni fachadas.

También quedan fuera: subida de imágenes, generación automática de ilustraciones, navegación giro a giro, ubicación del visitante, acreditación QR en el frontend, descarga offline y sincronización. Las limitaciones se documentan aquí, sin convertirlas en mensajes promocionales o explicaciones técnicas en la página pública.

## Verificación y restauración

`tests/pruebas_contenidos.sql` se ejecuta completo como postgres. Crea datos de prueba dentro de una transacción y termina en ROLLBACK. No sustituye las pruebas anteriores de población caótica. Los resultados y el alcance de la verificación de esta entrega están en `docs/RESULTADOS_ADMIN_CONTENIDOS.md`.

Para volver al código anterior, cerrar servicios y usar el respaldo completo previo o los archivos del respaldo del aplicador. La migración agrega funciones y ajustes de permisos compatibles con el código previo: no hace falta desinstalarla para restaurar el frontend anterior. Si se quiere revertir también los datos editados o el esquema, restaurar el respaldo PostgreSQL previo mediante el procedimiento habitual, sabiendo que reemplaza cambios posteriores. No borrar la BD como paso rutinario.

La publicación continúa separada: revisar el diff, probar, hacer commit y push con el procedimiento acordado. El lanzador público exige el repositorio preparado; no publica estos archivos automáticamente. Si se usa GitHub Pages, mantener API, túnel y PC activos como antes. Este paquete no cambia sus plazos, URL ni mecanismo de actualización.
