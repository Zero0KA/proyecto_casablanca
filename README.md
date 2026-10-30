# Casablanca

Aplicación integrada: React/Vite, Node/Express y PostgreSQL/PostGIS.

**Actualización del 30/10/2026:** administración de atractivos, rutas y paradas con BD real; carga inicial por acción del administrador; borrado protegido; y Mapas interactivos con el circuito del Casco Histórico en vista ilustrada y geográfica.

Consulta [LEEME_INTEGRACION.md](LEEME_INTEGRACION.md) para ejecutar el proyecto. Antes de usar los paneles nuevos en la BD existente, sigue [docs/ADMIN_CONTENIDOS.md](docs/ADMIN_CONTENIDOS.md) y ejecuta `bd/actualizar_bd_contenidos.sql`. El instalador completo actualizado se reserva para una base vacía.

El catálogo público de presentación todavía usa datos locales; su unificación completa con BD queda para una etapa posterior. El panel administrativo sí guarda en PostgreSQL. Fuentes y precisión del mapa: [docs/UBICACIONES_CASCO_HISTORICO.md](docs/UBICACIONES_CASCO_HISTORICO.md). Pruebas y resultados: [docs/RESULTADOS_ADMIN_CONTENIDOS.md](docs/RESULTADOS_ADMIN_CONTENIDOS.md).
