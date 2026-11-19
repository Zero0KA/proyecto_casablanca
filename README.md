# Casablanca

Aplicación turística con React/Vite, API Node/Express y PostgreSQL/PostGIS.

**Actualización del 19/11/2026:** Inicio, atractivos, categorías visibles, rutas y mapas consultan el mismo catálogo de PostgreSQL. La administración conserva el CRUD y permite abrir una vista previa privada. Solo el contenido publicado aparece al visitante; los borradores no se publican automáticamente.

La BD y sus UUID se conservan. Esta actualización no agrega tablas ni funciones SQL y no necesita una migración nueva. Se presupone instalada la ampliación administrativa anterior. El instalador completo continúa reservado para una BD vacía.

- [Ejecución e integración](LEEME_INTEGRACION.md).
- [Catálogo conectado y aplicación del paquete](docs/CATALOGO_CONECTADO.md).
- [Administración y reglas de conservación](docs/ADMIN_CONTENIDOS.md).
- [Mapa e ilustración](docs/MAPA_CASCO_HISTORICO.md).
- [Ubicaciones y referencias pendientes](docs/UBICACIONES_CASCO_HISTORICO.md).
- [Pruebas de esta entrega](docs/RESULTADOS_CATALOGO_CONECTADO.md).

Para comprobar el código en Windows: `verificar-proyecto.cmd`. Para trabajar localmente: `iniciar-demo.cmd`. Para compartir desde Pages: guardar y subir primero el código y después ejecutar `iniciar-publicacion.cmd`.
