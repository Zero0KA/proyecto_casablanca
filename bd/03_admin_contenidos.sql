-- Actualización sobre una instalación existente. Ejecutar como postgres.
-- No elimina datos ni ejecuta la población inicial.
BEGIN;

-- Los triggers diferidos se ejecutan al COMMIT, cuando ya terminó la llamada
-- SECURITY DEFINER. Usan el propietario interno para poder comprobar la integridad.
GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;
ALTER FUNCTION public.ruta_comprobar_publicacion() OWNER TO casablanca_admin_owner;
ALTER FUNCTION public.atractivo_comprobar_publicacion() OWNER TO casablanca_admin_owner;
ALTER FUNCTION public.categoria_comprobar_activacion() OWNER TO casablanca_admin_owner;
ALTER FUNCTION public.ruta_comprobar_publicacion() SECURITY DEFINER;
ALTER FUNCTION public.atractivo_comprobar_publicacion() SECURITY DEFINER;
ALTER FUNCTION public.categoria_comprobar_activacion() SECURITY DEFINER;
ALTER FUNCTION public.ruta_comprobar_publicacion() SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION public.atractivo_comprobar_publicacion() SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION public.categoria_comprobar_activacion() SET search_path = pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION public.ruta_comprobar_publicacion(),
    public.atractivo_comprobar_publicacion(), public.categoria_comprobar_activacion()
    FROM PUBLIC, casablanca_api;
REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

CREATE OR REPLACE FUNCTION public.admin_bloquear_ruta_edicion(p_token text, p_ruta_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);
    PERFORM 1 FROM public.ruta WHERE id = p_ruta_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe' USING ERRCODE = 'P0002';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_eliminar_atractivo(p_token text, p_atractivo_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_estado text;
BEGIN
    PERFORM public.exigir_administrador(p_token);
    SELECT estado INTO v_estado FROM public.atractivo
    WHERE id = p_atractivo_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El atractivo no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_estado = 'publicado' THEN
        RAISE EXCEPTION 'Retira el atractivo antes de eliminarlo' USING ERRCODE = '55000';
    END IF;
    IF EXISTS (SELECT 1 FROM public.ruta_parada WHERE atractivo_id = p_atractivo_id) THEN
        RAISE EXCEPTION 'El atractivo está asociado a paradas; modifica esas asociaciones antes de eliminarlo'
            USING ERRCODE = '23503';
    END IF;
    DELETE FROM public.atractivo_categoria WHERE atractivo_id = p_atractivo_id;
    DELETE FROM public.atractivo_traduccion WHERE atractivo_id = p_atractivo_id;
    DELETE FROM public.atractivo WHERE id = p_atractivo_id;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_eliminar_ruta(p_token text, p_ruta_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_estado text;
BEGIN
    PERFORM public.exigir_administrador(p_token);
    SELECT estado INTO v_estado FROM public.ruta WHERE id = p_ruta_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_estado = 'publicado' THEN
        RAISE EXCEPTION 'Retira la ruta antes de eliminarla' USING ERRCODE = '55000';
    END IF;
    IF EXISTS (SELECT 1 FROM public.recorrido_usuario WHERE ruta_id = p_ruta_id) THEN
        RAISE EXCEPTION 'La ruta tiene recorridos asociados; archívala para conservar el historial'
            USING ERRCODE = '23503';
    END IF;
    DELETE FROM public.qr_parada AS q USING public.ruta_parada AS p
    WHERE q.parada_id = p.id AND p.ruta_id = p_ruta_id;
    DELETE FROM public.ruta_parada_traduccion AS t USING public.ruta_parada AS p
    WHERE t.parada_id = p.id AND p.ruta_id = p_ruta_id;
    DELETE FROM public.ruta_parada WHERE ruta_id = p_ruta_id;
    DELETE FROM public.ruta_traduccion WHERE ruta_id = p_ruta_id;
    DELETE FROM public.ruta WHERE id = p_ruta_id;
    RETURN true;
END;
$$;

-- El rol de conexión continúa sin acceso directo de escritura a las tablas.
GRANT DELETE ON public.atractivo, public.atractivo_traduccion,
    public.ruta, public.ruta_traduccion TO casablanca_admin_owner;
GRANT SELECT (ruta_id) ON public.recorrido_usuario TO casablanca_admin_owner;
REVOKE ALL ON FUNCTION public.admin_bloquear_ruta_edicion(text, uuid),
    public.admin_eliminar_atractivo(text, uuid), public.admin_eliminar_ruta(text, uuid)
    FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;
ALTER FUNCTION public.admin_bloquear_ruta_edicion(text, uuid) OWNER TO casablanca_admin_owner;
ALTER FUNCTION public.admin_eliminar_atractivo(text, uuid) OWNER TO casablanca_admin_owner;
ALTER FUNCTION public.admin_eliminar_ruta(text, uuid) OWNER TO casablanca_admin_owner;
REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;
GRANT EXECUTE ON FUNCTION public.admin_bloquear_ruta_edicion(text, uuid),
    public.admin_eliminar_atractivo(text, uuid), public.admin_eliminar_ruta(text, uuid)
    TO casablanca_api;

COMMIT;
