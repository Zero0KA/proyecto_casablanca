# Casablanca integrado — diseño y funciones reales

## Instalación sin perder tu versión funcional

1. Extraer el ZIP en una carpeta NUEVA. No reemplazar ni borrar todavía tu proyecto anterior.
2. Copiar PRIVADAMENTE `backend/.env` desde tu proyecto actual a `backend/.env` del integrado. No enviarlo ni subirlo a GitHub. `.env.example` contiene solo placeholders: no reemplazar tu configuración por esos textos.
3. En PowerShell, entrar en la raíz de la nueva carpeta y ejecutar `npm.cmd ci`. Después entrar en backend y ejecutar `npm.cmd ci`. Esto instala las dependencias del PC desde los lockfiles incluidos.
4. Detener FRONT y API de las versiones anteriores con Ctrl+C. Importante: si dejas una API antigua en 3001, el lanzador puede reutilizarla y no tendrá los nuevos endpoints de rutas y perfil.
5. Hacer doble clic en `iniciar-demo.cmd` del proyecto integrado. Abrirá los servicios y la dirección del navegador.
6. El lanzador abre Inicio. A partir de ahora puedes navegar con los botones de la página.

La BD que ya tienes se conserva. NO repetir el instalador, `01_login_y_bloqueo.sql` ni la preparación de cuentas: ya confirmaste que ambos cambios fueron aplicados. No cambiar contraseñas para instalar esta integración.

Puedes nombrar la carpeta nueva `casablanca_integrado` y moverla donde quieras: el lanzador obtiene su propia carpeta. No incluye tus credenciales, node_modules ni dist. Para restaurar la versión anterior, cerrar estos servicios y ejecutar el lanzador de aquella carpeta.

## Menús según la cuenta

- Visitante: Inicio, Mapa, Rutas, Atractivos, Iniciar sesión y Registrarse.
- Turista: contenido público, Mi cuenta y Cerrar sesión. No aparece Administración.
- Admin: lo anterior más Administración; dentro se accede a Categorías y Usuarios.
- Las direcciones administrativas siguen protegidas aunque alguien las escriba. El backend y la BD también comprueban los permisos.

Las dos cuentas y contraseñas de prueba son las que ya preparaste. El registro normal sigue pendiente hasta verificar el correo; no se activa automáticamente.

## Rutas y datos de demostración

Se incorporaron endpoints que usan las funciones YA EXISTENTES de la BD:

- GET `/api/rutas`: rutas publicadas, sin sesión.
- GET `/api/rutas/:id`: detalle y paradas publicadas, sin sesión.
- POST `/api/rutas/:id/recorridos`: inicia el recorrido para el usuario de la cookie; exige sesión válida.
- GET `/api/perfil`: perfil propio.
- GET `/api/recorridos`: historial propio, paginado.
- POST `/api/recorridos/:id/abandonar`: abandona un recorrido propio, conservando historial.

Al solicitar iniciar una ruta sin sesión, se pide login y se regresa a la misma ruta. No se crea nada automáticamente al volver: la persona pulsa Confirmar inicio del recorrido. Una ruta ya abierta produce un conflicto y se puede consultar desde Mi cuenta.

Si no hay rutas publicadas en la BD, se muestran las tres tarjetas de ejemplo del compañero, IDENTIFICADAS como ejemplos. No se convierten sus IDs numéricos en UUID ni se inventa un inicio exitoso.

Para mostrar una ruta REAL en la demo, puedes ejecutar **opcionalmente** `bd/poblacion_ruta_demo.sql` en pgAdmin sobre casablanca con tu conexión administrativa. Crea una ruta publicada DEMO con tres paradas y traducciones en es/en usando las funciones administrativas. No cambia tablas, funciones, roles ni contraseñas; repetirlo no vuelve a crear la ruta. El contenido no es un itinerario oficial ni validado por la municipalidad. Después recargar Rutas.

El inicio guarda datos REALES: aparecen en el historial. Abandonar conserva esos registros. No se proporciona un borrado en cascada para limpiar rutas con historial; las protecciones de la BD permanecen. El SQL opcional no debe incorporarse al instalador como datos obligatorios.

No se integró registrar pasos por QR ni completar recorridos. El mapa conserva el marcador 'próximamente'. Los atractivos públicos siguen utilizando el catálogo de presentación del compañero, con un aviso que lo identifica.

## Qué se conservó y qué cambió

Se conservan su portada, fotografías, colores, tarjetas, menú móvil y pie de página. Se conserva nuestro backend, registro, Argon2id, login, cookies, funciones administrativas, categorías, bloqueo y lanzadores. Su backend alternativo no se incluye.

Cambios compartidos: App/menú/session context, perfil y rutas; estilos coherentes para login, registro y administración. El proxy de Vite se conserva apuntando a 3001. La eliminación de categorías ahora envía JSON y deja de ser rechazada por la protección de origen. Se separó el contexto/hooks de sesiones para resolver el error de lint. Se retiró la referencia a una fuente ausente; permanece la selección local y las fuentes alternativas.

Las fotografías grandes se conservan como fueron entregadas. Optimización de imágenes y mapa real quedan para una etapa posterior. El backend alternativo no se ejecuta y su `.env` no se copia.

No se modificó la BD ni se ejecutó SQL contra ella desde este entorno. Los cambios permanentes del login y del borrado administrativo que aplicaste antes deben seguir en tu instalador actualizado; esta integración no añade funciones SQL nuevas.

## Prueba recomendada en tu PC

1. Sin sesión: recorrer Inicio/Atractivos/Mapa/Rutas y ver Registro/Login en el menú.
2. Turista: login, Mi cuenta con datos reales; sin enlace Administración. URL directa administrativa denegada.
3. Admin: Administración → Categorías; crear, cambiar icono y eliminar. Administración → Usuarios; listar y bloquear/desbloquear una cuenta turista.
4. Si creaste la ruta opcional: cerrar sesión, abrir Rutas → Iniciar recorrido; login turista → volver a esa ruta → Confirmar inicio → Ver mis recorridos. Abandonar para cerrar el intento antes de iniciarlo nuevamente.
5. Cerrar sesión y comprobar que se retira el acceso administrativo y privado.

Para probar admin y turista simultáneamente usar perfiles separados/incógnito. Mantener el mismo host (localhost o 127.0.0.1) durante una prueba, porque la cookie pertenece al host.

## Comprobaciones ya realizadas y límites

- npm run build y npm run lint: correctos sin errores/advertencias del código.
- Pruebas HTTP de registro, Argon2 y sesiones con Express real y BD simulada: correctas.
- Pruebas de endpoints de rutas, ausencia de sesión, UUID inválido, sesión bloqueada y recorrido duplicado: correctas con BD simulada.
- Prueba DOM con React/JSDOM y API simulada: navegación pública, redirección login, vuelta a ruta, inicio explícito, perfil, rechazo turista, menú admin y creación/eliminación de categorías correctos.
- SQL de población: sintaxis SQL/PLpgSQL analizada; no ejecutado contra PostgreSQL en este entorno.

No se realizó prueba visual completa en Chromium: su descarga no pudo completarse en este entorno. Tampoco se accedió al PostgreSQL de tu PC. La prueba final de navegador, permisos y recorrido real se hará en tu instalación.

GitHub Pages solo publicará el frontend estático. Este paquete conectado es para la demo local; publicar allí el diseño no despliega la API ni PostgreSQL. No se hicieron commits, pushes ni publicaciones.
