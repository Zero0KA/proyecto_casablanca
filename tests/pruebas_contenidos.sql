-- Pruebas adicionales. Ejecutar el archivo completo como postgres, fuera del instalador.
-- Crea cuentas y contenido temporales dentro de una transacción. Finaliza con ROLLBACK.
-- Si se interrumpe por un error inesperado, ejecutar ROLLBACK antes de continuar.
BEGIN;
SET LOCAL lock_timeout = '5s';
CREATE TEMP TABLE prueba_contenidos_contexto(admin_token text,turista_token text);
CREATE TEMP TABLE prueba_contenidos_resultados(caso text,correcto boolean);
CREATE FUNCTION pg_temp.comprobar(p_caso text,p_correcto boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO prueba_contenidos_resultados VALUES(p_caso,p_correcto IS TRUE);
    IF p_correcto IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'FALLO: %',p_caso;
    END IF;
END;
$$;
CREATE FUNCTION pg_temp.exigir_error(p_caso text,p_sql text,p_esperado text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_observado text := 'ACEPTADO';
BEGIN
    BEGIN EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_observado = RETURNED_SQLSTATE;
    END;
    PERFORM pg_temp.comprobar(p_caso,v_observado=p_esperado);
END;
$$;
DO $$
DECLARE
    v_admin uuid; v_turista uuid; v_email text; v_token text; v_admin_token text;
    v_hash text := '$argon2id$v=19$m=65536,t=3,p=1$Q2FzYWJsYW5jYVRlc3QyNg$BlD+PTPts4AdoRgTzyExVsmWsnElPWgJ83+WcK6RJV0';
BEGIN
    v_email := 'qa.admin.'||gen_random_uuid()::text||'@example.invalid';
    v_admin := public.registrar_turista(v_email,v_hash,'Prueba contenidos',25,'CL','prefiero_no_responder',NULL);
    SELECT token_original INTO v_token FROM public.emitir_verificacion_email(v_admin);
    PERFORM public.confirmar_email(v_token);
    INSERT INTO public.usuario_rol(usuario_id,rol_id)
        SELECT v_admin,id FROM public.rol WHERE codigo='administrador';
    SELECT token_original INTO v_admin_token FROM public.crear_sesion(v_admin);
    v_turista := public.registrar_turista('qa.turista.'||gen_random_uuid()::text||'@example.invalid',v_hash,'Turista prueba',25,'CL','prefiero_no_responder',NULL);
    SELECT token_original INTO v_token FROM public.emitir_verificacion_email(v_turista);
    PERFORM public.confirmar_email(v_token);
    SELECT token_original INTO v_token FROM public.crear_sesion(v_turista);
    INSERT INTO prueba_contenidos_contexto VALUES(v_admin_token,v_token);
END;
$$;
GRANT SELECT ON prueba_contenidos_contexto TO casablanca_api;
GRANT SELECT,INSERT ON prueba_contenidos_resultados TO casablanca_api;
SET LOCAL ROLE casablanca_api;
DO $$
DECLARE
    c record; a uuid; r uuid; p1 uuid; p2 uuid; qr uuid; rec uuid; v_ids uuid[]; v_resultado jsonb;
BEGIN
    SELECT * INTO c FROM prueba_contenidos_contexto;
    PERFORM pg_temp.exigir_error('Turista no elimina atractivos',format('SELECT public.admin_eliminar_atractivo(%L,%L::uuid)',c.turista_token,gen_random_uuid()),'42501');
    PERFORM pg_temp.exigir_error('API sin escritura directa','INSERT INTO public.ruta(estado) VALUES(''borrador'')','42501');
    PERFORM pg_temp.exigir_error('API sin lectura de sesiones','SELECT * FROM public.sesion_usuario','42501');
    a := public.admin_crear_atractivo(c.admin_token);
    -- Fuerza el trigger diferido después de terminar la función SECURITY DEFINER.
    SET CONSTRAINTS ALL IMMEDIATE;
    PERFORM pg_temp.comprobar('Creación y comprobación diferida con rol API',a IS NOT NULL);
    PERFORM public.admin_actualizar_atractivo(c.admin_token,a,'images/plaza.jpg',-71.4101,-33.3205);
    PERFORM public.admin_guardar_atractivo_traduccion(c.admin_token,a,'es','Prueba','Descripción',NULL);
    PERFORM pg_temp.exigir_error('No publica un atractivo sin inglés',format('SELECT public.admin_publicar_atractivo(%L,%L::uuid)',c.admin_token,a),'23514');
    PERFORM public.admin_guardar_atractivo_traduccion(c.admin_token,a,'en','Test','Description',NULL);
    PERFORM public.admin_publicar_atractivo(c.admin_token,a);
    PERFORM pg_temp.exigir_error('No elimina un atractivo publicado',format('SELECT public.admin_eliminar_atractivo(%L,%L::uuid)',c.admin_token,a),'55000');
    r := public.admin_crear_ruta(c.admin_token);
    PERFORM public.admin_actualizar_ruta(c.admin_token,r,30,'images/plaza.jpg');
    PERFORM public.admin_guardar_ruta_traduccion(c.admin_token,r,'es','Ruta prueba','Descripción',NULL);
    PERFORM public.admin_guardar_ruta_traduccion(c.admin_token,r,'en','Test route','Description',NULL);
    PERFORM pg_temp.exigir_error('No publica una ruta sin paradas',format('SELECT public.admin_publicar_ruta(%L,%L::uuid)',c.admin_token,r),'23514');
    p1 := public.admin_crear_ruta_parada(c.admin_token,r,1,a,'images/plaza.jpg',-71.4101,-33.3205);
    p2 := public.admin_crear_ruta_parada(c.admin_token,r,2,NULL,'images/plaza.jpg',NULL,NULL);
    PERFORM public.admin_guardar_parada_traduccion(c.admin_token,p1,'es','Primera','Descripción',NULL);
    PERFORM public.admin_guardar_parada_traduccion(c.admin_token,p1,'en','First','Description',NULL);
    PERFORM public.admin_guardar_parada_traduccion(c.admin_token,p2,'es','Segunda','Descripción',NULL);
    PERFORM public.admin_guardar_parada_traduccion(c.admin_token,p2,'en','Second','Description',NULL);
    PERFORM public.admin_reordenar_ruta_paradas(c.admin_token,r,ARRAY[p2,p1]);
    SELECT array_agg(parada_id ORDER BY orden) INTO v_ids FROM public.admin_listar_ruta_paradas(c.admin_token,r,'es');
    PERFORM pg_temp.comprobar('Reordenación conserva ambas paradas',v_ids=ARRAY[p2,p1]);
    PERFORM pg_temp.exigir_error('Reordenación repetida rechazada',format('SELECT public.admin_reordenar_ruta_paradas(%L,%L::uuid,%L::uuid[])',c.admin_token,r,ARRAY[p1,p1]),'22023');
    PERFORM public.admin_retirar_atractivo(c.admin_token,a,'borrador');
    PERFORM pg_temp.exigir_error('No elimina un atractivo asociado',format('SELECT public.admin_eliminar_atractivo(%L,%L::uuid)',c.admin_token,a),'23503');
    PERFORM public.admin_publicar_atractivo(c.admin_token,a);
    PERFORM public.admin_publicar_ruta(c.admin_token,r);
    rec := public.iniciar_recorrido(c.turista_token,r);
    PERFORM public.admin_retirar_ruta(c.admin_token,r,'borrador');
    PERFORM pg_temp.exigir_error('No elimina parada de un recorrido abierto',format('SELECT public.admin_eliminar_ruta_parada(%L,%L::uuid)',c.admin_token,p1),'23514');
    PERFORM public.cerrar_recorrido(c.turista_token,rec,'abandonado');
    PERFORM pg_temp.comprobar('Permite eliminar parada después del cierre',public.admin_eliminar_ruta_parada(c.admin_token,p1));
    PERFORM pg_temp.exigir_error('No elimina una ruta con historial',format('SELECT public.admin_eliminar_ruta(%L,%L::uuid)',c.admin_token,r),'23503');
    PERFORM public.admin_retirar_ruta(c.admin_token,r,'archivado');
    PERFORM pg_temp.comprobar('Archiva ruta con historial',EXISTS(SELECT FROM public.admin_listar_rutas(c.admin_token,'es') WHERE ruta_id=r AND estado='archivado'));
    PERFORM public.admin_retirar_atractivo(c.admin_token,a,'borrador');
    PERFORM pg_temp.comprobar('Elimina atractivo sin asociaciones',public.admin_eliminar_atractivo(c.admin_token,a));
    r := public.admin_crear_ruta(c.admin_token);
    p1 := public.admin_crear_ruta_parada(c.admin_token,r,1,NULL,'images/plaza.jpg',NULL,NULL);
    qr := public.admin_obtener_o_crear_qr_parada(c.admin_token,p1);
    PERFORM pg_temp.comprobar('Borra ruta sin historial junto con parada y QR',qr IS NOT NULL AND public.admin_eliminar_ruta(c.admin_token,r));
    PERFORM public.admin_cargar_catalogo_inicial(c.admin_token);
    v_resultado := public.admin_cargar_catalogo_inicial(c.admin_token);
    PERFORM pg_temp.comprobar('Carga inicial repetible sin duplicados',v_resultado='{"atractivos_creados":0,"rutas_creadas":0,"paradas_creadas":0}'::jsonb);
END;
$$;
RESET ROLE;
SELECT count(*) AS casos, count(*) FILTER(WHERE correcto) AS correctos,
       count(*) FILTER(WHERE NOT correcto) AS diferencias
FROM prueba_contenidos_resultados;
ROLLBACK;
-- RESULTADO DOCUMENTADO (30/10/2026, PostgreSQL 16.15 + PostGIS 3.4.2):
-- 17 casos, 17 correctos, 0 diferencias. ROLLBACK confirmado.
-- Las cuentas y todos los datos creados por la prueba se deshacen con ROLLBACK.
