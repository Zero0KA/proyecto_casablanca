-- OPCIONAL: una ruta REAL de demostración con tres paradas independientes.
-- Ejecutar en casablanca con una conexión administrativa. No reinstala la BD.
-- No representa un itinerario validado por la municipalidad.
BEGIN;
DO $$
DECLARE v_usuario uuid; v_token text; v_ruta uuid; v_parada uuid; v_orden integer; v_nombre text; v_imagen text;
BEGIN
    IF EXISTS (SELECT 1 FROM public.ruta_traduccion WHERE idioma_codigo='es' AND nombre='DEMO: paseo cultural de Casablanca') THEN
        RAISE NOTICE 'La ruta DEMO ya existe; no se vuelve a crear';
        RETURN;
    END IF;
    SELECT id INTO v_usuario FROM public.usuario WHERE email='demo.admin@example.invalid';
    IF v_usuario IS NULL THEN RAISE EXCEPTION 'Falta el administrador de demostración'; END IF;
    SELECT token_original INTO STRICT v_token FROM public.crear_sesion(v_usuario);
    v_ruta := public.admin_crear_ruta(v_token);
    PERFORM public.admin_actualizar_ruta(v_token,v_ruta,45,'/images/plaza.jpg');
    PERFORM public.admin_guardar_ruta_traduccion(v_token,v_ruta,'es','DEMO: paseo cultural de Casablanca',
        'Ruta de demostración para probar el inicio y el historial de recorridos. Contenido de ejemplo, no itinerario oficial.', 'Plaza de Casablanca');
    PERFORM public.admin_guardar_ruta_traduccion(v_token,v_ruta,'en','DEMO: Casablanca cultural walk',
        'Demonstration route for testing trip creation and history. Sample content, not an official itinerary.', 'Casablanca square');
    FOR v_orden IN 1..3 LOOP
        v_nombre := CASE v_orden WHEN 1 THEN 'Plaza de Armas' WHEN 2 THEN 'Museo de Casablanca' ELSE 'Centro Cultural' END;
        v_imagen := CASE v_orden WHEN 1 THEN '/images/plaza.jpg' WHEN 2 THEN '/images/museo.jpg' ELSE '/images/centroCultural.jpg' END;
        v_parada := public.admin_crear_ruta_parada(v_token,v_ruta,v_orden,NULL,v_imagen,NULL,NULL);
        PERFORM public.admin_guardar_parada_traduccion(v_token,v_parada,'es',v_nombre,'Parada de ejemplo para la demostración del proyecto.',v_nombre);
        PERFORM public.admin_guardar_parada_traduccion(v_token,v_parada,'en',v_nombre,'Sample stop for the project demonstration.',v_nombre);
    END LOOP;
    PERFORM public.admin_publicar_ruta(v_token,v_ruta);
    PERFORM public.cerrar_sesion(v_token);
    RAISE NOTICE 'Ruta DEMO creada con tres paradas';
END;
$$;
COMMIT;
-- Resultado esperado: ruta publicada visible en Rutas; repetir no crea otra.
