-- INSTALADOR COMPLETO: únicamente para una base vacía con PostGIS disponible.
-- Para una BD existente usa actualizar_bd_contenidos.sql. No incluye cuentas de prueba.
BEGIN;
-- CASABLANCA: instalación inicial consolidada.
-- Origen: casablanca(3).sql. PostgreSQL 18; PostGIS disponible en el servidor.
-- Ejecutar completo como administrador en una BD NUEVA y vacía.
-- La BD se crea previamente desde pgAdmin; este archivo no crea la BD.
-- Una transacción instala estructura, funciones, permisos y catálogos.
-- Los roles técnicos son globales al clúster: se reutilizan si sus atributos coinciden.
-- No incluye pruebas, usuarios ficticios ni una contraseña para el backend.
-- casablanca_api permanece NOLOGIN; la conexión real del backend se configura después.
-- Argon2id: versión 19, sal de 16 bytes y resultado de 32 bytes en formato codificado.
-- El backend genera/verifica el hash; la BD comprueba su estructura.
-- Retirar rutas conserva los recorridos; impide avanzar/completar y permite abandonar.


-- Extensiones

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- Roles técnicos sin inicio de sesión.
DO $roles$
DECLARE
    v_nombre text;
    v_rol record;
BEGIN
    FOREACH v_nombre IN ARRAY ARRAY['casablanca_api', 'casablanca_registro_owner', 'casablanca_verificacion_owner', 'casablanca_sesion_owner', 'casablanca_perfil_owner', 'casablanca_admin_owner', 'casablanca_consulta_owner', 'casablanca_recorrido_owner', 'casablanca_autenticacion_owner'] LOOP
        SELECT * INTO v_rol FROM pg_catalog.pg_roles WHERE rolname = v_nombre;
        IF NOT FOUND THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS', v_nombre);
        ELSIF v_rol.rolcanlogin OR v_rol.rolsuper OR v_rol.rolcreatedb
           OR v_rol.rolcreaterole OR v_rol.rolreplication OR v_rol.rolbypassrls THEN
            RAISE EXCEPTION 'El rol existente % no cumple los atributos técnicos previstos', v_nombre;
        END IF;
    END LOOP;
END;
$roles$;

-- Tablas, claves, restricciones e índices

CREATE TABLE public.rol (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo character varying(30) NOT NULL,
    descripcion character varying(200) NOT NULL,
    CONSTRAINT rol_codigo_valido CHECK (((codigo)::text = ANY ((ARRAY['turista'::character varying, 'administrador'::character varying])::text[]))),
    CONSTRAINT rol_descripcion_valida CHECK ((((char_length(btrim((descripcion)::text)) >= 1) AND (char_length(btrim((descripcion)::text)) <= 200)) AND ((descripcion)::text ~ '[^[:space:]]'::text)))
);

CREATE TABLE public.usuario (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    nombre character varying(100) NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    email_verificado_en timestamp with time zone,
    creado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actualizado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT usuario_activo_verificado CHECK ((((estado)::text <> 'activo'::text) OR (email_verificado_en IS NOT NULL))),
    CONSTRAINT usuario_email_normalizado CHECK (((email = lower(btrim(email))) AND ((char_length(email) >= 3) AND (char_length(email) <= 254)) AND (email !~ '[[:space:]]'::text))),
    CONSTRAINT usuario_estado_valido CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'activo'::character varying, 'bloqueado'::character varying])::text[]))),
    CONSTRAINT usuario_fechas_validas CHECK ((isfinite(creado_en) AND isfinite(actualizado_en) AND (actualizado_en >= creado_en) AND ((email_verificado_en IS NULL) OR (isfinite(email_verificado_en) AND (email_verificado_en >= creado_en))))),
    CONSTRAINT usuario_nombre_valido CHECK ((((char_length(btrim((nombre)::text)) >= 1) AND (char_length(btrim((nombre)::text)) <= 100)) AND ((nombre)::text ~ '[^[:space:]]'::text))),
    CONSTRAINT usuario_password_hash_no_vacio CHECK (((char_length(btrim(password_hash)) > 0) AND (password_hash ~ '[^[:space:]]'::text)))
);

CREATE TABLE public.usuario_rol (
    usuario_id uuid NOT NULL,
    rol_id uuid NOT NULL,
    asignado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT usuario_rol_fecha_valida CHECK (isfinite(asignado_en))
);

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_codigo_unico UNIQUE (codigo);

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pk PRIMARY KEY (id);

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_email_unico UNIQUE (email);

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pk PRIMARY KEY (id);

ALTER TABLE ONLY public.usuario_rol
    ADD CONSTRAINT usuario_rol_pk PRIMARY KEY (usuario_id, rol_id);

CREATE INDEX usuario_rol_rol_idx ON public.usuario_rol USING btree (rol_id);

ALTER TABLE ONLY public.usuario_rol
    ADD CONSTRAINT usuario_rol_rol_fk FOREIGN KEY (rol_id) REFERENCES public.rol(id);

ALTER TABLE ONLY public.usuario_rol
    ADD CONSTRAINT usuario_rol_usuario_fk FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);

CREATE TABLE public.pais
(
    codigo varchar(2) NOT NULL,
    nombre_es varchar(100) NOT NULL,

    CONSTRAINT pais_pk PRIMARY KEY (codigo),

    -- Formato de dos letras mayusculas.
    -- No demuestra que el codigo sea oficial:
    -- la carga del catalogo debe estar verificada.
    CONSTRAINT pais_codigo_valido
        CHECK (codigo ~ '^[A-Z]{2}$'),

    CONSTRAINT pais_nombre_valido
        CHECK (nombre_es ~ '[^[:space:]]')
);

CREATE TABLE public.perfil_turista
(
    usuario_id uuid NOT NULL,
    edad_declarada smallint NOT NULL,
    edad_declarada_en timestamptz NOT NULL
        DEFAULT CURRENT_TIMESTAMP,
    nacionalidad_codigo varchar(2) NOT NULL,
    genero_codigo varchar(30) NOT NULL,
    genero_detalle varchar(100),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Una cuenta puede tener como maximo un perfil.
    CONSTRAINT perfil_turista_pk
        PRIMARY KEY (usuario_id),

    CONSTRAINT perfil_turista_usuario_fk
        FOREIGN KEY (usuario_id)
        REFERENCES public.usuario (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    -- Solo acepta nacionalidades incluidas en el catalogo.
    CONSTRAINT perfil_turista_nacionalidad_fk
        FOREIGN KEY (nacionalidad_codigo)
        REFERENCES public.pais (codigo)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT perfil_turista_edad_valida
        CHECK (edad_declarada BETWEEN 0 AND 120),

    CONSTRAINT perfil_turista_genero_valido
        CHECK (
            genero_codigo IN (
                'masculino',
                'femenino',
                'no_binario',
                'otra_identidad',
                'prefiero_no_responder'
            )
        ),

    -- El detalle es opcional y solo corresponde a otra_identidad.
    -- Si se informa, debe contener algo distinto de espacios.
    CONSTRAINT perfil_turista_genero_detalle_valido
        CHECK (
            genero_detalle IS NULL
            OR (
                genero_codigo = 'otra_identidad'
                AND genero_detalle ~ '[^[:space:]]'
            )
        ),

    CONSTRAINT perfil_turista_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(actualizado_en)
            AND isfinite(edad_declarada_en)
            AND actualizado_en >= creado_en
            AND edad_declarada_en >= creado_en
            AND edad_declarada_en <= actualizado_en
        )
);

CREATE TABLE public.verificacion_email
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    usuario_id uuid NOT NULL,
    token_hash text NOT NULL,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_en timestamptz NOT NULL,
    consumido_en timestamptz,
    revocado_en timestamptz,

    CONSTRAINT verificacion_email_pk PRIMARY KEY (id),

    -- Evita reutilizar el mismo hash en varios registros.
    CONSTRAINT verificacion_email_token_unico UNIQUE (token_hash),

    CONSTRAINT verificacion_email_usuario_fk
        FOREIGN KEY (usuario_id)
        REFERENCES public.usuario (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    -- Convención: SHA-256 representado con 64 caracteres hexadecimales.
    -- Valida el formato, no la aleatoriedad del token original.
    CONSTRAINT verificacion_email_hash_valido
        CHECK (token_hash ~ '^[0-9a-f]{64}$'),

    -- Fechas finitas y vencimiento posterior a la creación.
    CONSTRAINT verificacion_email_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(expira_en)
            AND expira_en > creado_en
            AND (
                consumido_en IS NULL
                OR (
                    isfinite(consumido_en)
                    AND consumido_en >= creado_en
                    AND consumido_en < expira_en
                )
            )
            AND (
                revocado_en IS NULL
                OR (
                    isfinite(revocado_en)
                    AND revocado_en >= creado_en
                )
            )
        ),

    -- Un token termina consumido o revocado, no en ambos estados.
    CONSTRAINT verificacion_email_estado_valido
        CHECK (consumido_en IS NULL OR revocado_en IS NULL)
);

CREATE INDEX verificacion_email_usuario_idx
    ON public.verificacion_email (usuario_id);

CREATE TABLE public.sesion_usuario
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    usuario_id uuid NOT NULL,
    token_hash text NOT NULL,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_en timestamptz NOT NULL,
    revocado_en timestamptz,

    CONSTRAINT sesion_usuario_pk PRIMARY KEY (id),

    CONSTRAINT sesion_usuario_token_unico UNIQUE (token_hash),

    -- Cada sesión pertenece a una cuenta existente.
    CONSTRAINT sesion_usuario_usuario_fk
        FOREIGN KEY (usuario_id)
        REFERENCES public.usuario (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    -- SHA-256 hexadecimal en minúsculas.
    -- El formato no demuestra que el token original sea aleatorio.
    CONSTRAINT sesion_usuario_hash_valido
        CHECK (token_hash ~ '^[0-9a-f]{64}$'),

    -- Fechas finitas y vencimiento posterior a la creación.
    -- Una sesión puede revocarse incluso después de vencer.
    CONSTRAINT sesion_usuario_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(expira_en)
            AND expira_en > creado_en
            AND (
                revocado_en IS NULL
                OR (
                    isfinite(revocado_en)
                    AND revocado_en >= creado_en
                )
            )
        )
);

CREATE INDEX sesion_usuario_usuario_idx
    ON public.sesion_usuario (usuario_id);

CREATE TABLE public.atractivo
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    estado varchar(20) NOT NULL DEFAULT 'borrador',
    imagen_principal text,
    ubicacion public.geometry(Point, 4326),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT atractivo_pk PRIMARY KEY (id),

    CONSTRAINT atractivo_estado_valido
        CHECK (estado IN ('borrador', 'publicado', 'archivado')),

    -- Referencia opcional al archivo; rechaza texto vacío.
    -- La existencia y seguridad del archivo se comprueban en el backend.
    CONSTRAINT atractivo_imagen_valida
        CHECK (
            imagen_principal IS NULL
            OR (
                imagen_principal = btrim(imagen_principal)
                AND imagen_principal ~ '[^[:space:]]'
                AND char_length(imagen_principal) <= 2048
            )
        ),

    -- Punto no vacío con coordenadas dentro de los rangos válidos.
    -- X = longitud; Y = latitud. No demuestra que el lugar sea correcto.
    CONSTRAINT atractivo_ubicacion_valida
        CHECK (
            ubicacion IS NULL
            OR (
                NOT public.ST_IsEmpty(ubicacion)
                AND public.ST_X(ubicacion) BETWEEN -180 AND 180
                AND public.ST_Y(ubicacion) BETWEEN -90 AND 90
            )
        ),

    -- Permite preparar borradores incompletos.
    CONSTRAINT atractivo_publicado_datos_basicos
        CHECK (
            estado <> 'publicado'
            OR (
                ubicacion IS NOT NULL
                AND imagen_principal IS NOT NULL
            )
        ),

    CONSTRAINT atractivo_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(actualizado_en)
            AND actualizado_en >= creado_en
        )
);

CREATE INDEX atractivo_ubicacion_idx
    ON public.atractivo USING gist (ubicacion);

CREATE TABLE public.atractivo_traduccion
(
    atractivo_id uuid NOT NULL,
    idioma_codigo varchar(2) NOT NULL,
    nombre varchar(200) NOT NULL,
    descripcion text NOT NULL,
    imagen_texto_alternativo varchar(300),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT atractivo_traduccion_pk
        PRIMARY KEY (atractivo_id, idioma_codigo),

    CONSTRAINT atractivo_traduccion_atractivo_fk
        FOREIGN KEY (atractivo_id)
        REFERENCES public.atractivo (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    -- Idiomas iniciales exigidos por el proyecto.
    CONSTRAINT atractivo_traduccion_idioma_valido
        CHECK (idioma_codigo IN ('es', 'en')),

    -- Evita nombres vacíos o con espacios en los extremos.
    CONSTRAINT atractivo_traduccion_nombre_valido
        CHECK (
            nombre = btrim(nombre)
            AND nombre ~ '[^[:space:]]'
        ),

    -- Límite inicial de contenido, ajustable según necesidades.
    CONSTRAINT atractivo_traduccion_descripcion_valida
        CHECK (
            descripcion ~ '[^[:space:]]'
            AND char_length(descripcion) <= 20000
        ),

    CONSTRAINT atractivo_traduccion_texto_alternativo_valido
        CHECK (
            imagen_texto_alternativo IS NULL
            OR (
                imagen_texto_alternativo =
                    btrim(imagen_texto_alternativo)
                AND imagen_texto_alternativo ~ '[^[:space:]]'
            )
        ),

    CONSTRAINT atractivo_traduccion_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(actualizado_en)
            AND actualizado_en >= creado_en
        )
);

CREATE TABLE public.categoria_atractivo
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    codigo varchar(50) NOT NULL,
    icono_codigo varchar(50) NOT NULL,
    activo boolean NOT NULL DEFAULT true,

    CONSTRAINT categoria_atractivo_pk PRIMARY KEY (id),

    CONSTRAINT categoria_atractivo_codigo_unico UNIQUE (codigo),

    -- Códigos en minúsculas, sin espacios.
    -- Permite letras, números y guion bajo; comienza con letra.
    CONSTRAINT categoria_atractivo_codigo_valido
        CHECK (codigo ~ '^[a-z][a-z0-9_]{0,49}$'),

    -- Identificador del icono, no HTML ni una URL.
    -- El frontend deberá resolverlo mediante una lista de iconos admitidos.
    CONSTRAINT categoria_atractivo_icono_valido
        CHECK (icono_codigo ~ '^[a-z][a-z0-9_]{0,49}$')
);

CREATE TABLE public.categoria_atractivo_traduccion
(
    categoria_id uuid NOT NULL,
    idioma_codigo varchar(2) NOT NULL,
    nombre varchar(100) NOT NULL,

    -- Evita repetir el mismo idioma dentro de una categoría.
    CONSTRAINT categoria_atractivo_traduccion_pk
        PRIMARY KEY (categoria_id, idioma_codigo),

    -- Impide traducciones de categorías inexistentes.
    CONSTRAINT categoria_atractivo_traduccion_categoria_fk
        FOREIGN KEY (categoria_id)
        REFERENCES public.categoria_atractivo (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT categoria_atractivo_traduccion_idioma_valido
        CHECK (idioma_codigo IN ('es', 'en')),

    -- Rechaza nombres vacíos, solo espacios o espacios en los extremos.
    CONSTRAINT categoria_atractivo_traduccion_nombre_valido
        CHECK (
            nombre = btrim(nombre)
            AND nombre ~ '[^[:space:]]'
        )
);

CREATE TABLE public.atractivo_categoria
(
    atractivo_id uuid NOT NULL,
    categoria_id uuid NOT NULL,

    CONSTRAINT atractivo_categoria_pk
        PRIMARY KEY (atractivo_id, categoria_id),

    CONSTRAINT atractivo_categoria_atractivo_fk
        FOREIGN KEY (atractivo_id)
        REFERENCES public.atractivo (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT atractivo_categoria_categoria_fk
        FOREIGN KEY (categoria_id)
        REFERENCES public.categoria_atractivo (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);

CREATE INDEX atractivo_categoria_categoria_idx
    ON public.atractivo_categoria (categoria_id);

CREATE TABLE public.ruta
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    estado varchar(20) NOT NULL DEFAULT 'borrador',
    duracion_estimada_minutos integer,
    imagen_principal text,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ruta_pk PRIMARY KEY (id),

    CONSTRAINT ruta_estado_valido
        CHECK (estado IN ('borrador', 'publicado', 'archivado')),

    -- NULL significa que aún no se conoce la duración.
    -- Si se informa, debe ser positiva.
    CONSTRAINT ruta_duracion_valida
        CHECK (
            duracion_estimada_minutos IS NULL
            OR duracion_estimada_minutos > 0
        ),

    -- Referencia al archivo; no comprueba su existencia.
    CONSTRAINT ruta_imagen_valida
        CHECK (
            imagen_principal IS NULL
            OR (
                imagen_principal = btrim(imagen_principal)
                AND imagen_principal ~ '[^[:space:]]'
                AND char_length(imagen_principal) <= 2048
            )
        ),

    -- La duración debe estar definida antes de publicar.
    -- Traducciones y paradas requerirán controles adicionales.
    CONSTRAINT ruta_publicada_duracion
        CHECK (
            estado <> 'publicado'
            OR duracion_estimada_minutos IS NOT NULL
        ),

    CONSTRAINT ruta_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(actualizado_en)
            AND actualizado_en >= creado_en
        )
);

CREATE TABLE public.ruta_traduccion
(
    ruta_id uuid NOT NULL,
    idioma_codigo varchar(2) NOT NULL,
    nombre varchar(200) NOT NULL,
    descripcion text NOT NULL,
    imagen_texto_alternativo varchar(300),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ruta_traduccion_pk
        PRIMARY KEY (ruta_id, idioma_codigo),

    CONSTRAINT ruta_traduccion_ruta_fk
        FOREIGN KEY (ruta_id)
        REFERENCES public.ruta (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    -- Idiomas iniciales del proyecto.
    CONSTRAINT ruta_traduccion_idioma_valido
        CHECK (idioma_codigo IN ('es', 'en')),

    CONSTRAINT ruta_traduccion_nombre_valido
        CHECK (
            nombre = btrim(nombre)
            AND nombre ~ '[^[:space:]]'
        ),

    -- Límite inicial ajustable, igual al contenido de atractivos.
    CONSTRAINT ruta_traduccion_descripcion_valida
        CHECK (
            descripcion ~ '[^[:space:]]'
            AND char_length(descripcion) <= 20000
        ),

    CONSTRAINT ruta_traduccion_texto_alternativo_valido
        CHECK (
            imagen_texto_alternativo IS NULL
            OR (
                imagen_texto_alternativo =
                    btrim(imagen_texto_alternativo)
                AND imagen_texto_alternativo ~ '[^[:space:]]'
            )
        ),

    CONSTRAINT ruta_traduccion_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(actualizado_en)
            AND actualizado_en >= creado_en
        )
);

CREATE TABLE public.ruta_parada
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    ruta_id uuid NOT NULL,
    atractivo_id uuid,
    orden integer NOT NULL,
    imagen_principal text,
    ubicacion public.geometry(Point, 4326),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ruta_parada_pk PRIMARY KEY (id),

    -- No permite dos paradas en la misma posición de una ruta.
    CONSTRAINT ruta_parada_orden_unico UNIQUE (ruta_id, orden),

    CONSTRAINT ruta_parada_ruta_fk
        FOREIGN KEY (ruta_id)
        REFERENCES public.ruta (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT ruta_parada_atractivo_fk
        FOREIGN KEY (atractivo_id)
        REFERENCES public.atractivo (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT ruta_parada_orden_valido
        CHECK (orden > 0),

    -- Valida la referencia textual, no el archivo de imagen.
    CONSTRAINT ruta_parada_imagen_valida
        CHECK (
            imagen_principal IS NULL
            OR (
                imagen_principal = btrim(imagen_principal)
                AND imagen_principal ~ '[^[:space:]]'
                AND char_length(imagen_principal) <= 2048
            )
        ),

    -- Longitud y latitud válidas si se informa una ubicación.
    CONSTRAINT ruta_parada_ubicacion_valida
        CHECK (
            ubicacion IS NULL
            OR (
                NOT public.ST_IsEmpty(ubicacion)
                AND public.ST_X(ubicacion) BETWEEN -180 AND 180
                AND public.ST_Y(ubicacion) BETWEEN -90 AND 90
            )
        ),

    CONSTRAINT ruta_parada_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(actualizado_en)
            AND actualizado_en >= creado_en
        )
);

CREATE INDEX ruta_parada_atractivo_idx
    ON public.ruta_parada (atractivo_id);

CREATE INDEX ruta_parada_ubicacion_idx
    ON public.ruta_parada USING gist (ubicacion);

CREATE TABLE public.ruta_parada_traduccion
(
    parada_id uuid NOT NULL,
    idioma_codigo varchar(2) NOT NULL,
    nombre varchar(200) NOT NULL,
    descripcion text NOT NULL,
    imagen_texto_alternativo varchar(300),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ruta_parada_traduccion_pk
        PRIMARY KEY (parada_id, idioma_codigo),

    CONSTRAINT ruta_parada_traduccion_parada_fk
        FOREIGN KEY (parada_id)
        REFERENCES public.ruta_parada (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT ruta_parada_traduccion_idioma_valido
        CHECK (idioma_codigo IN ('es', 'en')),

    CONSTRAINT ruta_parada_traduccion_nombre_valido
        CHECK (
            nombre = btrim(nombre)
            AND nombre ~ '[^[:space:]]'
        ),

    -- Límite inicial ajustable, consistente con las otras traducciones.
    CONSTRAINT ruta_parada_traduccion_descripcion_valida
        CHECK (
            descripcion ~ '[^[:space:]]'
            AND char_length(descripcion) <= 20000
        ),

    CONSTRAINT ruta_parada_traduccion_texto_alternativo_valido
        CHECK (
            imagen_texto_alternativo IS NULL
            OR (
                imagen_texto_alternativo =
                    btrim(imagen_texto_alternativo)
                AND imagen_texto_alternativo ~ '[^[:space:]]'
            )
        ),

    CONSTRAINT ruta_parada_traduccion_fechas_validas
        CHECK (
            isfinite(creado_en)
            AND isfinite(actualizado_en)
            AND actualizado_en >= creado_en
        )
);

ALTER TABLE public.ruta_parada
    DROP CONSTRAINT ruta_parada_orden_unico;

ALTER TABLE public.ruta_parada
    ADD CONSTRAINT ruta_parada_orden_unico
    UNIQUE (ruta_id, orden)
    DEFERRABLE INITIALLY IMMEDIATE;

CREATE TABLE public.recorrido_usuario
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    usuario_id uuid NOT NULL,
    ruta_id uuid NOT NULL,
    estado varchar(20) NOT NULL DEFAULT 'en_curso',
    iniciado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finalizado_en timestamptz,

    CONSTRAINT recorrido_usuario_pk PRIMARY KEY (id),

    CONSTRAINT recorrido_usuario_usuario_fk
        FOREIGN KEY (usuario_id)
        REFERENCES public.usuario (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT recorrido_usuario_ruta_fk
        FOREIGN KEY (ruta_id)
        REFERENCES public.ruta (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    -- Abandonar cierra el intento sin acreditarlo como completado.
    CONSTRAINT recorrido_usuario_estado_valido
        CHECK (estado IN ('en_curso', 'completado', 'abandonado')),

    CONSTRAINT recorrido_usuario_fechas_validas
        CHECK (
            isfinite(iniciado_en)
            AND (
                finalizado_en IS NULL
                OR (
                    isfinite(finalizado_en)
                    AND finalizado_en >= iniciado_en
                )
            )
        ),

    -- En curso: sin cierre. Completado o abandonado: con cierre.
    CONSTRAINT recorrido_usuario_estado_fecha_coherente
        CHECK (
            (estado = 'en_curso' AND finalizado_en IS NULL)
            OR
            (estado IN ('completado', 'abandonado')
             AND finalizado_en IS NOT NULL)
        )
);

CREATE UNIQUE INDEX recorrido_usuario_abierto_unico
    ON public.recorrido_usuario (usuario_id, ruta_id)
    WHERE estado = 'en_curso';

CREATE INDEX recorrido_usuario_ruta_idx
    ON public.recorrido_usuario (ruta_id);

CREATE TABLE public.recorrido_parada
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    recorrido_id uuid NOT NULL,
    parada_id uuid,
    orden integer NOT NULL,
    registrado_en timestamptz,

    CONSTRAINT recorrido_parada_pk PRIMARY KEY (id),

    -- Una posición y una parada original por intento.
    CONSTRAINT recorrido_parada_orden_unico
        UNIQUE (recorrido_id, orden),

    CONSTRAINT recorrido_parada_origen_unico
        UNIQUE (recorrido_id, parada_id),

    CONSTRAINT recorrido_parada_recorrido_fk
        FOREIGN KEY (recorrido_id)
        REFERENCES public.recorrido_usuario (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    -- Conserva el paso histórico si se elimina la parada original.
    CONSTRAINT recorrido_parada_parada_fk
        FOREIGN KEY (parada_id)
        REFERENCES public.ruta_parada (id)
        ON UPDATE NO ACTION
        ON DELETE SET NULL,

    CONSTRAINT recorrido_parada_orden_valido
        CHECK (orden > 0),

    CONSTRAINT recorrido_parada_fecha_valida
        CHECK (
            registrado_en IS NULL
            OR isfinite(registrado_en)
        )
);

CREATE INDEX recorrido_parada_parada_idx
    ON public.recorrido_parada (parada_id);

ALTER TABLE public.recorrido_usuario
    ADD COLUMN pasos_fijados boolean NOT NULL DEFAULT false;

CREATE TABLE public.qr_parada
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    parada_id uuid NOT NULL,
    activo boolean NOT NULL DEFAULT true,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT qr_parada_pk
        PRIMARY KEY (id),

    -- Una parada conserva un único identificador de QR.
    CONSTRAINT qr_parada_parada_unica
        UNIQUE (parada_id),

    CONSTRAINT qr_parada_parada_fk
        FOREIGN KEY (parada_id)
        REFERENCES public.ruta_parada (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT qr_parada_fecha_valida
        CHECK (isfinite(creado_en))
);

ALTER TABLE public.usuario
ADD CONSTRAINT usuario_email_estructura_valida
CHECK (
    email ~ '^[^[:space:]@]+@[^[:space:]@]+$'
);

ALTER TABLE public.usuario
ADD CONSTRAINT usuario_password_hash_estructura_valida
CHECK (
    char_length(password_hash) <= 1024
    AND password_hash ~
        '^[$]argon2id[$]v=19[$]m=[1-9][0-9]*,t=[1-9][0-9]*,p=[1-9][0-9]*[$][A-Za-z0-9+/]{22}[$][A-Za-z0-9+/]{43}$'
);

-- Funciones finales; una definición por firma

CREATE OR REPLACE FUNCTION public.usuario_actualizar_fecha()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'No se puede modificar el id del usuario';
    END IF;

    IF NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION 'No se puede modificar creado_en';
    END IF;

    NEW.actualizado_en := statement_timestamp();

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.perfil_turista_actualizar_fechas()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- La identidad del perfil y su creacion se conservan.
    IF NEW.usuario_id IS DISTINCT FROM OLD.usuario_id
       OR NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION
            'No se puede cambiar el propietario ni la fecha de creacion del perfil';
    END IF;

    NEW.actualizado_en := statement_timestamp();

    -- Si cambia la edad, registra cuando fue actualizada.
    IF NEW.edad_declarada IS DISTINCT FROM OLD.edad_declarada THEN
        NEW.edad_declarada_en := NEW.actualizado_en;
    ELSE
        NEW.edad_declarada_en := OLD.edad_declarada_en;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.registrar_turista(
    p_email text,
    p_password_hash text,
    p_nombre text,
    p_edad integer,
    p_nacionalidad_codigo text,
    p_genero_codigo text,
    p_genero_detalle text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_usuario_id uuid;
    v_rol_id uuid;
BEGIN
    -- El backend debe generar el hash real.
    -- Verificar el prefijo no demuestra su autenticidad.
    IF p_password_hash IS NULL
       OR char_length(p_password_hash) > 1024
       OR p_password_hash NOT LIKE '$argon2id$%' THEN
        RAISE EXCEPTION 'Se requiere un hash Argon2id'
            USING ERRCODE = '22023';
    END IF;

    -- Valida antes de convertir integer a smallint.
    IF p_edad IS NULL OR p_edad NOT BETWEEN 0 AND 120 THEN
        RAISE EXCEPTION 'La edad debe estar entre 0 y 120'
            USING ERRCODE = '22023';
    END IF;

    -- El cliente no puede elegir el rol.
    SELECT id INTO STRICT v_rol_id
    FROM public.rol
    WHERE codigo = 'turista';

    -- Conserva los valores por defecto:
    -- estado pendiente y correo sin verificar.
    INSERT INTO public.usuario (email, password_hash, nombre)
    VALUES (
        lower(btrim(p_email)),
        p_password_hash,
        btrim(p_nombre)
    )
    RETURNING id INTO v_usuario_id;

    INSERT INTO public.usuario_rol (usuario_id, rol_id)
    VALUES (v_usuario_id, v_rol_id);

    -- CHECK, NOT NULL y claves foráneas siguen aplicándose.
    -- Las fechas se generan con los valores por defecto.
    INSERT INTO public.perfil_turista (
        usuario_id,
        edad_declarada,
        nacionalidad_codigo,
        genero_codigo,
        genero_detalle
    )
    VALUES (
        v_usuario_id,
        p_edad::smallint,
        upper(btrim(p_nacionalidad_codigo)),
        lower(btrim(p_genero_codigo)),
        nullif(btrim(p_genero_detalle), '')
    );

    RETURN v_usuario_id;
END;
$function$;

CREATE FUNCTION public.emitir_verificacion_email(p_usuario_id uuid)
RETURNS TABLE (
    correo_destino text,
    token_original text,
    vence_en timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_correo text;
    v_estado text;
    v_verificado_en timestamptz;
    v_ahora timestamptz;
    v_ultima_emision timestamptz;
    v_emisiones bigint;
    v_token text;
    v_expira_en timestamptz;
BEGIN
    -- Serializa las solicitudes de una misma cuenta.
    -- La función de confirmación deberá bloquear primero esta misma fila.
    SELECT u.email, u.estado, u.email_verificado_en
    INTO v_correo, v_estado, v_verificado_en
    FROM public.usuario AS u
    WHERE u.id = p_usuario_id
    FOR UPDATE;

    -- Sin emisión para cuentas inexistentes, bloqueadas o verificadas.
    IF NOT FOUND
       OR v_estado <> 'pendiente'
       OR v_verificado_en IS NOT NULL THEN
        RETURN;
    END IF;

    -- Hora real tomada después de obtener el bloqueo.
    v_ahora := clock_timestamp();

    SELECT
        max(v.creado_en),
        count(*) FILTER (
            WHERE v.creado_en > v_ahora - interval '1 hour'
        )
    INTO v_ultima_emision, v_emisiones
    FROM public.verificacion_email AS v
    WHERE v.usuario_id = p_usuario_id;

    -- Si se alcanza un límite, no modifica tokens existentes.
    IF v_ultima_emision > v_ahora - interval '1 minute'
       OR v_emisiones >= 5 THEN
        RETURN;
    END IF;

    -- 32 bytes aleatorios: 256 bits, representados en hexadecimal.
    v_token := encode(public.gen_random_bytes(32), 'hex');
    v_expira_en := v_ahora + interval '24 hours';

    -- Invalida los registros anteriores sin consumir ni revocar.
    UPDATE public.verificacion_email AS v
    SET revocado_en = v_ahora
    WHERE v.usuario_id = p_usuario_id
      AND v.consumido_en IS NULL
      AND v.revocado_en IS NULL;

    -- Solo el hash queda almacenado.
    INSERT INTO public.verificacion_email (
        usuario_id, token_hash, creado_en, expira_en
    )
    VALUES (
        p_usuario_id,
        encode(public.digest(v_token, 'sha256'), 'hex'),
        v_ahora,
        v_expira_en
    );

    RETURN QUERY SELECT v_correo, v_token, v_expira_en;
END;
$$;

CREATE FUNCTION public.confirmar_email(p_token text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_hash text;
    v_usuario_id uuid;
    v_estado text;
    v_verificado_en timestamptz;
    v_solicitud public.verificacion_email%ROWTYPE;
    v_ahora timestamptz;
BEGIN
    -- Rechaza entradas fuera del formato emitido.
    IF p_token IS NULL OR p_token !~ '^[0-9a-f]{64}$' THEN
        RETURN false;
    END IF;

    v_hash := encode(public.digest(p_token, 'sha256'), 'hex');

    SELECT v.usuario_id INTO v_usuario_id
    FROM public.verificacion_email AS v
    WHERE v.token_hash = v_hash;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Mismo orden de bloqueo que la emisión: primero usuario.
    SELECT u.estado, u.email_verificado_en
    INTO v_estado, v_verificado_en
    FROM public.usuario AS u
    WHERE u.id = v_usuario_id
    FOR UPDATE;

    IF NOT FOUND
       OR v_estado <> 'pendiente'
       OR v_verificado_en IS NOT NULL THEN
        RETURN false;
    END IF;

    -- Relee y bloquea el token después de bloquear la cuenta.
    SELECT v.* INTO v_solicitud
    FROM public.verificacion_email AS v
    WHERE v.token_hash = v_hash
      AND v.usuario_id = v_usuario_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Comprueba el vencimiento usando la hora real tras los bloqueos.
    v_ahora := clock_timestamp();

    IF v_solicitud.consumido_en IS NOT NULL
       OR v_solicitud.revocado_en IS NOT NULL
       OR v_solicitud.creado_en > v_ahora
       OR v_solicitud.expira_en <= v_ahora THEN
        RETURN false;
    END IF;

    UPDATE public.verificacion_email
    SET consumido_en = v_ahora
    WHERE id = v_solicitud.id;

    UPDATE public.usuario
    SET email_verificado_en = v_ahora,
        estado = 'activo'
    WHERE id = v_usuario_id;

    -- Invalida cualquier otra solicitud todavía sin cerrar.
    UPDATE public.verificacion_email
    SET revocado_en = v_ahora
    WHERE usuario_id = v_usuario_id
      AND id <> v_solicitud.id
      AND consumido_en IS NULL
      AND revocado_en IS NULL;

    RETURN true;
END;
$$;

CREATE FUNCTION public.crear_sesion(p_usuario_id uuid)
RETURNS TABLE (
    sesion_id uuid,
    token_original text,
    vence_en timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_sesion_id uuid;
    v_token text;
    v_ahora timestamptz;
    v_expira_en timestamptz;
BEGIN
    -- Solo admite cuentas activas y con correo verificado.
    IF NOT EXISTS (
        SELECT 1
        FROM public.usuario AS u
        WHERE u.id = p_usuario_id
          AND u.estado = 'activo'
          AND u.email_verificado_en IS NOT NULL
    ) THEN
        RETURN;
    END IF;

    v_ahora := clock_timestamp();
    v_expira_en := v_ahora + interval '8 hours';

    -- Token aleatorio de 256 bits, representado en hexadecimal.
    v_token := encode(public.gen_random_bytes(32), 'hex');

    INSERT INTO public.sesion_usuario (
        usuario_id, token_hash, creado_en, expira_en
    )
    VALUES (
        p_usuario_id,
        encode(public.digest(v_token, 'sha256'), 'hex'),
        v_ahora,
        v_expira_en
    )
    RETURNING id INTO v_sesion_id;

    RETURN QUERY SELECT v_sesion_id, v_token, v_expira_en;
END;
$$;

CREATE OR REPLACE FUNCTION public.validar_sesion(p_token text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
    v_hash text;
    v_ahora timestamptz;
BEGIN
    IF p_token IS NULL OR p_token !~ '^[0-9a-f]{64}$' THEN
        RETURN NULL;
    END IF;

    v_hash := encode(public.digest(p_token, 'sha256'), 'hex');
    v_ahora := clock_timestamp();

    SELECT s.usuario_id INTO v_usuario_id
    FROM public.sesion_usuario AS s
    JOIN public.usuario AS u ON u.id = s.usuario_id
    WHERE s.token_hash = v_hash
      AND s.revocado_en IS NULL
      AND s.creado_en <= v_ahora
      AND s.expira_en > v_ahora
      AND u.estado = 'activo'
      AND u.email_verificado_en IS NOT NULL;

    RETURN v_usuario_id;
END;
$$;

CREATE FUNCTION public.cerrar_sesion(p_token text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_hash text;
BEGIN
    IF p_token IS NULL OR p_token !~ '^[0-9a-f]{64}$' THEN
        RETURN false;
    END IF;

    v_hash := encode(public.digest(p_token, 'sha256'), 'hex');

    -- El filtro impide cambiar la fecha de una revocación anterior.
    UPDATE public.sesion_usuario
    SET revocado_en = clock_timestamp()
    WHERE token_hash = v_hash
      AND revocado_en IS NULL;

    RETURN FOUND;
END;
$$;

CREATE FUNCTION public.obtener_mi_perfil(p_token text)
RETURNS TABLE (
    usuario_id uuid,
    email text,
    nombre varchar(100),
    edad_declarada smallint,
    edad_declarada_en timestamptz,
    nacionalidad_codigo varchar(2),
    genero_codigo varchar(30),
    genero_detalle varchar(100)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    -- Una sesión inválida no devuelve datos.
    IF v_usuario_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        u.id,
        u.email,
        u.nombre,
        p.edad_declarada,
        p.edad_declarada_en,
        p.nacionalidad_codigo,
        p.genero_codigo,
        p.genero_detalle
    FROM public.usuario AS u
    JOIN public.perfil_turista AS p ON p.usuario_id = u.id
    WHERE u.id = v_usuario_id;
END;
$$;

CREATE FUNCTION public.actualizar_mi_perfil(
    p_token text,
    p_edad integer,
    p_nacionalidad_codigo text,
    p_genero_codigo text,
    p_genero_detalle text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    -- No modifica datos si la sesión no es válida.
    IF v_usuario_id IS NULL THEN
        RETURN false;
    END IF;

    -- Valida antes de convertir integer a smallint.
    IF p_edad IS NULL OR p_edad NOT BETWEEN 0 AND 120 THEN
        RAISE EXCEPTION 'La edad debe estar entre 0 y 120'
            USING ERRCODE = '22023';
    END IF;

    -- Las restricciones de la tabla siguen aplicándose.
    -- El trigger mantiene las fechas de actualización.
    UPDATE public.perfil_turista
    SET edad_declarada = p_edad::smallint,
        nacionalidad_codigo = upper(btrim(p_nacionalidad_codigo)),
        genero_codigo = lower(btrim(p_genero_codigo)),
        genero_detalle = nullif(btrim(p_genero_detalle), '')
    WHERE usuario_id = v_usuario_id;

    RETURN FOUND;
END;
$$;

CREATE FUNCTION public.atractivo_actualizar_fecha()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- Conserva la identidad y la fecha original.
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION
            'No se puede cambiar el id ni la fecha de creación del atractivo';
    END IF;

    NEW.actualizado_en := clock_timestamp();

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.atractivo_traduccion_actualizar_fecha()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- La traducción conserva su atractivo, idioma y fecha de creación.
    IF NEW.atractivo_id IS DISTINCT FROM OLD.atractivo_id
       OR NEW.idioma_codigo IS DISTINCT FROM OLD.idioma_codigo
       OR NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION
            'No se puede cambiar el atractivo, idioma ni fecha de creación de la traducción';
    END IF;

    NEW.actualizado_en := clock_timestamp();

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.ruta_actualizar_fecha()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- Conserva la identidad y la fecha original.
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION
            'No se puede cambiar el id ni la fecha de creación de la ruta';
    END IF;

    NEW.actualizado_en := clock_timestamp();

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.ruta_traduccion_actualizar_fecha()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- Conserva la identidad de la traducción y su fecha original.
    IF NEW.ruta_id IS DISTINCT FROM OLD.ruta_id
       OR NEW.idioma_codigo IS DISTINCT FROM OLD.idioma_codigo
       OR NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION
            'No se puede cambiar la ruta, idioma ni fecha de creación de la traducción';
    END IF;

    NEW.actualizado_en := clock_timestamp();

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.ruta_parada_actualizar_fecha()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- La parada conserva su identidad, ruta y fecha de creación.
    -- Su orden y asociación con un atractivo pueden modificarse.
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.ruta_id IS DISTINCT FROM OLD.ruta_id
       OR NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION
            'No se puede cambiar el id, ruta ni fecha de creación de la parada';
    END IF;

    NEW.actualizado_en := clock_timestamp();

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.ruta_parada_traduccion_actualizar_fecha()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- Conserva la parada, el idioma y la fecha original.
    IF NEW.parada_id IS DISTINCT FROM OLD.parada_id
       OR NEW.idioma_codigo IS DISTINCT FROM OLD.idioma_codigo
       OR NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION
            'No se puede cambiar la parada, idioma ni fecha de creación de la traducción';
    END IF;

    NEW.actualizado_en := clock_timestamp();

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.comprobar_ruta_publicable(
    p_ruta_id uuid
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_duracion integer;
    v_cantidad bigint;
    v_orden_minimo integer;
    v_orden_maximo integer;
BEGIN
    SELECT duracion_estimada_minutos
    INTO v_duracion
    FROM public.ruta
    WHERE id = p_ruta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    IF v_duracion IS NULL OR v_duracion <= 0 THEN
        RAISE EXCEPTION 'La ruta requiere una duración mayor que cero'
            USING ERRCODE = '23514';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (VALUES ('es'), ('en')) AS idioma(codigo)
        WHERE NOT EXISTS (
            SELECT 1
            FROM public.ruta_traduccion AS t
            WHERE t.ruta_id = p_ruta_id
              AND t.idioma_codigo = idioma.codigo
        )
    ) THEN
        RAISE EXCEPTION
            'La ruta requiere traducciones en español e inglés'
            USING ERRCODE = '23514';
    END IF;

    SELECT count(*), min(orden), max(orden)
    INTO v_cantidad, v_orden_minimo, v_orden_maximo
    FROM public.ruta_parada
    WHERE ruta_id = p_ruta_id;

    IF v_cantidad = 0 THEN
        RAISE EXCEPTION 'La ruta requiere al menos una parada'
            USING ERRCODE = '23514';
    END IF;

    -- La restricción UNIQUE ya impide posiciones repetidas.
    IF v_orden_minimo <> 1 OR v_orden_maximo <> v_cantidad THEN
        RAISE EXCEPTION
            'Las paradas deben tener órdenes consecutivos desde 1'
            USING ERRCODE = '23514';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.ruta_parada AS p
        CROSS JOIN (VALUES ('es'), ('en')) AS idioma(codigo)
        WHERE p.ruta_id = p_ruta_id
          AND NOT EXISTS (
              SELECT 1
              FROM public.ruta_parada_traduccion AS t
              WHERE t.parada_id = p.id
                AND t.idioma_codigo = idioma.codigo
          )
    ) THEN
        RAISE EXCEPTION
            'Cada parada requiere traducciones en español e inglés'
            USING ERRCODE = '23514';
    END IF;

    -- HU-04: cada punto publicado debe incluir una imagen.
    -- No se hereda automáticamente la imagen del atractivo.
    IF EXISTS (
        SELECT 1
        FROM public.ruta_parada AS p
        WHERE p.ruta_id = p_ruta_id
          AND p.imagen_principal IS NULL
    ) THEN
        RAISE EXCEPTION 'Cada parada requiere una imagen para publicar'
            USING ERRCODE = '23514';
    END IF;

    -- Las coordenadas siguen siendo opcionales para puntos interiores.
END;
$$;

CREATE OR REPLACE FUNCTION public.ruta_comprobar_publicacion()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_estado text;
BEGIN
    -- Consulta el estado final de la ruta.
    SELECT estado INTO v_estado
    FROM public.ruta
    WHERE id = NEW.id;

    IF FOUND AND v_estado = 'publicado' THEN
        -- Exige duración, traducciones y paradas completas.
        PERFORM public.comprobar_ruta_publicable(NEW.id);

        -- Los atractivos vinculados también deben estar publicados.
        PERFORM public.comprobar_ruta_atractivos_publicados(NEW.id);
    END IF;

    RETURN NULL;
END;
$$;

CREATE FUNCTION public.ruta_traduccion_marcar_cambio()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_ruta_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_ruta_id := OLD.ruta_id;
    ELSE
        v_ruta_id := NEW.ruta_id;
    END IF;

    -- El UPDATE bloquea la fila de la ruta hasta terminar
    -- la transacción y activa su comprobación diferida.
    -- El trigger existente mantiene actualizado_en.
    UPDATE public.ruta
    SET actualizado_en = actualizado_en
    WHERE id = v_ruta_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.ruta_parada_marcar_cambio()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_ruta_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_ruta_id := OLD.ruta_id;
    ELSE
        v_ruta_id := NEW.ruta_id;
    END IF;

    -- Bloquea la ruta y activa su comprobación al finalizar.
    -- Su trigger existente actualiza la fecha.
    UPDATE public.ruta
    SET actualizado_en = actualizado_en
    WHERE id = v_ruta_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.ruta_parada_traduccion_marcar_cambio()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_parada_id uuid;
    v_ruta_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_parada_id := OLD.parada_id;
    ELSE
        v_parada_id := NEW.parada_id;
    END IF;

    SELECT ruta_id INTO v_ruta_id
    FROM public.ruta_parada
    WHERE id = v_parada_id;

    IF FOUND THEN
        UPDATE public.ruta
        SET actualizado_en = actualizado_en
        WHERE id = v_ruta_id;
    END IF;

    -- Si la parada no existe, la clave foránea
    -- rechazará la inserción o actualización.
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.exigir_administrador(p_token text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión válida'
            USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.usuario_rol AS ur
        JOIN public.rol AS r ON r.id = ur.rol_id
        WHERE ur.usuario_id = v_usuario_id
          AND r.codigo = 'administrador'
    ) THEN
        RAISE EXCEPTION 'Se requieren permisos de administrador'
            USING ERRCODE = '42501';
    END IF;

    RETURN v_usuario_id;
END;
$$;

CREATE FUNCTION public.admin_crear_ruta(p_token text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_ruta_id uuid;
BEGIN
    -- Rechaza sesiones inválidas y usuarios sin rol administrador.
    PERFORM public.exigir_administrador(p_token);

    -- Siempre comienza como borrador.
    -- Los demás campos usan sus valores por defecto.
    INSERT INTO public.ruta (estado)
    VALUES ('borrador')
    RETURNING id INTO v_ruta_id;

    RETURN v_ruta_id;
END;
$$;

CREATE FUNCTION public.admin_actualizar_ruta(
    p_token text,
    p_ruta_id uuid,
    p_duracion_estimada_minutos integer,
    p_imagen_principal text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    -- Los CHECK existentes validan duración e imagen.
    -- El trigger mantiene la fecha de actualización.
    UPDATE public.ruta
    SET duracion_estimada_minutos = p_duracion_estimada_minutos,
        imagen_principal = p_imagen_principal
    WHERE id = p_ruta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_guardar_ruta_traduccion(
    p_token text,
    p_ruta_id uuid,
    p_idioma_codigo text,
    p_nombre text,
    p_descripcion text,
    p_imagen_texto_alternativo text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    -- Valida las longitudes antes de convertir los parámetros
    -- a columnas varchar, evitando cualquier recorte explícito.
    IF char_length(p_idioma_codigo) > 2
       OR char_length(p_nombre) > 200
       OR char_length(p_imagen_texto_alternativo) > 300 THEN
        RAISE EXCEPTION 'Un texto supera la longitud permitida'
            USING ERRCODE = '22001';
    END IF;

    -- La clave compuesta identifica una traducción por ruta e idioma.
    -- ON CONFLICT permite guardarla sin crear duplicados.
    INSERT INTO public.ruta_traduccion (
        ruta_id,
        idioma_codigo,
        nombre,
        descripcion,
        imagen_texto_alternativo
    )
    VALUES (
        p_ruta_id,
        p_idioma_codigo,
        p_nombre,
        p_descripcion,
        p_imagen_texto_alternativo
    )
    ON CONFLICT (ruta_id, idioma_codigo)
    DO UPDATE SET
        nombre = EXCLUDED.nombre,
        descripcion = EXCLUDED.descripcion,
        imagen_texto_alternativo = EXCLUDED.imagen_texto_alternativo;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_crear_ruta_parada(
    p_token text,
    p_ruta_id uuid,
    p_orden integer,
    p_atractivo_id uuid,
    p_imagen_principal text,
    p_longitud double precision,
    p_latitud double precision
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_parada_id uuid;
    v_ubicacion public.geometry;
BEGIN
    PERFORM public.exigir_administrador(p_token);

    -- Rechaza ubicaciones incompletas.
    IF (p_longitud IS NULL) <> (p_latitud IS NULL) THEN
        RAISE EXCEPTION 'Longitud y latitud deben indicarse juntas'
            USING ERRCODE = '22023';
    END IF;

    IF p_longitud IS NOT NULL THEN
        -- Estos límites también rechazan Infinity y NaN.
        IF NOT (
            p_longitud BETWEEN -180 AND 180
            AND p_latitud BETWEEN -90 AND 90
        ) THEN
            RAISE EXCEPTION 'Coordenadas fuera del rango permitido'
                USING ERRCODE = '22023';
        END IF;

        -- PostGIS utiliza X = longitud, Y = latitud.
        v_ubicacion := public.ST_SetSRID(
            public.ST_MakePoint(p_longitud, p_latitud),
            4326
        );
    END IF;

    -- Las claves foráneas comprueban ruta y atractivo.
    -- CHECK valida orden e imagen; UNIQUE evita repetir posiciones.
    INSERT INTO public.ruta_parada (
        ruta_id,
        atractivo_id,
        orden,
        imagen_principal,
        ubicacion
    )
    VALUES (
        p_ruta_id,
        p_atractivo_id,
        p_orden,
        p_imagen_principal,
        v_ubicacion
    )
    RETURNING id INTO v_parada_id;

    RETURN v_parada_id;
END;
$$;

CREATE FUNCTION public.admin_guardar_parada_traduccion(
    p_token text,
    p_parada_id uuid,
    p_idioma_codigo text,
    p_nombre text,
    p_descripcion text,
    p_imagen_texto_alternativo text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF char_length(p_idioma_codigo) > 2
       OR char_length(p_nombre) > 200
       OR char_length(p_imagen_texto_alternativo) > 300 THEN
        RAISE EXCEPTION 'Un texto supera la longitud permitida'
            USING ERRCODE = '22001';
    END IF;

    -- Los CHECK validan idioma y contenido.
    -- La clave foránea exige una parada existente.
    INSERT INTO public.ruta_parada_traduccion (
        parada_id,
        idioma_codigo,
        nombre,
        descripcion,
        imagen_texto_alternativo
    )
    VALUES (
        p_parada_id,
        p_idioma_codigo,
        p_nombre,
        p_descripcion,
        p_imagen_texto_alternativo
    )
    ON CONFLICT (parada_id, idioma_codigo)
    DO UPDATE SET
        nombre = EXCLUDED.nombre,
        descripcion = EXCLUDED.descripcion,
        imagen_texto_alternativo = EXCLUDED.imagen_texto_alternativo;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_publicar_ruta(
    p_token text,
    p_ruta_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    -- Coordina la publicación con otras ediciones de la ruta.
    PERFORM 1
    FROM public.ruta
    WHERE id = p_ruta_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    -- Revisa duración, traducciones y paradas antes de publicar.
    PERFORM public.comprobar_ruta_publicable(p_ruta_id);

    UPDATE public.ruta
    SET estado = 'publicado'
    WHERE id = p_ruta_id;

    -- El trigger diferido también comprobará el estado final
    -- si después se modifica contenido en esta transacción.
    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_retirar_ruta(
    p_token text,
    p_ruta_id uuid,
    p_estado_destino text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    -- Esta operación nunca permite publicar.
    IF p_estado_destino IS NULL
       OR p_estado_destino NOT IN ('borrador', 'archivado') THEN
        RAISE EXCEPTION 'El destino debe ser borrador o archivado'
            USING ERRCODE = '22023';
    END IF;

    -- El UPDATE bloquea la ruta y mantiene sus datos relacionados.
    -- El trigger existente actualiza la fecha.
    UPDATE public.ruta
    SET estado = p_estado_destino
    WHERE id = p_ruta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_actualizar_ruta_parada(
    p_token text,
    p_parada_id uuid,
    p_atractivo_id uuid,
    p_imagen_principal text,
    p_longitud double precision,
    p_latitud double precision
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_ubicacion public.geometry;
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF (p_longitud IS NULL) <> (p_latitud IS NULL) THEN
        RAISE EXCEPTION 'Longitud y latitud deben indicarse juntas'
            USING ERRCODE = '22023';
    END IF;

    IF p_longitud IS NOT NULL THEN
        IF NOT (
            p_longitud BETWEEN -180 AND 180
            AND p_latitud BETWEEN -90 AND 90
        ) THEN
            RAISE EXCEPTION 'Coordenadas fuera del rango permitido'
                USING ERRCODE = '22023';
        END IF;

        v_ubicacion := public.ST_SetSRID(
            public.ST_MakePoint(p_longitud, p_latitud),
            4326
        );
    END IF;

    -- La FK valida el atractivo y los CHECK validan los datos.
    -- Los triggers mantienen las fechas y revisan la publicación.
    UPDATE public.ruta_parada
    SET atractivo_id = p_atractivo_id,
        imagen_principal = p_imagen_principal,
        ubicacion = v_ubicacion
    WHERE id = p_parada_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La parada no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_reordenar_ruta_paradas(
    p_token text,
    p_ruta_id uuid,
    p_paradas uuid[]
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_cantidad bigint;
    v_coincidentes bigint;
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_paradas IS NULL
       OR coalesce(array_ndims(p_paradas), 1) <> 1 THEN
        RAISE EXCEPTION 'Se requiere una lista de paradas de una dimensión'
            USING ERRCODE = '22023';
    END IF;

    -- Coordina el reordenamiento con las demás ediciones de la ruta.
    PERFORM 1
    FROM public.ruta
    WHERE id = p_ruta_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    -- COUNT DISTINCT no cuenta NULL y elimina repeticiones.
    -- Debe coincidir con la cantidad total de elementos recibidos.
    SELECT count(DISTINCT elemento.id)
    INTO v_coincidentes
    FROM unnest(p_paradas) AS elemento(id);

    IF v_coincidentes <> cardinality(p_paradas) THEN
        RAISE EXCEPTION 'La lista contiene identificadores nulos o repetidos'
            USING ERRCODE = '22023';
    END IF;

    SELECT count(*) INTO v_cantidad
    FROM public.ruta_parada
    WHERE ruta_id = p_ruta_id;

    SELECT count(*) INTO v_coincidentes
    FROM public.ruta_parada
    WHERE ruta_id = p_ruta_id
      AND id = ANY (p_paradas);

    IF cardinality(p_paradas) <> v_cantidad
       OR v_coincidentes <> v_cantidad THEN
        RAISE EXCEPTION 'La lista debe contener todas y solo las paradas de esta ruta'
            USING ERRCODE = '22023';
    END IF;

    -- Cambia todas las posiciones en una sola instrucción.
    -- WITH ORDINALITY numera desde 1 según el orden de la lista.
    UPDATE public.ruta_parada AS p
    SET orden = lista.posicion::integer
    FROM unnest(p_paradas) WITH ORDINALITY AS lista(id, posicion)
    WHERE p.ruta_id = p_ruta_id
      AND p.id = lista.id;

    RETURN true;
END;
$$;

CREATE FUNCTION public.listar_rutas_publicadas(
    p_idioma_codigo text
)
RETURNS TABLE (
    ruta_id uuid,
    idioma_codigo text,
    nombre text,
    descripcion text,
    duracion_estimada_minutos integer,
    imagen_principal text,
    imagen_texto_alternativo text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        r.id,
        t.idioma_codigo::text,
        t.nombre::text,
        t.descripcion,
        r.duracion_estimada_minutos,
        r.imagen_principal,
        t.imagen_texto_alternativo::text
    FROM public.ruta AS r
    JOIN public.ruta_traduccion AS t
        ON t.ruta_id = r.id
    WHERE r.estado = 'publicado'
      AND t.idioma_codigo = p_idioma_codigo
    ORDER BY t.nombre, r.id;
END;
$$;

CREATE FUNCTION public.listar_paradas_ruta_publicada(
    p_ruta_id uuid,
    p_idioma_codigo text
)
RETURNS TABLE (
    parada_id uuid,
    ruta_id uuid,
    atractivo_id uuid,
    orden integer,
    idioma_codigo text,
    nombre text,
    descripcion text,
    imagen_principal text,
    imagen_texto_alternativo text,
    longitud double precision,
    latitud double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    IF p_ruta_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere el identificador de la ruta'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.ruta_id,
        p.atractivo_id,
        p.orden,
        t.idioma_codigo::text,
        t.nombre::text,
        t.descripcion,
        p.imagen_principal,
        t.imagen_texto_alternativo::text,
        public.ST_X(p.ubicacion),
        public.ST_Y(p.ubicacion)
    FROM public.ruta AS r
    JOIN public.ruta_parada AS p
        ON p.ruta_id = r.id
    JOIN public.ruta_parada_traduccion AS t
        ON t.parada_id = p.id
    WHERE r.id = p_ruta_id
      AND r.estado = 'publicado'
      AND t.idioma_codigo = p_idioma_codigo
    ORDER BY p.orden;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_eliminar_ruta_parada(
    p_token text,
    p_parada_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_ruta_id uuid;
    v_estado text;
BEGIN
    PERFORM public.exigir_administrador(p_token);

    SELECT ruta_id INTO v_ruta_id
    FROM public.ruta_parada
    WHERE id = p_parada_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La parada no existe'
            USING ERRCODE = '23503';
    END IF;

    -- Bloquea la ruta antes de eliminar y reordenar.
    SELECT estado INTO v_estado
    FROM public.ruta
    WHERE id = v_ruta_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    IF v_estado IS DISTINCT FROM 'borrador' THEN
        RAISE EXCEPTION 'La ruta debe estar en borrador para eliminar paradas'
            USING ERRCODE = '22023';
    END IF;

    -- Elimina primero los registros que referencian la parada.
    -- Si el borrado de la parada falla, también se deshacen estos cambios.
    DELETE FROM public.qr_parada
    WHERE parada_id = p_parada_id;

    DELETE FROM public.ruta_parada_traduccion
    WHERE parada_id = p_parada_id;

    -- La protección de recorridos abiertos se aplica automáticamente.
    -- En recorridos cerrados, la FK conserva el paso con origen NULL.
    DELETE FROM public.ruta_parada
    WHERE id = p_parada_id
      AND ruta_id = v_ruta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La parada ya no existe'
            USING ERRCODE = '23503';
    END IF;

    -- Conserva el orden relativo y elimina los huecos.
    WITH posiciones AS (
        SELECT
            id,
            row_number() OVER (ORDER BY orden)::integer AS nuevo_orden
        FROM public.ruta_parada
        WHERE ruta_id = v_ruta_id
    )
    UPDATE public.ruta_parada AS p
    SET orden = posiciones.nuevo_orden
    FROM posiciones
    WHERE p.id = posiciones.id
      AND p.orden <> posiciones.nuevo_orden;

    RETURN true;
END;
$$;

CREATE FUNCTION public.asignar_administrador_inicial(
    p_usuario_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_rol_id uuid;
    v_estado text;
    v_verificado_en timestamptz;
BEGIN
    -- Bloquea el rol para coordinar llamadas simultáneas
    -- a esta función de preparación inicial.
    SELECT id INTO STRICT v_rol_id
    FROM public.rol
    WHERE codigo = 'administrador'
    FOR UPDATE;

    IF EXISTS (
        SELECT 1
        FROM public.usuario_rol
        WHERE rol_id = v_rol_id
    ) THEN
        RAISE EXCEPTION 'Ya existe una asignación de administrador'
            USING ERRCODE = '22023';
    END IF;

    SELECT estado, email_verificado_en
    INTO v_estado, v_verificado_en
    FROM public.usuario
    WHERE id = p_usuario_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario no existe'
            USING ERRCODE = '23503';
    END IF;

    IF v_estado IS DISTINCT FROM 'activo'
       OR v_verificado_en IS NULL THEN
        RAISE EXCEPTION 'La cuenta debe estar activa y con correo verificado'
            USING ERRCODE = '22023';
    END IF;

    -- Conserva los demás roles que ya tenga la cuenta.
    INSERT INTO public.usuario_rol (usuario_id, rol_id)
    VALUES (p_usuario_id, v_rol_id);

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_crear_atractivo(p_token text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_atractivo_id uuid;
BEGIN
    PERFORM public.exigir_administrador(p_token);

    -- El cliente no elige el estado inicial.
    INSERT INTO public.atractivo (estado)
    VALUES ('borrador')
    RETURNING id INTO v_atractivo_id;

    RETURN v_atractivo_id;
END;
$$;

CREATE FUNCTION public.admin_actualizar_atractivo(
    p_token text,
    p_atractivo_id uuid,
    p_imagen_principal text,
    p_longitud double precision,
    p_latitud double precision
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_ubicacion public.geometry;
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF (p_longitud IS NULL) <> (p_latitud IS NULL) THEN
        RAISE EXCEPTION 'Longitud y latitud deben indicarse juntas'
            USING ERRCODE = '22023';
    END IF;

    IF p_longitud IS NOT NULL THEN
        IF NOT (
            p_longitud BETWEEN -180 AND 180
            AND p_latitud BETWEEN -90 AND 90
        ) THEN
            RAISE EXCEPTION 'Coordenadas fuera del rango permitido'
                USING ERRCODE = '22023';
        END IF;

        v_ubicacion := public.ST_SetSRID(
            public.ST_MakePoint(p_longitud, p_latitud),
            4326
        );
    END IF;

    -- Los CHECK validan la referencia de imagen, ubicación
    -- y los datos básicos exigidos para un atractivo publicado.
    -- El trigger existente mantiene actualizado_en.
    UPDATE public.atractivo
    SET imagen_principal = p_imagen_principal,
        ubicacion = v_ubicacion
    WHERE id = p_atractivo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El atractivo no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_guardar_atractivo_traduccion(
    p_token text,
    p_atractivo_id uuid,
    p_idioma_codigo text,
    p_nombre text,
    p_descripcion text,
    p_imagen_texto_alternativo text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF char_length(p_idioma_codigo) > 2
       OR char_length(p_nombre) > 200
       OR char_length(p_imagen_texto_alternativo) > 300 THEN
        RAISE EXCEPTION 'Un texto supera la longitud permitida'
            USING ERRCODE = '22001';
    END IF;

    -- Los CHECK validan idioma y contenido.
    -- La clave foránea exige un atractivo existente.
    INSERT INTO public.atractivo_traduccion (
        atractivo_id,
        idioma_codigo,
        nombre,
        descripcion,
        imagen_texto_alternativo
    )
    VALUES (
        p_atractivo_id,
        p_idioma_codigo,
        p_nombre,
        p_descripcion,
        p_imagen_texto_alternativo
    )
    ON CONFLICT (atractivo_id, idioma_codigo)
    DO UPDATE SET
        nombre = EXCLUDED.nombre,
        descripcion = EXCLUDED.descripcion,
        imagen_texto_alternativo = EXCLUDED.imagen_texto_alternativo;

    RETURN true;
END;
$$;

CREATE FUNCTION public.comprobar_atractivo_publicable(
    p_atractivo_id uuid
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_imagen text;
    v_ubicacion public.geometry;
BEGIN
    SELECT imagen_principal, ubicacion
    INTO v_imagen, v_ubicacion
    FROM public.atractivo
    WHERE id = p_atractivo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El atractivo no existe'
            USING ERRCODE = '23503';
    END IF;

    -- Los CHECK existentes validan la referencia de imagen
    -- y el tipo y rango de la ubicación.
    IF v_imagen IS NULL OR v_ubicacion IS NULL THEN
        RAISE EXCEPTION 'El atractivo requiere imagen y ubicación'
            USING ERRCODE = '23514';
    END IF;

    -- Los CHECK de traducciones ya exigen textos con contenido.
    IF EXISTS (
        SELECT 1
        FROM (VALUES ('es'), ('en')) AS idioma(codigo)
        WHERE NOT EXISTS (
            SELECT 1
            FROM public.atractivo_traduccion AS t
            WHERE t.atractivo_id = p_atractivo_id
              AND t.idioma_codigo = idioma.codigo
        )
    ) THEN
        RAISE EXCEPTION
            'El atractivo requiere traducciones en español e inglés'
            USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.atractivo_comprobar_publicacion()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_estado text;
BEGIN
    -- Consulta el estado final del atractivo.
    SELECT estado INTO v_estado
    FROM public.atractivo
    WHERE id = NEW.id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF v_estado = 'publicado' THEN
        -- Conserva la comprobación de imagen, ubicación e idiomas.
        PERFORM public.comprobar_atractivo_publicable(NEW.id);
    ELSE
        -- Impide retirarlo si una ruta publicada conserva el vínculo.
        IF EXISTS (
            SELECT 1
            FROM public.ruta_parada AS p
            JOIN public.ruta AS r ON r.id = p.ruta_id
            WHERE p.atractivo_id = NEW.id
              AND r.estado = 'publicado'
        ) THEN
            RAISE EXCEPTION
                'El atractivo está vinculado a una ruta publicada; retire o modifique esa ruta primero'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

CREATE FUNCTION public.atractivo_traduccion_marcar_cambio()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_atractivo_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_atractivo_id := OLD.atractivo_id;
    ELSE
        v_atractivo_id := NEW.atractivo_id;
    END IF;

    -- Bloquea y actualiza el atractivo, activando su revisión.
    -- El trigger de fechas mantiene actualizado_en.
    UPDATE public.atractivo
    SET actualizado_en = actualizado_en
    WHERE id = v_atractivo_id;

    RETURN NULL;
END;
$$;

CREATE FUNCTION public.admin_publicar_atractivo(
    p_token text,
    p_atractivo_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    -- Coordina la publicación con otras ediciones del atractivo.
    PERFORM 1
    FROM public.atractivo
    WHERE id = p_atractivo_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El atractivo no existe'
            USING ERRCODE = '23503';
    END IF;

    PERFORM public.comprobar_atractivo_publicable(p_atractivo_id);

    UPDATE public.atractivo
    SET estado = 'publicado'
    WHERE id = p_atractivo_id;

    -- La revisión diferida también protege el estado final
    -- si se realizan más cambios en esta transacción.
    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_retirar_atractivo(
    p_token text,
    p_atractivo_id uuid,
    p_estado_destino text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_estado_destino IS NULL
       OR p_estado_destino NOT IN ('borrador', 'archivado') THEN
        RAISE EXCEPTION 'El destino debe ser borrador o archivado'
            USING ERRCODE = '22023';
    END IF;

    -- Cambia únicamente el estado.
    -- Conserva traducciones, categorías y vínculos de paradas.
    UPDATE public.atractivo
    SET estado = p_estado_destino
    WHERE id = p_atractivo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El atractivo no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_crear_categoria_atractivo(
    p_token text,
    p_codigo text,
    p_icono_codigo text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_categoria_id uuid;
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF char_length(p_codigo) > 50
       OR char_length(p_icono_codigo) > 50 THEN
        RAISE EXCEPTION 'El código supera la longitud permitida'
            USING ERRCODE = '22001';
    END IF;

    -- Los CHECK validan el formato de los códigos.
    -- UNIQUE impide repetir el código de categoría.
    INSERT INTO public.categoria_atractivo (
        codigo, icono_codigo, activo
    )
    VALUES (
        p_codigo, p_icono_codigo, false
    )
    RETURNING id INTO v_categoria_id;

    RETURN v_categoria_id;
END;
$$;

CREATE FUNCTION public.admin_guardar_categoria_traduccion(
    p_token text,
    p_categoria_id uuid,
    p_idioma_codigo text,
    p_nombre text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF char_length(p_idioma_codigo) > 2
       OR char_length(p_nombre) > 100 THEN
        RAISE EXCEPTION 'Un texto supera la longitud permitida'
            USING ERRCODE = '22001';
    END IF;

    -- Los CHECK validan idioma y nombre.
    -- La FK exige una categoría existente.
    INSERT INTO public.categoria_atractivo_traduccion (
        categoria_id, idioma_codigo, nombre
    )
    VALUES (
        p_categoria_id, p_idioma_codigo, p_nombre
    )
    ON CONFLICT (categoria_id, idioma_codigo)
    DO UPDATE SET
        nombre = EXCLUDED.nombre;

    RETURN true;
END;
$$;

CREATE FUNCTION public.comprobar_categoria_activable(
    p_categoria_id uuid
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM 1
    FROM public.categoria_atractivo
    WHERE id = p_categoria_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La categoría no existe'
            USING ERRCODE = '23503';
    END IF;

    -- Los CHECK existentes ya exigen nombres con contenido.
    IF EXISTS (
        SELECT 1
        FROM (VALUES ('es'), ('en')) AS idioma(codigo)
        WHERE NOT EXISTS (
            SELECT 1
            FROM public.categoria_atractivo_traduccion AS t
            WHERE t.categoria_id = p_categoria_id
              AND t.idioma_codigo = idioma.codigo
        )
    ) THEN
        RAISE EXCEPTION
            'La categoría requiere traducciones en español e inglés'
            USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE FUNCTION public.categoria_comprobar_activacion()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_activo boolean;
BEGIN
    SELECT activo INTO v_activo
    FROM public.categoria_atractivo
    WHERE id = NEW.id;

    IF FOUND AND v_activo THEN
        PERFORM public.comprobar_categoria_activable(NEW.id);
    END IF;

    RETURN NULL;
END;
$$;

CREATE FUNCTION public.categoria_traduccion_marcar_cambio()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_categoria_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_categoria_id := OLD.categoria_id;
    ELSE
        v_categoria_id := NEW.categoria_id;
    END IF;

    UPDATE public.categoria_atractivo
    SET activo = activo
    WHERE id = v_categoria_id;

    RETURN NULL;
END;
$$;

CREATE FUNCTION public.admin_cambiar_activacion_categoria(
    p_token text,
    p_categoria_id uuid,
    p_activo boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_activo IS NULL THEN
        RAISE EXCEPTION 'Debe indicar true o false'
            USING ERRCODE = '22023';
    END IF;

    -- Coordina la activación con las ediciones de traducciones.
    PERFORM 1
    FROM public.categoria_atractivo
    WHERE id = p_categoria_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La categoría no existe'
            USING ERRCODE = '23503';
    END IF;

    IF p_activo THEN
        PERFORM public.comprobar_categoria_activable(p_categoria_id);
    END IF;

    UPDATE public.categoria_atractivo
    SET activo = p_activo
    WHERE id = p_categoria_id;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_asignar_categoria_atractivo(
    p_token text,
    p_atractivo_id uuid,
    p_categoria_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_atractivo_id IS NULL OR p_categoria_id IS NULL THEN
        RAISE EXCEPTION 'Se requieren los identificadores del atractivo y categoría'
            USING ERRCODE = '22023';
    END IF;

    -- Las claves foráneas exigen que ambos registros existan.
    -- La clave primaria compuesta evita repetir el vínculo.
    INSERT INTO public.atractivo_categoria (
        atractivo_id, categoria_id
    )
    VALUES (
        p_atractivo_id, p_categoria_id
    )
    ON CONFLICT (atractivo_id, categoria_id)
    DO NOTHING;

    -- true: vínculo creado; false: ya existía.
    RETURN FOUND;
END;
$$;

CREATE FUNCTION public.admin_quitar_categoria_atractivo(
    p_token text,
    p_atractivo_id uuid,
    p_categoria_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_atractivo_id IS NULL OR p_categoria_id IS NULL THEN
        RAISE EXCEPTION
            'Se requieren los identificadores del atractivo y categoría'
            USING ERRCODE = '22023';
    END IF;

    -- Borra solo la relación entre ambos registros.
    DELETE FROM public.atractivo_categoria
    WHERE atractivo_id = p_atractivo_id
      AND categoria_id = p_categoria_id;

    -- true: vínculo eliminado; false: no existía.
    RETURN FOUND;
END;
$$;

CREATE FUNCTION public.listar_categorias_activas(
    p_idioma_codigo text
)
RETURNS TABLE (
    categoria_id uuid,
    codigo text,
    icono_codigo text,
    idioma_codigo text,
    nombre text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.codigo::text,
        c.icono_codigo::text,
        t.idioma_codigo::text,
        t.nombre::text
    FROM public.categoria_atractivo AS c
    JOIN public.categoria_atractivo_traduccion AS t
        ON t.categoria_id = c.id
    WHERE c.activo = true
      AND t.idioma_codigo = p_idioma_codigo
    ORDER BY t.nombre, c.id;
END;
$$;

CREATE FUNCTION public.listar_atractivos_publicados(
    p_idioma_codigo text,
    p_categoria_id uuid DEFAULT NULL
)
RETURNS TABLE (
    atractivo_id uuid,
    idioma_codigo text,
    nombre text,
    descripcion text,
    imagen_principal text,
    imagen_texto_alternativo text,
    longitud double precision,
    latitud double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        a.id,
        t.idioma_codigo::text,
        t.nombre::text,
        t.descripcion,
        a.imagen_principal,
        t.imagen_texto_alternativo::text,
        public.ST_X(a.ubicacion),
        public.ST_Y(a.ubicacion)
    FROM public.atractivo AS a
    JOIN public.atractivo_traduccion AS t
        ON t.atractivo_id = a.id
    WHERE a.estado = 'publicado'
      AND t.idioma_codigo = p_idioma_codigo
      AND (
          p_categoria_id IS NULL
          OR EXISTS (
              SELECT 1
              FROM public.atractivo_categoria AS ac
              JOIN public.categoria_atractivo AS c
                  ON c.id = ac.categoria_id
              WHERE ac.atractivo_id = a.id
                AND c.id = p_categoria_id
                AND c.activo = true
          )
      )
    ORDER BY t.nombre, a.id;
END;
$$;

CREATE FUNCTION public.listar_categorias_atractivo_publicado(
    p_atractivo_id uuid,
    p_idioma_codigo text
)
RETURNS TABLE (
    categoria_id uuid,
    codigo text,
    icono_codigo text,
    idioma_codigo text,
    nombre text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    IF p_atractivo_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere el identificador del atractivo'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.codigo::text,
        c.icono_codigo::text,
        t.idioma_codigo::text,
        t.nombre::text
    FROM public.atractivo AS a
    JOIN public.atractivo_categoria AS ac
        ON ac.atractivo_id = a.id
    JOIN public.categoria_atractivo AS c
        ON c.id = ac.categoria_id
    JOIN public.categoria_atractivo_traduccion AS t
        ON t.categoria_id = c.id
    WHERE a.id = p_atractivo_id
      AND a.estado = 'publicado'
      AND c.activo = true
      AND t.idioma_codigo = p_idioma_codigo
    ORDER BY t.nombre, c.id;
END;
$$;

CREATE FUNCTION public.admin_listar_atractivos(
    p_token text,
    p_idioma_codigo text
)
RETURNS TABLE (
    atractivo_id uuid,
    estado text,
    idioma_codigo text,
    nombre text,
    descripcion text,
    imagen_principal text,
    imagen_texto_alternativo text,
    longitud double precision,
    latitud double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        a.id,
        a.estado::text,
        p_idioma_codigo,
        t.nombre::text,
        t.descripcion,
        a.imagen_principal,
        t.imagen_texto_alternativo::text,
        public.ST_X(a.ubicacion),
        public.ST_Y(a.ubicacion)
    FROM public.atractivo AS a
    LEFT JOIN public.atractivo_traduccion AS t
        ON t.atractivo_id = a.id
       AND t.idioma_codigo = p_idioma_codigo
    ORDER BY t.nombre NULLS LAST, a.id;
END;
$$;

CREATE FUNCTION public.admin_listar_categorias_atractivo(
    p_token text,
    p_idioma_codigo text
)
RETURNS TABLE (
    categoria_id uuid,
    codigo text,
    icono_codigo text,
    activo boolean,
    idioma_codigo text,
    nombre text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.codigo::text,
        c.icono_codigo::text,
        c.activo,
        p_idioma_codigo,
        t.nombre::text
    FROM public.categoria_atractivo AS c
    LEFT JOIN public.categoria_atractivo_traduccion AS t
        ON t.categoria_id = c.id
       AND t.idioma_codigo = p_idioma_codigo
    ORDER BY t.nombre NULLS LAST, c.id;
END;
$$;

CREATE FUNCTION public.admin_actualizar_icono_categoria(
    p_token text,
    p_categoria_id uuid,
    p_icono_codigo text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF char_length(p_icono_codigo) > 50 THEN
        RAISE EXCEPTION 'El código de icono supera la longitud permitida'
            USING ERRCODE = '22001';
    END IF;

    -- NOT NULL y CHECK validan el formato.
    -- La revisión de categorías activas sigue aplicándose.
    UPDATE public.categoria_atractivo
    SET icono_codigo = p_icono_codigo
    WHERE id = p_categoria_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La categoría no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN true;
END;
$$;

CREATE FUNCTION public.admin_listar_rutas(
    p_token text,
    p_idioma_codigo text
)
RETURNS TABLE (
    ruta_id uuid,
    estado text,
    idioma_codigo text,
    nombre text,
    descripcion text,
    duracion_estimada_minutos integer,
    imagen_principal text,
    imagen_texto_alternativo text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        r.id,
        r.estado::text,
        p_idioma_codigo,
        t.nombre::text,
        t.descripcion,
        r.duracion_estimada_minutos,
        r.imagen_principal,
        t.imagen_texto_alternativo::text
    FROM public.ruta AS r
    LEFT JOIN public.ruta_traduccion AS t
        ON t.ruta_id = r.id
       AND t.idioma_codigo = p_idioma_codigo
    ORDER BY t.nombre NULLS LAST, r.id;
END;
$$;

CREATE FUNCTION public.admin_listar_ruta_paradas(
    p_token text,
    p_ruta_id uuid,
    p_idioma_codigo text
)
RETURNS TABLE (
    parada_id uuid,
    ruta_id uuid,
    atractivo_id uuid,
    orden integer,
    idioma_codigo text,
    nombre text,
    descripcion text,
    imagen_principal text,
    imagen_texto_alternativo text,
    longitud double precision,
    latitud double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    PERFORM 1 FROM public.ruta
    WHERE id = p_ruta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.ruta_id,
        p.atractivo_id,
        p.orden,
        p_idioma_codigo,
        t.nombre::text,
        t.descripcion,
        p.imagen_principal,
        t.imagen_texto_alternativo::text,
        public.ST_X(p.ubicacion),
        public.ST_Y(p.ubicacion)
    FROM public.ruta_parada AS p
    LEFT JOIN public.ruta_parada_traduccion AS t
        ON t.parada_id = p.id
       AND t.idioma_codigo = p_idioma_codigo
    WHERE p.ruta_id = p_ruta_id
    ORDER BY p.orden;
END;
$$;

CREATE FUNCTION public.admin_listar_categorias_atractivo_asignadas(
    p_token text,
    p_atractivo_id uuid,
    p_idioma_codigo text
)
RETURNS TABLE (
    categoria_id uuid,
    codigo text,
    icono_codigo text,
    activo boolean,
    idioma_codigo text,
    nombre text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'El idioma debe ser es o en'
            USING ERRCODE = '22023';
    END IF;

    PERFORM 1
    FROM public.atractivo
    WHERE id = p_atractivo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El atractivo no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.codigo::text,
        c.icono_codigo::text,
        c.activo,
        p_idioma_codigo,
        t.nombre::text
    FROM public.atractivo_categoria AS ac
    JOIN public.categoria_atractivo AS c
        ON c.id = ac.categoria_id
    LEFT JOIN public.categoria_atractivo_traduccion AS t
        ON t.categoria_id = c.id
       AND t.idioma_codigo = p_idioma_codigo
    WHERE ac.atractivo_id = p_atractivo_id
    ORDER BY t.nombre NULLS LAST, c.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.comprobar_ruta_atractivos_publicados(
    p_ruta_id uuid
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_atractivo_id uuid;
BEGIN
    PERFORM 1
    FROM public.ruta
    WHERE id = p_ruta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    -- Coordina con las transacciones que editan o retiran
    -- estos atractivos. Usa un orden estable entre sus identificadores.
    FOR v_atractivo_id IN
        SELECT DISTINCT p.atractivo_id
        FROM public.ruta_parada AS p
        WHERE p.ruta_id = p_ruta_id
          AND p.atractivo_id IS NOT NULL
        ORDER BY p.atractivo_id
    LOOP
        -- La actualización bloquea y escribe la fila.
        -- El trigger existente actualiza su fecha.
        UPDATE public.atractivo
        SET actualizado_en = actualizado_en
        WHERE id = v_atractivo_id;
    END LOOP;

    -- Comprueba el estado después de obtener los bloqueos.
    -- Las paradas sin atractivo vinculado siguen permitidas.
    IF EXISTS (
        SELECT 1
        FROM public.ruta_parada AS p
        JOIN public.atractivo AS a
            ON a.id = p.atractivo_id
        WHERE p.ruta_id = p_ruta_id
          AND a.estado <> 'publicado'
    ) THEN
        RAISE EXCEPTION
            'La ruta contiene paradas vinculadas a atractivos no publicados'
            USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.recorrido_parada_validar()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_ruta_id uuid;
    v_ruta_parada_id uuid;
    v_estado text;
    v_iniciado_en timestamptz;
    v_pasos_fijados boolean;
BEGIN
    -- Coordina el progreso con la fijación y el cierre del intento.
    SELECT ruta_id, estado, iniciado_en, pasos_fijados
    INTO v_ruta_id, v_estado, v_iniciado_en, v_pasos_fijados
    FROM public.recorrido_usuario
    WHERE id = NEW.recorrido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El recorrido no existe'
            USING ERRCODE = '23503';
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF v_estado <> 'en_curso' OR v_pasos_fijados THEN
            RAISE EXCEPTION 'No se pueden añadir pasos a una lista fijada o un recorrido cerrado'
                USING ERRCODE = '23514';
        END IF;

        IF NEW.registrado_en IS NOT NULL THEN
            RAISE EXCEPTION 'Los pasos deben crearse pendientes'
                USING ERRCODE = '23514';
        END IF;

        IF NEW.parada_id IS NULL THEN
            RAISE EXCEPTION 'La parada original es obligatoria al crear el paso'
                USING ERRCODE = '23514';
        END IF;

        SELECT ruta_id INTO v_ruta_parada_id
        FROM public.ruta_parada
        WHERE id = NEW.parada_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'La parada original no existe'
                USING ERRCODE = '23503';
        END IF;

        IF v_ruta_parada_id IS DISTINCT FROM v_ruta_id THEN
            RAISE EXCEPTION 'La parada no pertenece a la ruta del recorrido'
                USING ERRCODE = '23514';
        END IF;
    ELSE
        IF NEW.id IS DISTINCT FROM OLD.id
           OR NEW.recorrido_id IS DISTINCT FROM OLD.recorrido_id
           OR NEW.orden IS DISTINCT FROM OLD.orden THEN
            RAISE EXCEPTION 'No se puede cambiar la identidad ni el orden del paso'
                USING ERRCODE = '23514';
        END IF;

        -- Permite ON DELETE SET NULL, sin sustituir el origen.
        IF NEW.parada_id IS DISTINCT FROM OLD.parada_id
           AND NEW.parada_id IS NOT NULL THEN
            RAISE EXCEPTION 'No se puede sustituir la parada original'
                USING ERRCODE = '23514';
        END IF;

        IF NEW.registrado_en IS DISTINCT FROM OLD.registrado_en THEN
            IF v_estado <> 'en_curso' OR NOT v_pasos_fijados THEN
                RAISE EXCEPTION 'Registrar progreso requiere un recorrido en curso con su lista fijada'
                    USING ERRCODE = '23514';
            END IF;

            IF OLD.registrado_en IS NOT NULL THEN
                RAISE EXCEPTION 'No se puede reemplazar ni borrar un registro realizado'
                    USING ERRCODE = '23514';
            END IF;
        END IF;
    END IF;

    IF NEW.registrado_en IS NOT NULL THEN
        IF NOT isfinite(NEW.registrado_en)
           OR NEW.registrado_en < v_iniciado_en
           OR NEW.registrado_en > clock_timestamp() THEN
            RAISE EXCEPTION 'La fecha de registro debe estar entre el inicio y la hora actual'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.recorrido_usuario_validar_cambio()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- Conserva la identidad histórica del intento.
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.usuario_id IS DISTINCT FROM OLD.usuario_id
       OR NEW.ruta_id IS DISTINCT FROM OLD.ruta_id
       OR NEW.iniciado_en IS DISTINCT FROM OLD.iniciado_en THEN
        RAISE EXCEPTION
            'No se puede cambiar la identidad, ruta ni inicio del recorrido'
            USING ERRCODE = '23514';
    END IF;

    -- Una vez cerrado, el resultado y su fecha son definitivos.
    IF OLD.estado <> 'en_curso' THEN
        IF NEW.estado IS DISTINCT FROM OLD.estado
           OR NEW.finalizado_en IS DISTINCT FROM OLD.finalizado_en THEN
            RAISE EXCEPTION 'No se puede modificar el cierre del recorrido'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF NEW.estado IN ('completado', 'abandonado') THEN
        IF NEW.finalizado_en IS NULL
           OR NOT isfinite(NEW.finalizado_en)
           OR NEW.finalizado_en < NEW.iniciado_en
           OR NEW.finalizado_en > clock_timestamp() THEN
            RAISE EXCEPTION 'La fecha de cierre es inválida'
                USING ERRCODE = '23514';
        END IF;

        -- Ningún paso puede haberse registrado después del cierre.
        IF EXISTS (
            SELECT 1
            FROM public.recorrido_parada
            WHERE recorrido_id = NEW.id
              AND registrado_en > NEW.finalizado_en
        ) THEN
            RAISE EXCEPTION 'El cierre no puede ser anterior al registro de un paso'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF NEW.estado = 'completado' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM public.recorrido_parada
            WHERE recorrido_id = NEW.id
        ) OR EXISTS (
            SELECT 1
            FROM public.recorrido_parada
            WHERE recorrido_id = NEW.id
              AND registrado_en IS NULL
        ) THEN
            RAISE EXCEPTION
                'Completar requiere al menos un paso y todos registrados'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.recorrido_parada_impedir_borrado()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    RAISE EXCEPTION
        'No se pueden eliminar pasos de un recorrido; cierre el intento como abandonado si corresponde'
        USING ERRCODE = '23514';
END;
$$;

CREATE FUNCTION public.recorrido_usuario_validar_fijacion()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_cantidad bigint;
    v_minimo integer;
    v_maximo integer;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- El intento se crea antes de copiar sus paradas.
        IF NEW.pasos_fijados THEN
            RAISE EXCEPTION 'El recorrido debe crearse con pasos_fijados = false'
                USING ERRCODE = '23514';
        END IF;
    ELSE
        IF OLD.pasos_fijados AND NOT NEW.pasos_fijados THEN
            RAISE EXCEPTION 'No se puede reabrir la lista de pasos'
                USING ERRCODE = '23514';
        END IF;

        IF NOT OLD.pasos_fijados AND NEW.pasos_fijados THEN
            IF OLD.estado <> 'en_curso' OR NEW.estado <> 'en_curso' THEN
                RAISE EXCEPTION 'La lista debe fijarse mientras el recorrido está en curso'
                    USING ERRCODE = '23514';
            END IF;

            SELECT count(*), min(orden), max(orden)
            INTO v_cantidad, v_minimo, v_maximo
            FROM public.recorrido_parada
            WHERE recorrido_id = NEW.id;

            -- UNIQUE ya evita posiciones repetidas.
            IF v_cantidad = 0
               OR v_minimo <> 1
               OR v_maximo <> v_cantidad THEN
                RAISE EXCEPTION 'Se requiere una lista no vacía y consecutiva desde 1'
                    USING ERRCODE = '23514';
            END IF;

            -- Al fijar la lista, debe coincidir con todas las paradas
            -- y posiciones de la ruta. Las ediciones posteriores
            -- no volverán a comparar ni modificar esta copia.
            IF EXISTS (
                SELECT parada_id, orden
                FROM public.recorrido_parada
                WHERE recorrido_id = NEW.id

                EXCEPT

                SELECT id, orden
                FROM public.ruta_parada
                WHERE ruta_id = NEW.ruta_id
            ) OR EXISTS (
                SELECT id, orden
                FROM public.ruta_parada
                WHERE ruta_id = NEW.ruta_id

                EXCEPT

                SELECT parada_id, orden
                FROM public.recorrido_parada
                WHERE recorrido_id = NEW.id
            ) THEN
                RAISE EXCEPTION 'La lista inicial debe coincidir con las paradas de la ruta'
                    USING ERRCODE = '23514';
            END IF;
        END IF;
    END IF;

    IF NEW.estado <> 'en_curso' AND NOT NEW.pasos_fijados THEN
        RAISE EXCEPTION 'Debe fijar la lista antes de cerrar el recorrido'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.iniciar_recorrido(
    p_token text,
    p_ruta_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
    v_estado text;
    v_recorrido_id uuid;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión válida'
            USING ERRCODE = '42501';
    END IF;

    -- Coordina la copia con las ediciones de la ruta.
    SELECT estado INTO v_estado
    FROM public.ruta
    WHERE id = p_ruta_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ruta no existe'
            USING ERRCODE = '23503';
    END IF;

    IF v_estado <> 'publicado' THEN
        RAISE EXCEPTION 'Solo se pueden iniciar rutas publicadas'
            USING ERRCODE = '22023';
    END IF;

    -- El índice parcial impide otro intento abierto de la misma ruta.
    INSERT INTO public.recorrido_usuario (
        usuario_id, ruta_id, iniciado_en
    )
    VALUES (
        v_usuario_id, p_ruta_id, clock_timestamp()
    )
    RETURNING id INTO v_recorrido_id;

    -- Copia la lista establecida; el cliente no elige sus paradas.
    INSERT INTO public.recorrido_parada (
        recorrido_id, parada_id, orden
    )
    SELECT v_recorrido_id, p.id, p.orden
    FROM public.ruta_parada AS p
    WHERE p.ruta_id = p_ruta_id
    ORDER BY p.orden;

    -- El trigger comprueba la lista antes de fijarla.
    UPDATE public.recorrido_usuario
    SET pasos_fijados = true
    WHERE id = v_recorrido_id;

    RETURN v_recorrido_id;
END;
$$;

CREATE FUNCTION public.registrar_paso_recorrido(
    p_token text,
    p_paso_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
    v_recorrido_id uuid;
    v_estado text;
    v_pasos_fijados boolean;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión válida'
            USING ERRCODE = '42501';
    END IF;

    SELECT recorrido_id INTO v_recorrido_id
    FROM public.recorrido_parada
    WHERE id = p_paso_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Obtiene y bloquea únicamente un intento del usuario autenticado.
    -- Coordina el registro con otros registros y con el cierre.
    SELECT estado, pasos_fijados
    INTO v_estado, v_pasos_fijados
    FROM public.recorrido_usuario
    WHERE id = v_recorrido_id
      AND usuario_id = v_usuario_id
    FOR UPDATE;

    IF NOT FOUND THEN
        -- No distingue entre un paso ajeno y uno inexistente.
        RETURN false;
    END IF;

    IF v_estado <> 'en_curso' OR NOT v_pasos_fijados THEN
        RAISE EXCEPTION
            'El recorrido debe estar en curso y tener su lista fijada'
            USING ERRCODE = '22023';
    END IF;

    -- La hora la establece PostgreSQL, no el cliente.
    -- El trigger aplica los controles de fecha y registro único.
    UPDATE public.recorrido_parada
    SET registrado_en = clock_timestamp()
    WHERE id = p_paso_id
      AND recorrido_id = v_recorrido_id
      AND registrado_en IS NULL;

    -- Repetir la petición no cambia la fecha anterior.
    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.cerrar_recorrido(
    p_token text,
    p_recorrido_id uuid,
    p_estado_destino text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
    v_ruta_id uuid;
    v_estado_ruta text;
    v_estado text;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión válida'
            USING ERRCODE = '42501';
    END IF;

    IF p_estado_destino IS NULL
       OR p_estado_destino NOT IN ('completado', 'abandonado') THEN
        RAISE EXCEPTION 'El destino debe ser completado o abandonado'
            USING ERRCODE = '22023';
    END IF;

    SELECT r.ruta_id INTO v_ruta_id
    FROM public.recorrido_usuario AS r
    WHERE r.id = p_recorrido_id
      AND r.usuario_id = v_usuario_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Completar requiere coordinar con el retiro de la ruta.
    -- Abandonar se permite en cualquier estado de publicación.
    IF p_estado_destino = 'completado' THEN
        SELECT rt.estado INTO v_estado_ruta
        FROM public.ruta AS rt
        WHERE rt.id = v_ruta_id
        FOR SHARE;

        IF NOT FOUND THEN
            RETURN false;
        END IF;
    END IF;

    SELECT r.estado INTO v_estado
    FROM public.recorrido_usuario AS r
    WHERE r.id = p_recorrido_id
      AND r.usuario_id = v_usuario_id
    FOR UPDATE;

    IF NOT FOUND OR v_estado <> 'en_curso' THEN
        RETURN false;
    END IF;

    IF p_estado_destino = 'completado'
       AND v_estado_ruta <> 'publicado' THEN
        RAISE EXCEPTION
            'No se puede completar el recorrido mientras la ruta esté retirada'
            USING ERRCODE = '22023';
    END IF;

    -- Los triggers existentes siguen comprobando los pasos y fechas.
    UPDATE public.recorrido_usuario
    SET estado = p_estado_destino,
        finalizado_en = clock_timestamp()
    WHERE id = p_recorrido_id;

    RETURN true;
END;
$$;

CREATE FUNCTION public.obtener_mi_recorrido(
    p_token text,
    p_recorrido_id uuid
)
RETURNS TABLE (
    recorrido_id uuid,
    ruta_id uuid,
    estado text,
    iniciado_en timestamptz,
    finalizado_en timestamptz,
    total_paradas bigint,
    paradas_registradas bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión válida'
            USING ERRCODE = '42501';
    END IF;

    -- Filtra por el propietario obtenido desde la sesión.
    -- Cuenta las paradas fijadas al iniciar el recorrido,
    -- aunque después se modifique la ruta original.
    RETURN QUERY
    SELECT
        r.id,
        r.ruta_id,
        r.estado::text,
        r.iniciado_en,
        r.finalizado_en,
        (
            SELECT count(*)
            FROM public.recorrido_parada AS p
            WHERE p.recorrido_id = r.id
        ),
        (
            SELECT count(*)
            FROM public.recorrido_parada AS p
            WHERE p.recorrido_id = r.id
              AND p.registrado_en IS NOT NULL
        )
    FROM public.recorrido_usuario AS r
    WHERE r.id = p_recorrido_id
      AND r.usuario_id = v_usuario_id
      AND r.pasos_fijados;
END;
$$;

CREATE FUNCTION public.listar_mis_paradas_recorrido(
    p_token text,
    p_recorrido_id uuid
)
RETURNS TABLE (
    paso_id uuid,
    parada_id uuid,
    orden integer,
    registrado_en timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión válida'
            USING ERRCODE = '42501';
    END IF;

    -- Comprueba la propiedad desde la sesión y conserva
    -- el orden fijado al iniciar, aunque cambie la ruta original.
    RETURN QUERY
    SELECT
        p.id,
        p.parada_id,
        p.orden,
        p.registrado_en
    FROM public.recorrido_parada AS p
    JOIN public.recorrido_usuario AS r
        ON r.id = p.recorrido_id
    WHERE r.id = p_recorrido_id
      AND r.usuario_id = v_usuario_id
      AND r.pasos_fijados
    ORDER BY p.orden;
END;
$$;

CREATE FUNCTION public.listar_mis_recorridos(
    p_token text,
    p_limite integer DEFAULT 20,
    p_desplazamiento integer DEFAULT 0
)
RETURNS TABLE (
    recorrido_id uuid,
    ruta_id uuid,
    estado text,
    iniciado_en timestamptz,
    finalizado_en timestamptz,
    total_paradas bigint,
    paradas_registradas bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión válida'
            USING ERRCODE = '42501';
    END IF;

    -- Evita tamaños de respuesta ilimitados y valores negativos.
    IF p_limite IS NULL OR p_limite < 1 OR p_limite > 100
       OR p_desplazamiento IS NULL OR p_desplazamiento < 0 THEN
        RAISE EXCEPTION 'Paginación inválida: límite de 1 a 100 y desplazamiento no negativo'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        r.id,
        r.ruta_id,
        r.estado::text,
        r.iniciado_en,
        r.finalizado_en,
        (
            SELECT count(*)
            FROM public.recorrido_parada AS p
            WHERE p.recorrido_id = r.id
        ),
        (
            SELECT count(*)
            FROM public.recorrido_parada AS p
            WHERE p.recorrido_id = r.id
              AND p.registrado_en IS NOT NULL
        )
    FROM public.recorrido_usuario AS r
    WHERE r.usuario_id = v_usuario_id
      AND r.pasos_fijados
    -- El UUID desempata fechas iguales para mantener un orden definido.
    ORDER BY r.iniciado_en DESC, r.id DESC
    LIMIT p_limite
    OFFSET p_desplazamiento;
END;
$$;

CREATE FUNCTION public.recorrido_parada_proteger_origen()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_estado text;
BEGIN
    IF OLD.parada_id IS NOT NULL AND NEW.parada_id IS NULL THEN
        -- Coordina esta comprobación con el cierre del recorrido.
        -- Si otra transacción lo está cerrando, espera su resultado.
        SELECT r.estado INTO v_estado
        FROM public.recorrido_usuario AS r
        WHERE r.id = OLD.recorrido_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No existe el recorrido asociado'
                USING ERRCODE = '23503';
        END IF;

        IF v_estado = 'en_curso' THEN
            RAISE EXCEPTION
                'No se puede eliminar una parada utilizada por un recorrido en curso'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.qr_parada_proteger_identidad()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.parada_id IS DISTINCT FROM OLD.parada_id
       OR NEW.creado_en IS DISTINCT FROM OLD.creado_en THEN
        RAISE EXCEPTION
            'No se permite cambiar la identidad, la parada ni la fecha de creación del QR'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.admin_obtener_o_crear_qr_parada(
    p_token text,
    p_parada_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_qr_id uuid;
BEGIN
    -- Solo admite una sesión con rol administrador.
    PERFORM public.exigir_administrador(p_token);

    IF p_parada_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una parada'
            USING ERRCODE = '22023';
    END IF;

    -- Bloquea la parada para coordinar la creación del QR
    -- con otras creaciones y con su eliminación.
    PERFORM p.id
    FROM public.ruta_parada AS p
    WHERE p.id = p_parada_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La parada no existe'
            USING ERRCODE = '23503';
    END IF;

    -- Conserva el identificador existente, incluso si está inactivo.
    SELECT q.id INTO v_qr_id
    FROM public.qr_parada AS q
    WHERE q.parada_id = p_parada_id;

    IF FOUND THEN
        RETURN v_qr_id;
    END IF;

    INSERT INTO public.qr_parada (parada_id)
    VALUES (p_parada_id)
    ON CONFLICT (parada_id) DO NOTHING
    RETURNING id INTO v_qr_id;

    -- Resuelve también una creación concurrente sin cambiar el QR.
    IF v_qr_id IS NULL THEN
        SELECT q.id INTO STRICT v_qr_id
        FROM public.qr_parada AS q
        WHERE q.parada_id = p_parada_id;
    END IF;

    RETURN v_qr_id;
END;
$$;

CREATE FUNCTION public.admin_cambiar_activacion_qr(
    p_token text,
    p_qr_id uuid,
    p_activo boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_qr_id IS NULL OR p_activo IS NULL THEN
        RAISE EXCEPTION 'Se requiere el identificador y la activación del QR'
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.qr_parada AS q
    SET activo = p_activo
    WHERE q.id = p_qr_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El QR no existe'
            USING ERRCODE = '23503';
    END IF;

    RETURN true;
END;
$$;

CREATE FUNCTION public.obtener_contenido_qr(
    p_qr_id uuid,
    p_idioma_codigo text
)
RETURNS TABLE (
    qr_id uuid,
    parada_id uuid,
    ruta_id uuid,
    atractivo_id uuid,
    orden integer,
    idioma_codigo text,
    nombre text,
    descripcion text,
    imagen_principal text,
    imagen_texto_alternativo text,
    longitud double precision,
    latitud double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF p_qr_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere el identificador del QR'
            USING ERRCODE = '22023';
    END IF;

    IF p_idioma_codigo IS NULL
       OR p_idioma_codigo NOT IN ('es', 'en') THEN
        RAISE EXCEPTION 'Idioma no admitido'
            USING ERRCODE = '22023';
    END IF;

    -- Lee el contenido vigente; actualizarlo no cambia el QR.
    -- La ubicación corresponde a la parada, sin herencia automática.
    RETURN QUERY
    SELECT
        q.id,
        p.id,
        p.ruta_id,
        p.atractivo_id,
        p.orden,
        t.idioma_codigo::text,
        t.nombre::text,
        t.descripcion,
        p.imagen_principal,
        t.imagen_texto_alternativo::text,
        public.ST_X(p.ubicacion),
        public.ST_Y(p.ubicacion)
    FROM public.qr_parada AS q
    JOIN public.ruta_parada AS p
        ON p.id = q.parada_id
    JOIN public.ruta AS r
        ON r.id = p.ruta_id
    JOIN public.ruta_parada_traduccion AS t
        ON t.parada_id = p.id
       AND t.idioma_codigo = p_idioma_codigo
    WHERE q.id = p_qr_id
      AND q.activo
      AND r.estado = 'publicado';
END;
$$;

CREATE OR REPLACE FUNCTION public.registrar_paso_por_qr(
    p_token text,
    p_recorrido_id uuid,
    p_qr_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_usuario_id uuid;
    v_ruta_id uuid;
    v_estado_ruta text;
    v_estado text;
    v_pasos_fijados boolean;
    v_parada_id uuid;
    v_qr_activo boolean;
    v_paso_id uuid;
BEGIN
    v_usuario_id := public.validar_sesion(p_token);

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión válida'
            USING ERRCODE = '42501';
    END IF;

    IF p_recorrido_id IS NULL OR p_qr_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere el recorrido y el QR'
            USING ERRCODE = '22023';
    END IF;

    -- Obtiene la ruta solo desde un recorrido propio.
    -- La identidad y ruta del intento son inmutables.
    SELECT r.ruta_id INTO v_ruta_id
    FROM public.recorrido_usuario AS r
    WHERE r.id = p_recorrido_id
      AND r.usuario_id = v_usuario_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Primero coordina con retiro, publicación y edición de la ruta.
    SELECT rt.estado INTO v_estado_ruta
    FROM public.ruta AS rt
    WHERE rt.id = v_ruta_id
    FOR SHARE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Después coordina con desactivación o eliminación del QR.
    SELECT q.parada_id, q.activo
    INTO v_parada_id, v_qr_activo
    FROM public.qr_parada AS q
    WHERE q.id = p_qr_id
    FOR SHARE;

    IF NOT FOUND OR NOT v_qr_activo THEN
        RETURN false;
    END IF;

    -- Relee y bloquea el intento antes de registrar.
    SELECT r.estado, r.pasos_fijados
    INTO v_estado, v_pasos_fijados
    FROM public.recorrido_usuario AS r
    WHERE r.id = p_recorrido_id
      AND r.usuario_id = v_usuario_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_estado <> 'en_curso' OR NOT v_pasos_fijados THEN
        RAISE EXCEPTION 'El recorrido no está abierto para registrar progreso'
            USING ERRCODE = '22023';
    END IF;

    SELECT p.id INTO v_paso_id
    FROM public.recorrido_parada AS p
    WHERE p.recorrido_id = p_recorrido_id
      AND p.parada_id = v_parada_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_estado_ruta <> 'publicado' THEN
        RAISE EXCEPTION
            'No se puede registrar progreso mientras la ruta esté retirada'
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.recorrido_parada AS p
    SET registrado_en = clock_timestamp()
    WHERE p.id = v_paso_id
      AND p.recorrido_id = p_recorrido_id
      AND p.registrado_en IS NULL;

    -- Repetir un registro válido conserva la primera fecha.
    RETURN FOUND;
END;
$$;

CREATE FUNCTION public.admin_estadisticas_recorridos(
    p_token text,
    p_desde timestamptz,
    p_hasta timestamptz
)
RETURNS TABLE (
    ruta_id uuid,
    iniciados bigint,
    completados bigint,
    abandonados bigint,
    en_curso bigint,
    porcentaje_finalizacion numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_desde IS NULL OR p_hasta IS NULL
       OR NOT isfinite(p_desde)
       OR NOT isfinite(p_hasta)
       OR p_hasta <= p_desde THEN
        RAISE EXCEPTION 'Se requiere un período finito con inicio anterior al término'
            USING ERRCODE = '22023';
    END IF;

    -- Incluye rutas sin intentos en el período.
    -- Cuenta intentos, no usuarios únicos ni visitas físicas acreditadas.
    RETURN QUERY
    WITH conteos AS (
        SELECT
            r.ruta_id AS id_ruta,
            count(*) AS cantidad_iniciados,
            count(*) FILTER (
                WHERE r.estado = 'completado'
            ) AS cantidad_completados,
            count(*) FILTER (
                WHERE r.estado = 'abandonado'
            ) AS cantidad_abandonados,
            count(*) FILTER (
                WHERE r.estado = 'en_curso'
            ) AS cantidad_en_curso
        FROM public.recorrido_usuario AS r
        WHERE r.pasos_fijados
          AND r.iniciado_en >= p_desde
          AND r.iniciado_en < p_hasta
        GROUP BY r.ruta_id
    )
    SELECT
        rt.id,
        coalesce(c.cantidad_iniciados, 0::bigint),
        coalesce(c.cantidad_completados, 0::bigint),
        coalesce(c.cantidad_abandonados, 0::bigint),
        coalesce(c.cantidad_en_curso, 0::bigint),
        round(
            100::numeric * c.cantidad_completados
            / nullif(c.cantidad_iniciados, 0),
            2
        )
    FROM public.ruta AS rt
    LEFT JOIN conteos AS c
        ON c.id_ruta = rt.id
    ORDER BY rt.id;
END;
$$;

CREATE FUNCTION public.admin_estadisticas_perfiles(p_token text)
RETURNS TABLE (
    dimension text,
    grupo text,
    cantidad_visible bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    RETURN QUERY
    WITH perfiles AS (
        -- Un perfil por cuenta; no representa a todos los visitantes.
        SELECT
            p.edad_declarada,
            p.nacionalidad_codigo,
            p.genero_codigo
        FROM public.perfil_turista AS p
        JOIN public.usuario AS u
            ON u.id = p.usuario_id
        WHERE u.estado = 'activo'
          AND u.email_verificado_en IS NOT NULL
    ),
    grupos AS (
        -- Enumera también los grupos sin perfiles.
        SELECT
            'edad'::text AS dim,
            e.etiqueta AS etiqueta,
            e.posicion AS posicion
        FROM (
            VALUES
                ('0–17'::text, 1),
                ('18–29'::text, 2),
                ('30–44'::text, 3),
                ('45–59'::text, 4),
                ('60 años o más'::text, 5)
        ) AS e(etiqueta, posicion)

        UNION ALL

        SELECT
            'nacionalidad'::text,
            p.codigo::text,
            0
        FROM public.pais AS p

        UNION ALL

        SELECT
            'genero'::text,
            g.codigo,
            g.posicion
        FROM (
            VALUES
                ('masculino'::text, 1),
                ('femenino'::text, 2),
                ('no_binario'::text, 3),
                ('otra_identidad'::text, 4),
                ('prefiero_no_responder'::text, 5)
        ) AS g(codigo, posicion)
    ),
    observaciones AS (
        -- Cada dimensión se analiza por separado, sin cruces.
        SELECT
            'edad'::text AS dim,
            CASE
                WHEN p.edad_declarada <= 17 THEN '0–17'
                WHEN p.edad_declarada <= 29 THEN '18–29'
                WHEN p.edad_declarada <= 44 THEN '30–44'
                WHEN p.edad_declarada <= 59 THEN '45–59'
                ELSE '60 años o más'
            END AS etiqueta
        FROM perfiles AS p

        UNION ALL

        SELECT
            'nacionalidad'::text,
            p.nacionalidad_codigo::text
        FROM perfiles AS p

        UNION ALL

        SELECT
            'genero'::text,
            p.genero_codigo::text
        FROM perfiles AS p
    ),
    conteos AS (
        SELECT
            o.dim,
            o.etiqueta,
            count(*) AS cantidad
        FROM observaciones AS o
        GROUP BY o.dim, o.etiqueta
    )
    SELECT
        g.dim,
        g.etiqueta,
        CASE
            WHEN coalesce(c.cantidad, 0::bigint) >= 5
                THEN c.cantidad
            ELSE NULL::bigint
        END
    FROM grupos AS g
    LEFT JOIN conteos AS c
        ON c.dim = g.dim
       AND c.etiqueta = g.etiqueta
    ORDER BY g.dim, g.posicion, g.etiqueta;
END;
$$;

CREATE FUNCTION public.obtener_credenciales_login(
    p_email text
)
RETURNS TABLE (
    usuario_id uuid,
    password_hash text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_email text;
BEGIN
    v_email := lower(btrim(p_email));

    -- Las entradas inválidas no devuelven credenciales.
    IF v_email IS NULL
       OR char_length(v_email) NOT BETWEEN 3 AND 254
       OR v_email ~ '[[:space:]]'
       OR v_email !~ '^[^@]+@[^@]+$' THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        u.id,
        u.password_hash
    FROM public.usuario AS u
    WHERE u.email = v_email
      AND u.estado = 'activo'
      AND u.email_verificado_en IS NOT NULL;
END;
$$;

-- Triggers de integridad y mantenimiento

CREATE TRIGGER usuario_actualizar_fecha_trg BEFORE UPDATE ON public.usuario FOR EACH ROW EXECUTE FUNCTION public.usuario_actualizar_fecha();

CREATE TRIGGER perfil_turista_actualizar_fechas_trg
BEFORE UPDATE ON public.perfil_turista
FOR EACH ROW
EXECUTE FUNCTION public.perfil_turista_actualizar_fechas();

CREATE TRIGGER atractivo_actualizar_fecha_trg
BEFORE UPDATE ON public.atractivo
FOR EACH ROW
EXECUTE FUNCTION public.atractivo_actualizar_fecha();

CREATE TRIGGER atractivo_traduccion_actualizar_fecha_trg
BEFORE UPDATE ON public.atractivo_traduccion
FOR EACH ROW
EXECUTE FUNCTION public.atractivo_traduccion_actualizar_fecha();

CREATE TRIGGER ruta_actualizar_fecha_trg
BEFORE UPDATE ON public.ruta
FOR EACH ROW
EXECUTE FUNCTION public.ruta_actualizar_fecha();

CREATE TRIGGER ruta_traduccion_actualizar_fecha_trg
BEFORE UPDATE ON public.ruta_traduccion
FOR EACH ROW
EXECUTE FUNCTION public.ruta_traduccion_actualizar_fecha();

CREATE TRIGGER ruta_parada_actualizar_fecha_trg
BEFORE UPDATE ON public.ruta_parada
FOR EACH ROW
EXECUTE FUNCTION public.ruta_parada_actualizar_fecha();

CREATE TRIGGER ruta_parada_traduccion_actualizar_fecha_trg
BEFORE UPDATE ON public.ruta_parada_traduccion
FOR EACH ROW
EXECUTE FUNCTION public.ruta_parada_traduccion_actualizar_fecha();

CREATE CONSTRAINT TRIGGER ruta_publicacion_completa_trg
AFTER INSERT OR UPDATE ON public.ruta
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.ruta_comprobar_publicacion();

CREATE TRIGGER ruta_traduccion_marcar_cambio_trg
AFTER INSERT OR UPDATE OR DELETE
ON public.ruta_traduccion
FOR EACH ROW
EXECUTE FUNCTION public.ruta_traduccion_marcar_cambio();

CREATE TRIGGER ruta_parada_marcar_cambio_trg
AFTER INSERT OR UPDATE OR DELETE
ON public.ruta_parada
FOR EACH ROW
EXECUTE FUNCTION public.ruta_parada_marcar_cambio();

CREATE TRIGGER ruta_parada_traduccion_marcar_cambio_trg
AFTER INSERT OR UPDATE OR DELETE
ON public.ruta_parada_traduccion
FOR EACH ROW
EXECUTE FUNCTION public.ruta_parada_traduccion_marcar_cambio();

CREATE CONSTRAINT TRIGGER atractivo_publicacion_completa_trg
AFTER INSERT OR UPDATE ON public.atractivo
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.atractivo_comprobar_publicacion();

CREATE TRIGGER atractivo_traduccion_marcar_cambio_trg
AFTER INSERT OR UPDATE OR DELETE
ON public.atractivo_traduccion
FOR EACH ROW
EXECUTE FUNCTION public.atractivo_traduccion_marcar_cambio();

CREATE CONSTRAINT TRIGGER categoria_activacion_completa_trg
AFTER INSERT OR UPDATE ON public.categoria_atractivo
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.categoria_comprobar_activacion();

CREATE TRIGGER categoria_traduccion_marcar_cambio_trg
AFTER INSERT OR UPDATE OR DELETE
ON public.categoria_atractivo_traduccion
FOR EACH ROW
EXECUTE FUNCTION public.categoria_traduccion_marcar_cambio();

CREATE TRIGGER recorrido_parada_validar_trg
BEFORE INSERT OR UPDATE ON public.recorrido_parada
FOR EACH ROW
EXECUTE FUNCTION public.recorrido_parada_validar();

CREATE TRIGGER recorrido_usuario_validar_cambio_trg
BEFORE UPDATE ON public.recorrido_usuario
FOR EACH ROW
EXECUTE FUNCTION public.recorrido_usuario_validar_cambio();

CREATE TRIGGER recorrido_parada_impedir_borrado_trg
BEFORE DELETE ON public.recorrido_parada
FOR EACH ROW
EXECUTE FUNCTION public.recorrido_parada_impedir_borrado();

CREATE TRIGGER recorrido_usuario_validar_fijacion_trg
BEFORE INSERT OR UPDATE ON public.recorrido_usuario
FOR EACH ROW
EXECUTE FUNCTION public.recorrido_usuario_validar_fijacion();

CREATE TRIGGER recorrido_parada_proteger_origen_trg
BEFORE UPDATE OF parada_id ON public.recorrido_parada
FOR EACH ROW
EXECUTE FUNCTION public.recorrido_parada_proteger_origen();

CREATE TRIGGER qr_parada_proteger_identidad_trg
BEFORE UPDATE ON public.qr_parada
FOR EACH ROW
EXECUTE FUNCTION public.qr_parada_proteger_identidad();

-- Catálogos iniciales: roles y 249 países/territorios

INSERT INTO public.rol (codigo, descripcion)
VALUES
    ('turista', 'Usuario visitante de la plataforma'),
    ('administrador', 'Personal autorizado para la gestión municipal')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO public.pais (codigo, nombre_es)
VALUES
    ('AD', 'Andorra'),
    ('AE', 'Emiratos Árabes Unidos'),
    ('AF', 'Afganistán'),
    ('AG', 'Antigua y Barbuda'),
    ('AI', 'Anguila'),
    ('AL', 'Albania'),
    ('AM', 'Armenia'),
    ('AO', 'Angola'),
    ('AQ', 'Antártida'),
    ('AR', 'Argentina'),
    ('AS', 'Samoa Americana'),
    ('AT', 'Austria'),
    ('AU', 'Australia'),
    ('AW', 'Aruba'),
    ('AX', 'Islas Aland'),
    ('AZ', 'Azerbaiyán'),
    ('BA', 'Bosnia y Herzegovina'),
    ('BB', 'Barbados'),
    ('BD', 'Bangladés'),
    ('BE', 'Bélgica'),
    ('BF', 'Burkina Faso'),
    ('BG', 'Bulgaria'),
    ('BH', 'Baréin'),
    ('BI', 'Burundi'),
    ('BJ', 'Benín'),
    ('BL', 'San Bartolomé'),
    ('BM', 'Bermudas'),
    ('BN', 'Brunéi'),
    ('BO', 'Bolivia'),
    ('BQ', 'Caribe neerlandés'),
    ('BR', 'Brasil'),
    ('BS', 'Bahamas'),
    ('BT', 'Bután'),
    ('BV', 'Isla Bouvet'),
    ('BW', 'Botsuana'),
    ('BY', 'Bielorrusia'),
    ('BZ', 'Belice'),
    ('CA', 'Canadá'),
    ('CC', 'Islas Cocos'),
    ('CD', 'República Democrática del Congo'),
    ('CF', 'República Centroafricana'),
    ('CG', 'Congo'),
    ('CH', 'Suiza'),
    ('CI', 'Côte d’Ivoire'),
    ('CK', 'Islas Cook'),
    ('CL', 'Chile'),
    ('CM', 'Camerún'),
    ('CN', 'China'),
    ('CO', 'Colombia'),
    ('CR', 'Costa Rica'),
    ('CU', 'Cuba'),
    ('CV', 'Cabo Verde'),
    ('CW', 'Curazao'),
    ('CX', 'Isla de Navidad'),
    ('CY', 'Chipre'),
    ('CZ', 'Chequia'),
    ('DE', 'Alemania'),
    ('DJ', 'Yibuti'),
    ('DK', 'Dinamarca'),
    ('DM', 'Dominica'),
    ('DO', 'República Dominicana'),
    ('DZ', 'Argelia'),
    ('EC', 'Ecuador'),
    ('EE', 'Estonia'),
    ('EG', 'Egipto'),
    ('EH', 'Sáhara Occidental'),
    ('ER', 'Eritrea'),
    ('ES', 'España'),
    ('ET', 'Etiopía'),
    ('FI', 'Finlandia'),
    ('FJ', 'Fiyi'),
    ('FK', 'Islas Malvinas'),
    ('FM', 'Micronesia'),
    ('FO', 'Islas Feroe'),
    ('FR', 'Francia'),
    ('GA', 'Gabón'),
    ('GB', 'Reino Unido'),
    ('GD', 'Granada'),
    ('GE', 'Georgia'),
    ('GF', 'Guayana Francesa'),
    ('GG', 'Guernesey'),
    ('GH', 'Ghana'),
    ('GI', 'Gibraltar'),
    ('GL', 'Groenlandia'),
    ('GM', 'Gambia'),
    ('GN', 'Guinea'),
    ('GP', 'Guadalupe'),
    ('GQ', 'Guinea Ecuatorial'),
    ('GR', 'Grecia'),
    ('GS', 'Islas Georgia del Sur y Sandwich del Sur'),
    ('GT', 'Guatemala'),
    ('GU', 'Guam'),
    ('GW', 'Guinea-Bisáu'),
    ('GY', 'Guyana'),
    ('HK', 'RAE de Hong Kong (China)'),
    ('HM', 'Islas Heard y McDonald'),
    ('HN', 'Honduras'),
    ('HR', 'Croacia'),
    ('HT', 'Haití'),
    ('HU', 'Hungría'),
    ('ID', 'Indonesia'),
    ('IE', 'Irlanda'),
    ('IL', 'Israel'),
    ('IM', 'Isla de Man'),
    ('IN', 'India'),
    ('IO', 'Territorio Británico del Océano Índico'),
    ('IQ', 'Irak'),
    ('IR', 'Irán'),
    ('IS', 'Islandia'),
    ('IT', 'Italia'),
    ('JE', 'Jersey'),
    ('JM', 'Jamaica'),
    ('JO', 'Jordania'),
    ('JP', 'Japón'),
    ('KE', 'Kenia'),
    ('KG', 'Kirguistán'),
    ('KH', 'Camboya'),
    ('KI', 'Kiribati'),
    ('KM', 'Comoras'),
    ('KN', 'San Cristóbal y Nieves'),
    ('KP', 'Corea del Norte'),
    ('KR', 'Corea del Sur'),
    ('KW', 'Kuwait'),
    ('KY', 'Islas Caimán'),
    ('KZ', 'Kazajistán'),
    ('LA', 'Laos'),
    ('LB', 'Líbano'),
    ('LC', 'Santa Lucía'),
    ('LI', 'Liechtenstein'),
    ('LK', 'Sri Lanka'),
    ('LR', 'Liberia'),
    ('LS', 'Lesoto'),
    ('LT', 'Lituania'),
    ('LU', 'Luxemburgo'),
    ('LV', 'Letonia'),
    ('LY', 'Libia'),
    ('MA', 'Marruecos'),
    ('MC', 'Mónaco'),
    ('MD', 'Moldavia'),
    ('ME', 'Montenegro'),
    ('MF', 'San Martín'),
    ('MG', 'Madagascar'),
    ('MH', 'Islas Marshall'),
    ('MK', 'Macedonia del Norte'),
    ('ML', 'Mali'),
    ('MM', 'Myanmar (Birmania)'),
    ('MN', 'Mongolia'),
    ('MO', 'RAE de Macao (China)'),
    ('MP', 'Islas Marianas del Norte'),
    ('MQ', 'Martinica'),
    ('MR', 'Mauritania'),
    ('MS', 'Montserrat'),
    ('MT', 'Malta'),
    ('MU', 'Mauricio'),
    ('MV', 'Maldivas'),
    ('MW', 'Malaui'),
    ('MX', 'México'),
    ('MY', 'Malasia'),
    ('MZ', 'Mozambique'),
    ('NA', 'Namibia'),
    ('NC', 'Nueva Caledonia'),
    ('NE', 'Níger'),
    ('NF', 'Isla Norfolk'),
    ('NG', 'Nigeria'),
    ('NI', 'Nicaragua'),
    ('NL', 'Países Bajos'),
    ('NO', 'Noruega'),
    ('NP', 'Nepal'),
    ('NR', 'Nauru'),
    ('NU', 'Niue'),
    ('NZ', 'Nueva Zelanda'),
    ('OM', 'Omán'),
    ('PA', 'Panamá'),
    ('PE', 'Perú'),
    ('PF', 'Polinesia Francesa'),
    ('PG', 'Papúa Nueva Guinea'),
    ('PH', 'Filipinas'),
    ('PK', 'Pakistán'),
    ('PL', 'Polonia'),
    ('PM', 'San Pedro y Miquelón'),
    ('PN', 'Islas Pitcairn'),
    ('PR', 'Puerto Rico'),
    ('PS', 'Territorios Palestinos'),
    ('PT', 'Portugal'),
    ('PW', 'Palaos'),
    ('PY', 'Paraguay'),
    ('QA', 'Catar'),
    ('RE', 'Reunión'),
    ('RO', 'Rumanía'),
    ('RS', 'Serbia'),
    ('RU', 'Rusia'),
    ('RW', 'Ruanda'),
    ('SA', 'Arabia Saudí'),
    ('SB', 'Islas Salomón'),
    ('SC', 'Seychelles'),
    ('SD', 'Sudán'),
    ('SE', 'Suecia'),
    ('SG', 'Singapur'),
    ('SH', 'Santa Elena'),
    ('SI', 'Eslovenia'),
    ('SJ', 'Svalbard y Jan Mayen'),
    ('SK', 'Eslovaquia'),
    ('SL', 'Sierra Leona'),
    ('SM', 'San Marino'),
    ('SN', 'Senegal'),
    ('SO', 'Somalia'),
    ('SR', 'Surinam'),
    ('SS', 'Sudán del Sur'),
    ('ST', 'Santo Tomé y Príncipe'),
    ('SV', 'El Salvador'),
    ('SX', 'Sint Maarten'),
    ('SY', 'Siria'),
    ('SZ', 'Esuatini'),
    ('TC', 'Islas Turcas y Caicos'),
    ('TD', 'Chad'),
    ('TF', 'Territorios Australes Franceses'),
    ('TG', 'Togo'),
    ('TH', 'Tailandia'),
    ('TJ', 'Tayikistán'),
    ('TK', 'Tokelau'),
    ('TL', 'Timor-Leste'),
    ('TM', 'Turkmenistán'),
    ('TN', 'Túnez'),
    ('TO', 'Tonga'),
    ('TR', 'Turquía'),
    ('TT', 'Trinidad y Tobago'),
    ('TV', 'Tuvalu'),
    ('TW', 'Taiwán'),
    ('TZ', 'Tanzania'),
    ('UA', 'Ucrania'),
    ('UG', 'Uganda'),
    ('UM', 'Islas menores alejadas de EE. UU.'),
    ('US', 'Estados Unidos'),
    ('UY', 'Uruguay'),
    ('UZ', 'Uzbekistán'),
    ('VA', 'Ciudad del Vaticano'),
    ('VC', 'San Vicente y las Granadinas'),
    ('VE', 'Venezuela'),
    ('VG', 'Islas Vírgenes Británicas'),
    ('VI', 'Islas Vírgenes de EE. UU.'),
    ('VN', 'Vietnam'),
    ('VU', 'Vanuatu'),
    ('WF', 'Wallis y Futuna'),
    ('WS', 'Samoa'),
    ('YE', 'Yemen'),
    ('YT', 'Mayotte'),
    ('ZA', 'Sudáfrica'),
    ('ZM', 'Zambia'),
    ('ZW', 'Zimbabue')
ON CONFLICT (codigo) DO NOTHING;

-- Propietarios y permisos mínimos

DO $conexion$ BEGIN EXECUTE format('GRANT CONNECT ON DATABASE %I TO casablanca_api', current_database()); END; $conexion$;

GRANT USAGE ON SCHEMA public TO casablanca_api;

GRANT SELECT ON public.rol TO casablanca_api;

GRANT USAGE ON SCHEMA public
    TO casablanca_registro_owner;

GRANT SELECT ON public.rol
    TO casablanca_registro_owner;

GRANT INSERT (email, password_hash, nombre)
    ON public.usuario
    TO casablanca_registro_owner;

GRANT SELECT (id) ON public.usuario
    TO casablanca_registro_owner;

GRANT INSERT (usuario_id, rol_id)
    ON public.usuario_rol
    TO casablanca_registro_owner;

GRANT CREATE ON SCHEMA public
    TO casablanca_registro_owner;

REVOKE CREATE ON SCHEMA public
    FROM casablanca_registro_owner;

GRANT SELECT ON TABLE public.pais TO casablanca_api;

GRANT INSERT (
    usuario_id,
    edad_declarada,
    nacionalidad_codigo,
    genero_codigo,
    genero_detalle
)
ON public.perfil_turista
TO casablanca_registro_owner;

REVOKE ALL ON FUNCTION public.registrar_turista(
    text, text, text, integer, text, text, text
) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_registro_owner;

ALTER FUNCTION public.registrar_turista(
    text, text, text, integer, text, text, text
) OWNER TO casablanca_registro_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_registro_owner;

GRANT EXECUTE ON FUNCTION public.registrar_turista(
    text, text, text, integer, text, text, text
) TO casablanca_api;

GRANT USAGE ON SCHEMA public
    TO casablanca_verificacion_owner;

GRANT SELECT (id, email, estado, email_verificado_en, creado_en)
    ON public.usuario
    TO casablanca_verificacion_owner;

GRANT UPDATE (estado, email_verificado_en)
    ON public.usuario
    TO casablanca_verificacion_owner;

GRANT SELECT ON public.verificacion_email
    TO casablanca_verificacion_owner;

GRANT INSERT (usuario_id, token_hash, creado_en, expira_en)
    ON public.verificacion_email
    TO casablanca_verificacion_owner;

GRANT UPDATE (consumido_en, revocado_en)
    ON public.verificacion_email
    TO casablanca_verificacion_owner;

GRANT EXECUTE ON FUNCTION public.gen_random_bytes(integer)
    TO casablanca_verificacion_owner;

GRANT EXECUTE ON FUNCTION public.digest(text, text)
    TO casablanca_verificacion_owner;

REVOKE ALL ON FUNCTION public.emitir_verificacion_email(uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_verificacion_owner;

ALTER FUNCTION public.emitir_verificacion_email(uuid)
    OWNER TO casablanca_verificacion_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_verificacion_owner;

GRANT EXECUTE ON FUNCTION public.emitir_verificacion_email(uuid)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.confirmar_email(text) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_verificacion_owner;

ALTER FUNCTION public.confirmar_email(text)
    OWNER TO casablanca_verificacion_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_verificacion_owner;

GRANT EXECUTE ON FUNCTION public.confirmar_email(text)
    TO casablanca_api;

GRANT USAGE ON SCHEMA public
    TO casablanca_sesion_owner;

GRANT SELECT (id, estado, email_verificado_en)
    ON public.usuario
    TO casablanca_sesion_owner;

GRANT SELECT ON public.sesion_usuario
    TO casablanca_sesion_owner;

GRANT INSERT (usuario_id, token_hash, creado_en, expira_en)
    ON public.sesion_usuario
    TO casablanca_sesion_owner;

GRANT UPDATE (revocado_en)
    ON public.sesion_usuario
    TO casablanca_sesion_owner;

GRANT EXECUTE ON FUNCTION public.gen_random_bytes(integer)
    TO casablanca_sesion_owner;

GRANT EXECUTE ON FUNCTION public.digest(text, text)
    TO casablanca_sesion_owner;

REVOKE ALL ON FUNCTION public.crear_sesion(uuid) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_sesion_owner;

ALTER FUNCTION public.crear_sesion(uuid)
    OWNER TO casablanca_sesion_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_sesion_owner;

GRANT EXECUTE ON FUNCTION public.crear_sesion(uuid)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.validar_sesion(text) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_sesion_owner;

ALTER FUNCTION public.validar_sesion(text)
    OWNER TO casablanca_sesion_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_sesion_owner;

GRANT EXECUTE ON FUNCTION public.validar_sesion(text)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.cerrar_sesion(text) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_sesion_owner;

ALTER FUNCTION public.cerrar_sesion(text)
    OWNER TO casablanca_sesion_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_sesion_owner;

GRANT EXECUTE ON FUNCTION public.cerrar_sesion(text)
    TO casablanca_api;

GRANT USAGE ON SCHEMA public TO casablanca_perfil_owner;

GRANT EXECUTE ON FUNCTION public.validar_sesion(text)
    TO casablanca_perfil_owner;

GRANT SELECT (id, email, nombre)
    ON public.usuario
    TO casablanca_perfil_owner;

GRANT SELECT (
    usuario_id,
    edad_declarada,
    edad_declarada_en,
    nacionalidad_codigo,
    genero_codigo,
    genero_detalle
)
    ON public.perfil_turista
    TO casablanca_perfil_owner;

REVOKE ALL ON FUNCTION public.obtener_mi_perfil(text) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_perfil_owner;

ALTER FUNCTION public.obtener_mi_perfil(text)
    OWNER TO casablanca_perfil_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_perfil_owner;

GRANT EXECUTE ON FUNCTION public.obtener_mi_perfil(text)
    TO casablanca_api;

GRANT UPDATE (
    edad_declarada,
    nacionalidad_codigo,
    genero_codigo,
    genero_detalle
)
    ON public.perfil_turista
    TO casablanca_perfil_owner;

REVOKE ALL ON FUNCTION public.actualizar_mi_perfil(
    text, integer, text, text, text
) FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_perfil_owner;

ALTER FUNCTION public.actualizar_mi_perfil(
    text, integer, text, text, text
) OWNER TO casablanca_perfil_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_perfil_owner;

GRANT EXECUTE ON FUNCTION public.actualizar_mi_perfil(
    text, integer, text, text, text
) TO casablanca_api;

REVOKE ALL ON FUNCTION public.comprobar_ruta_publicable(uuid)
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.ruta_comprobar_publicacion()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.ruta_traduccion_marcar_cambio()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.ruta_parada_marcar_cambio()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.ruta_parada_traduccion_marcar_cambio()
    FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO casablanca_admin_owner;

GRANT SELECT (usuario_id, rol_id)
    ON public.usuario_rol TO casablanca_admin_owner;

GRANT SELECT (id, codigo)
    ON public.rol TO casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.validar_sesion(text)
    TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.exigir_administrador(text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.exigir_administrador(text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT INSERT (estado)
    ON public.ruta TO casablanca_admin_owner;

GRANT SELECT (id, estado)
    ON public.ruta TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_crear_ruta(text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_crear_ruta(text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_crear_ruta(text)
    TO casablanca_api;

GRANT UPDATE (duracion_estimada_minutos, imagen_principal)
    ON public.ruta TO casablanca_admin_owner;

GRANT SELECT (duracion_estimada_minutos)
    ON public.ruta TO casablanca_admin_owner;

GRANT SELECT (ruta_id, idioma_codigo)
    ON public.ruta_traduccion TO casablanca_admin_owner;

GRANT SELECT (id, ruta_id, orden)
    ON public.ruta_parada TO casablanca_admin_owner;

GRANT SELECT (parada_id, idioma_codigo)
    ON public.ruta_parada_traduccion TO casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.comprobar_ruta_publicable(uuid)
    TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_actualizar_ruta(text, uuid, integer, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION
    public.admin_actualizar_ruta(text, uuid, integer, text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_actualizar_ruta(text, uuid, integer, text)
    TO casablanca_api;

GRANT INSERT (
    ruta_id, idioma_codigo, nombre,
    descripcion, imagen_texto_alternativo
)
ON public.ruta_traduccion TO casablanca_admin_owner;

GRANT UPDATE (
    nombre, descripcion, imagen_texto_alternativo
)
ON public.ruta_traduccion TO casablanca_admin_owner;

GRANT SELECT (creado_en)
    ON public.ruta_traduccion TO casablanca_admin_owner;

GRANT UPDATE (actualizado_en)
    ON public.ruta TO casablanca_admin_owner;

GRANT SELECT (actualizado_en)
    ON public.ruta TO casablanca_admin_owner;

GRANT SELECT (nombre, descripcion, imagen_texto_alternativo)
    ON public.ruta_traduccion TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_guardar_ruta_traduccion(
        text, uuid, text, text, text, text
    )
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_guardar_ruta_traduccion(
    text, uuid, text, text, text, text
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_guardar_ruta_traduccion(
        text, uuid, text, text, text, text
    )
    TO casablanca_api;

GRANT INSERT (
    ruta_id, atractivo_id, orden, imagen_principal, ubicacion
)
ON public.ruta_parada TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_crear_ruta_parada(
    text, uuid, integer, uuid, text, double precision, double precision
)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_crear_ruta_parada(
    text, uuid, integer, uuid, text, double precision, double precision
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_crear_ruta_parada(
    text, uuid, integer, uuid, text, double precision, double precision
)
TO casablanca_api;

GRANT INSERT (
    parada_id, idioma_codigo, nombre,
    descripcion, imagen_texto_alternativo
)
ON public.ruta_parada_traduccion TO casablanca_admin_owner;

GRANT UPDATE (
    nombre, descripcion, imagen_texto_alternativo
)
ON public.ruta_parada_traduccion TO casablanca_admin_owner;

GRANT SELECT (
    parada_id, idioma_codigo, nombre,
    descripcion, imagen_texto_alternativo
)
ON public.ruta_parada_traduccion TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_guardar_parada_traduccion(
    text, uuid, text, text, text, text
)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_guardar_parada_traduccion(
    text, uuid, text, text, text, text
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_guardar_parada_traduccion(
    text, uuid, text, text, text, text
)
TO casablanca_api;

GRANT UPDATE (estado)
    ON public.ruta TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_publicar_ruta(text, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_publicar_ruta(text, uuid)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_publicar_ruta(text, uuid)
    TO casablanca_api;

REVOKE ALL ON FUNCTION
    public.admin_retirar_ruta(text, uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_retirar_ruta(text, uuid, text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_retirar_ruta(text, uuid, text)
    TO casablanca_api;

GRANT UPDATE (atractivo_id, imagen_principal, ubicacion)
    ON public.ruta_parada TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_actualizar_ruta_parada(
    text, uuid, uuid, text, double precision, double precision
)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_actualizar_ruta_parada(
    text, uuid, uuid, text, double precision, double precision
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_actualizar_ruta_parada(
    text, uuid, uuid, text, double precision, double precision
)
TO casablanca_api;

GRANT UPDATE (orden)
    ON public.ruta_parada TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_reordenar_ruta_paradas(text, uuid, uuid[])
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_reordenar_ruta_paradas(
    text, uuid, uuid[]
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_reordenar_ruta_paradas(text, uuid, uuid[])
    TO casablanca_api;

GRANT USAGE ON SCHEMA public TO casablanca_consulta_owner;

GRANT SELECT (
    id, estado, duracion_estimada_minutos, imagen_principal
)
ON public.ruta TO casablanca_consulta_owner;

GRANT SELECT (
    ruta_id, idioma_codigo, nombre,
    descripcion, imagen_texto_alternativo
)
ON public.ruta_traduccion TO casablanca_consulta_owner;

REVOKE ALL ON FUNCTION public.listar_rutas_publicadas(text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_consulta_owner;

ALTER FUNCTION public.listar_rutas_publicadas(text)
    OWNER TO casablanca_consulta_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_consulta_owner;

GRANT EXECUTE ON FUNCTION public.listar_rutas_publicadas(text)
    TO casablanca_api;

GRANT SELECT (
    id, ruta_id, atractivo_id, orden, imagen_principal, ubicacion
)
ON public.ruta_parada TO casablanca_consulta_owner;

GRANT SELECT (
    parada_id, idioma_codigo, nombre,
    descripcion, imagen_texto_alternativo
)
ON public.ruta_parada_traduccion TO casablanca_consulta_owner;

REVOKE ALL ON FUNCTION
    public.listar_paradas_ruta_publicada(uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_consulta_owner;

ALTER FUNCTION public.listar_paradas_ruta_publicada(uuid, text)
    OWNER TO casablanca_consulta_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_consulta_owner;

GRANT EXECUTE ON FUNCTION
    public.listar_paradas_ruta_publicada(uuid, text)
    TO casablanca_api;

GRANT DELETE ON public.ruta_parada_traduccion
    TO casablanca_admin_owner;

GRANT DELETE ON public.ruta_parada
    TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_eliminar_ruta_parada(text, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_eliminar_ruta_parada(text, uuid)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_eliminar_ruta_parada(text, uuid)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.asignar_administrador_inicial(uuid)
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.asignar_administrador_inicial(uuid)
    FROM casablanca_api;

GRANT INSERT (estado)
    ON public.atractivo TO casablanca_admin_owner;

GRANT SELECT (id)
    ON public.atractivo TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_crear_atractivo(text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_crear_atractivo(text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_crear_atractivo(text)
    TO casablanca_api;

GRANT UPDATE (imagen_principal, ubicacion)
    ON public.atractivo TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_actualizar_atractivo(
    text, uuid, text, double precision, double precision
)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_actualizar_atractivo(
    text, uuid, text, double precision, double precision
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_actualizar_atractivo(
    text, uuid, text, double precision, double precision
)
TO casablanca_api;

GRANT INSERT (
    atractivo_id, idioma_codigo, nombre,
    descripcion, imagen_texto_alternativo
)
ON public.atractivo_traduccion TO casablanca_admin_owner;

GRANT UPDATE (
    nombre, descripcion, imagen_texto_alternativo
)
ON public.atractivo_traduccion TO casablanca_admin_owner;

GRANT SELECT (
    atractivo_id, idioma_codigo, nombre,
    descripcion, imagen_texto_alternativo
)
ON public.atractivo_traduccion TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_guardar_atractivo_traduccion(
    text, uuid, text, text, text, text
)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_guardar_atractivo_traduccion(
    text, uuid, text, text, text, text
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_guardar_atractivo_traduccion(
    text, uuid, text, text, text, text
)
TO casablanca_api;

REVOKE ALL ON FUNCTION public.comprobar_atractivo_publicable(uuid)
    FROM PUBLIC;

GRANT SELECT (estado, imagen_principal, ubicacion, actualizado_en)
    ON public.atractivo TO casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.comprobar_atractivo_publicable(uuid)
    TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.atractivo_comprobar_publicacion()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.atractivo_traduccion_marcar_cambio()
    FROM PUBLIC;

GRANT UPDATE (actualizado_en)
    ON public.atractivo TO casablanca_admin_owner;

GRANT UPDATE (estado)
    ON public.atractivo TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_publicar_atractivo(text, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_publicar_atractivo(text, uuid)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_publicar_atractivo(text, uuid)
    TO casablanca_api;

REVOKE ALL ON FUNCTION
    public.admin_retirar_atractivo(text, uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_retirar_atractivo(text, uuid, text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_retirar_atractivo(text, uuid, text)
    TO casablanca_api;

GRANT INSERT (codigo, icono_codigo, activo)
    ON public.categoria_atractivo TO casablanca_admin_owner;

GRANT SELECT (id)
    ON public.categoria_atractivo TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_crear_categoria_atractivo(
    text, text, text
)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_crear_categoria_atractivo(
    text, text, text
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_crear_categoria_atractivo(
    text, text, text
)
TO casablanca_api;

GRANT INSERT (categoria_id, idioma_codigo, nombre)
    ON public.categoria_atractivo_traduccion
    TO casablanca_admin_owner;

GRANT UPDATE (nombre)
    ON public.categoria_atractivo_traduccion
    TO casablanca_admin_owner;

GRANT SELECT (categoria_id, idioma_codigo, nombre)
    ON public.categoria_atractivo_traduccion
    TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_guardar_categoria_traduccion(
    text, uuid, text, text
)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_guardar_categoria_traduccion(
    text, uuid, text, text
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_guardar_categoria_traduccion(
    text, uuid, text, text
)
TO casablanca_api;

REVOKE ALL ON FUNCTION public.comprobar_categoria_activable(uuid)
    FROM PUBLIC;

GRANT SELECT (activo)
    ON public.categoria_atractivo TO casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.comprobar_categoria_activable(uuid)
    TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.categoria_comprobar_activacion()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.categoria_traduccion_marcar_cambio()
    FROM PUBLIC;

GRANT UPDATE (activo)
    ON public.categoria_atractivo TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_cambiar_activacion_categoria(text, uuid, boolean)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_cambiar_activacion_categoria(
    text, uuid, boolean
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_cambiar_activacion_categoria(text, uuid, boolean)
    TO casablanca_api;

GRANT INSERT (atractivo_id, categoria_id)
    ON public.atractivo_categoria TO casablanca_admin_owner;

GRANT SELECT (atractivo_id, categoria_id)
    ON public.atractivo_categoria TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_asignar_categoria_atractivo(text, uuid, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_asignar_categoria_atractivo(
    text, uuid, uuid
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_asignar_categoria_atractivo(text, uuid, uuid)
    TO casablanca_api;

GRANT DELETE ON public.atractivo_categoria
    TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_quitar_categoria_atractivo(text, uuid, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_quitar_categoria_atractivo(
    text, uuid, uuid
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_quitar_categoria_atractivo(text, uuid, uuid)
    TO casablanca_api;

GRANT SELECT (id, codigo, icono_codigo, activo)
    ON public.categoria_atractivo TO casablanca_consulta_owner;

GRANT SELECT (categoria_id, idioma_codigo, nombre)
    ON public.categoria_atractivo_traduccion
    TO casablanca_consulta_owner;

REVOKE ALL ON FUNCTION public.listar_categorias_activas(text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_consulta_owner;

ALTER FUNCTION public.listar_categorias_activas(text)
    OWNER TO casablanca_consulta_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_consulta_owner;

GRANT EXECUTE ON FUNCTION public.listar_categorias_activas(text)
    TO casablanca_api;

GRANT SELECT (id, estado, imagen_principal, ubicacion)
    ON public.atractivo TO casablanca_consulta_owner;

GRANT SELECT (
    atractivo_id, idioma_codigo, nombre,
    descripcion, imagen_texto_alternativo
)
ON public.atractivo_traduccion TO casablanca_consulta_owner;

GRANT SELECT (atractivo_id, categoria_id)
    ON public.atractivo_categoria TO casablanca_consulta_owner;

REVOKE ALL ON FUNCTION public.listar_atractivos_publicados(text, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_consulta_owner;

ALTER FUNCTION public.listar_atractivos_publicados(text, uuid)
    OWNER TO casablanca_consulta_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_consulta_owner;

GRANT EXECUTE ON FUNCTION public.listar_atractivos_publicados(text, uuid)
    TO casablanca_api;

REVOKE ALL ON FUNCTION
    public.listar_categorias_atractivo_publicado(uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_consulta_owner;

ALTER FUNCTION public.listar_categorias_atractivo_publicado(uuid, text)
    OWNER TO casablanca_consulta_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_consulta_owner;

GRANT EXECUTE ON FUNCTION
    public.listar_categorias_atractivo_publicado(uuid, text)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.admin_listar_atractivos(text, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_listar_atractivos(text, text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_listar_atractivos(text, text)
    TO casablanca_api;

GRANT SELECT (codigo, icono_codigo)
    ON public.categoria_atractivo TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_listar_categorias_atractivo(text, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_listar_categorias_atractivo(text, text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_listar_categorias_atractivo(text, text)
    TO casablanca_api;

GRANT UPDATE (icono_codigo)
    ON public.categoria_atractivo TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_actualizar_icono_categoria(text, uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_actualizar_icono_categoria(
    text, uuid, text
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_actualizar_icono_categoria(text, uuid, text)
    TO casablanca_api;

GRANT SELECT (imagen_principal)
    ON public.ruta TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_listar_rutas(text, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_listar_rutas(text, text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_listar_rutas(text, text)
    TO casablanca_api;

GRANT SELECT (atractivo_id, imagen_principal, ubicacion)
    ON public.ruta_parada TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_listar_ruta_paradas(text, uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_listar_ruta_paradas(text, uuid, text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_listar_ruta_paradas(text, uuid, text)
    TO casablanca_api;

REVOKE ALL ON FUNCTION
    public.admin_listar_categorias_atractivo_asignadas(text, uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_listar_categorias_atractivo_asignadas(
    text, uuid, text
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_listar_categorias_atractivo_asignadas(text, uuid, text)
    TO casablanca_api;

REVOKE ALL ON FUNCTION
    public.comprobar_ruta_atractivos_publicados(uuid)
    FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
    public.comprobar_ruta_atractivos_publicados(uuid)
    TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.recorrido_parada_validar()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.recorrido_usuario_validar_cambio()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.recorrido_parada_impedir_borrado()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.recorrido_usuario_validar_fijacion()
    FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO casablanca_recorrido_owner;

GRANT EXECUTE ON FUNCTION public.validar_sesion(text)
    TO casablanca_recorrido_owner;

GRANT SELECT (id, estado)
    ON public.ruta TO casablanca_recorrido_owner;

GRANT UPDATE (actualizado_en)
    ON public.ruta TO casablanca_recorrido_owner;

GRANT SELECT (id, ruta_id, orden)
    ON public.ruta_parada TO casablanca_recorrido_owner;

GRANT INSERT (usuario_id, ruta_id, iniciado_en)
    ON public.recorrido_usuario TO casablanca_recorrido_owner;

GRANT SELECT (
    id, usuario_id, ruta_id, estado,
    iniciado_en, finalizado_en, pasos_fijados
)
ON public.recorrido_usuario TO casablanca_recorrido_owner;

GRANT UPDATE (pasos_fijados)
    ON public.recorrido_usuario TO casablanca_recorrido_owner;

GRANT INSERT (recorrido_id, parada_id, orden)
    ON public.recorrido_parada TO casablanca_recorrido_owner;

GRANT SELECT (id, recorrido_id, parada_id, orden, registrado_en)
    ON public.recorrido_parada TO casablanca_recorrido_owner;

REVOKE ALL ON FUNCTION public.iniciar_recorrido(text, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_recorrido_owner;

ALTER FUNCTION public.iniciar_recorrido(text, uuid)
    OWNER TO casablanca_recorrido_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_recorrido_owner;

GRANT EXECUTE ON FUNCTION public.iniciar_recorrido(text, uuid)
    TO casablanca_api;

GRANT UPDATE (registrado_en)
    ON public.recorrido_parada TO casablanca_recorrido_owner;

REVOKE ALL ON FUNCTION public.registrar_paso_recorrido(text, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_recorrido_owner;

ALTER FUNCTION public.registrar_paso_recorrido(text, uuid)
    OWNER TO casablanca_recorrido_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_recorrido_owner;

GRANT EXECUTE ON FUNCTION public.registrar_paso_recorrido(text, uuid)
    TO casablanca_api;

GRANT UPDATE (estado, finalizado_en)
    ON public.recorrido_usuario TO casablanca_recorrido_owner;

REVOKE ALL ON FUNCTION
    public.cerrar_recorrido(text, uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_recorrido_owner;

ALTER FUNCTION public.cerrar_recorrido(text, uuid, text)
    OWNER TO casablanca_recorrido_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_recorrido_owner;

GRANT EXECUTE ON FUNCTION
    public.cerrar_recorrido(text, uuid, text)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.obtener_mi_recorrido(text, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_recorrido_owner;

ALTER FUNCTION public.obtener_mi_recorrido(text, uuid)
    OWNER TO casablanca_recorrido_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_recorrido_owner;

GRANT EXECUTE ON FUNCTION public.obtener_mi_recorrido(text, uuid)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.listar_mis_paradas_recorrido(text, uuid)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_recorrido_owner;

ALTER FUNCTION public.listar_mis_paradas_recorrido(text, uuid)
    OWNER TO casablanca_recorrido_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_recorrido_owner;

GRANT EXECUTE ON FUNCTION public.listar_mis_paradas_recorrido(text, uuid)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.listar_mis_recorridos(text, integer, integer)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_recorrido_owner;

ALTER FUNCTION public.listar_mis_recorridos(text, integer, integer)
    OWNER TO casablanca_recorrido_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_recorrido_owner;

GRANT EXECUTE ON FUNCTION public.listar_mis_recorridos(text, integer, integer)
    TO casablanca_api;

REVOKE ALL ON FUNCTION public.recorrido_parada_proteger_origen()
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_recorrido_owner;

ALTER FUNCTION public.recorrido_parada_proteger_origen()
    OWNER TO casablanca_recorrido_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_recorrido_owner;

REVOKE ALL ON FUNCTION public.qr_parada_proteger_identidad()
    FROM PUBLIC;

GRANT SELECT (id, parada_id, activo)
ON public.qr_parada
TO casablanca_admin_owner;

GRANT INSERT (parada_id)
ON public.qr_parada
TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_obtener_o_crear_qr_parada(text, uuid)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_obtener_o_crear_qr_parada(text, uuid)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_obtener_o_crear_qr_parada(text, uuid)
TO casablanca_api;

GRANT UPDATE (activo)
ON public.qr_parada
TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_cambiar_activacion_qr(text, uuid, boolean)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_cambiar_activacion_qr(text, uuid, boolean)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_cambiar_activacion_qr(text, uuid, boolean)
TO casablanca_api;

GRANT SELECT (id, parada_id, activo)
ON public.qr_parada
TO casablanca_consulta_owner;

REVOKE ALL ON FUNCTION public.obtener_contenido_qr(uuid, text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_consulta_owner;

ALTER FUNCTION public.obtener_contenido_qr(uuid, text)
    OWNER TO casablanca_consulta_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_consulta_owner;

GRANT EXECUTE ON FUNCTION public.obtener_contenido_qr(uuid, text)
    TO casablanca_api;

GRANT SELECT (id, parada_id, activo)
ON public.qr_parada
TO casablanca_recorrido_owner;

REVOKE ALL ON FUNCTION
    public.registrar_paso_por_qr(text, uuid, uuid)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_recorrido_owner;

ALTER FUNCTION public.registrar_paso_por_qr(text, uuid, uuid)
    OWNER TO casablanca_recorrido_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_recorrido_owner;

GRANT EXECUTE ON FUNCTION
    public.registrar_paso_por_qr(text, uuid, uuid)
TO casablanca_api;

REVOKE ALL ON FUNCTION public.registrar_paso_recorrido(text, uuid)
    FROM PUBLIC;

REVOKE ALL ON FUNCTION public.registrar_paso_recorrido(text, uuid)
    FROM casablanca_api;

GRANT DELETE ON public.qr_parada
    TO casablanca_admin_owner;

GRANT UPDATE (activo)
ON public.qr_parada
TO casablanca_recorrido_owner;

GRANT SELECT (
    ruta_id, estado, iniciado_en, pasos_fijados
)
ON public.recorrido_usuario
TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION
    public.admin_estadisticas_recorridos(text, timestamptz, timestamptz)
FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_estadisticas_recorridos(
    text, timestamptz, timestamptz
)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_estadisticas_recorridos(text, timestamptz, timestamptz)
TO casablanca_api;

GRANT SELECT (id, estado, email_verificado_en)
ON public.usuario
TO casablanca_admin_owner;

GRANT SELECT (
    usuario_id, edad_declarada, nacionalidad_codigo, genero_codigo
)
ON public.perfil_turista
TO casablanca_admin_owner;

GRANT SELECT (codigo)
ON public.pais
TO casablanca_admin_owner;

REVOKE ALL ON FUNCTION public.admin_estadisticas_perfiles(text)
    FROM PUBLIC;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_estadisticas_perfiles(text)
    OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION public.admin_estadisticas_perfiles(text)
    TO casablanca_api;

REVOKE ALL ON FUNCTION
    public.atractivo_actualizar_fecha(),
    public.atractivo_traduccion_actualizar_fecha(),
    public.perfil_turista_actualizar_fechas(),
    public.ruta_actualizar_fecha(),
    public.ruta_parada_actualizar_fecha(),
    public.ruta_parada_traduccion_actualizar_fecha(),
    public.ruta_traduccion_actualizar_fecha(),
    public.usuario_actualizar_fecha()
FROM PUBLIC, casablanca_api;

ALTER FUNCTION public.usuario_actualizar_fecha()
    SET search_path = pg_catalog, pg_temp;

GRANT USAGE ON SCHEMA public
    TO casablanca_autenticacion_owner;

GRANT SELECT (
    id,
    email,
    password_hash,
    estado,
    email_verificado_en
)
ON public.usuario
TO casablanca_autenticacion_owner;

REVOKE ALL ON FUNCTION public.obtener_credenciales_login(text)
    FROM PUBLIC, casablanca_api;

GRANT CREATE ON SCHEMA public
    TO casablanca_autenticacion_owner;

ALTER FUNCTION public.obtener_credenciales_login(text)
    OWNER TO casablanca_autenticacion_owner;

REVOKE CREATE ON SCHEMA public
    FROM casablanca_autenticacion_owner;

GRANT EXECUTE ON FUNCTION public.obtener_credenciales_login(text)
    TO casablanca_api;

-- Descripción de objetos

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';

COMMENT ON TABLE public.perfil_turista IS
'Perfil declarado para segmentacion turistica. Su existencia no implica correo verificado ni permiso administrativo.';

COMMENT ON COLUMN public.perfil_turista.edad_declarada IS
'Edad declarada en edad_declarada_en; no se actualiza automaticamente al cumplir años.';

COMMENT ON COLUMN public.perfil_turista.genero_detalle IS
'Descripcion opcional de otra identidad, hasta 100 caracteres. No publicar en reportes agregados.';

COMMENT ON FUNCTION public.registrar_turista(
    text, text, text, integer, text, text, text
) IS
    'Crea usuario pendiente, rol turista y perfil conjuntamente. El backend genera el hash Argon2id.';

COMMENT ON TABLE public.verificacion_email IS
    'Solicitudes de verificación de correo. Su emisión y consumo requieren funciones controladas.';

COMMENT ON COLUMN public.verificacion_email.token_hash IS
    'SHA-256 hexadecimal en minúsculas del token aleatorio. No guardar aquí el token original.';

COMMENT ON COLUMN public.verificacion_email.revocado_en IS
    'Momento de invalidación anticipada; NULL si no fue revocado.';

COMMENT ON FUNCTION public.emitir_verificacion_email(uuid) IS
    'Emite un token para envío interno del backend al correo registrado; guarda SHA-256, revoca anteriores y aplica límites por cuenta.';

COMMENT ON FUNCTION public.confirmar_email(text) IS
    'Consume un token vigente y activa una cuenta pendiente conjuntamente. Rechaza tokens inexistentes, vencidos, consumidos o revocados.';

COMMENT ON TABLE public.sesion_usuario IS
    'Sesiones de usuarios. Su uso requiere comprobar vencimiento, revocación y estado actual de la cuenta.';

COMMENT ON COLUMN public.sesion_usuario.token_hash IS
    'SHA-256 hexadecimal del token de sesión. El token original no se almacena en esta tabla.';

COMMENT ON COLUMN public.sesion_usuario.revocado_en IS
    'Momento de cierre o invalidación de la sesión; NULL si no fue revocada.';

COMMENT ON FUNCTION public.crear_sesion(uuid) IS
    'Emite una sesión de 8 horas para una cuenta activa y verificada. Requiere autenticación previa de contraseña en el backend.';

COMMENT ON FUNCTION public.validar_sesion(text) IS
    'Devuelve el usuario de una sesión vigente y no revocada, con cuenta activa y verificada; NULL si no cumple.';

COMMENT ON FUNCTION public.cerrar_sesion(text) IS
    'Revoca únicamente la sesión del token recibido. Devuelve true si la revocó y false si no encontró una sesión sin revocar.';

COMMENT ON FUNCTION public.obtener_mi_perfil(text) IS
    'Devuelve únicamente el perfil del usuario identificado por una sesión válida. No devuelve contraseñas ni acepta un usuario_id del cliente.';

COMMENT ON FUNCTION public.actualizar_mi_perfil(
    text, integer, text, text, text
) IS
    'Actualiza edad, nacionalidad y género del usuario de una sesión válida. No permite cambiar identidad, correo, estado ni roles.';

COMMENT ON TABLE public.atractivo IS
    'Lugar turístico independiente de sus traducciones y de las rutas que lo incluyen.';

COMMENT ON COLUMN public.atractivo.ubicacion IS
    'Punto en WGS84 (SRID 4326): longitud primero, latitud después.';

COMMENT ON COLUMN public.atractivo.imagen_principal IS
    'Referencia a la imagen principal, no el contenido binario del archivo.';

COMMENT ON TABLE public.atractivo_traduccion IS
    'Contenido por idioma de cada atractivo; la clave compuesta evita traducciones duplicadas.';

COMMENT ON COLUMN public.atractivo_traduccion.imagen_texto_alternativo IS
    'Descripción de la imagen en este idioma para lectores de pantalla; no sustituye la descripción del lugar.';

COMMENT ON TABLE public.categoria_atractivo IS
    'Clasificaciones de atractivos con códigos estables y nombres traducidos en una tabla separada.';

COMMENT ON COLUMN public.categoria_atractivo.icono_codigo IS
    'Identificador que el frontend resuelve a un icono admitido; no contiene código ejecutable.';

COMMENT ON COLUMN public.categoria_atractivo.activo IS
    'Permite deshabilitar la categoría sin eliminar sus relaciones existentes.';

COMMENT ON TABLE public.categoria_atractivo_traduccion IS
    'Nombre visible de cada categoría por idioma; no duplica la identidad de la categoría.';

COMMENT ON TABLE public.atractivo_categoria IS
    'Asigna varias categorías a un atractivo sin duplicar lugares ni repetir asignaciones.';

COMMENT ON TABLE public.ruta IS
    'Recorrido turístico independiente de sus traducciones y paradas. Los itinerarios reales requieren validación con el mandante.';

COMMENT ON COLUMN public.ruta.duracion_estimada_minutos IS
    'Duración total estimada en minutos; positiva si se informa y obligatoria para publicar.';

COMMENT ON COLUMN public.ruta.imagen_principal IS
    'Referencia opcional a la imagen de presentación de la ruta.';

COMMENT ON TABLE public.ruta_traduccion IS
    'Textos de presentación de una ruta por idioma; no contiene el itinerario ni sus paradas.';

COMMENT ON COLUMN public.ruta_traduccion.imagen_texto_alternativo IS
    'Descripción de la portada de la ruta en este idioma para lectores de pantalla.';

COMMENT ON TABLE public.ruta_parada IS
    'Punto ordenado de una ruta; puede representar una parada exterior o interior. Los recorridos reales requieren validación.';

COMMENT ON COLUMN public.ruta_parada.ubicacion IS
    'Ubicación opcional del punto en WGS84; no exige coordenadas individuales para paradas interiores.';

COMMENT ON COLUMN public.ruta_parada.atractivo_id IS
    'Atractivo asociado opcionalmente; varias paradas pueden pertenecer al mismo atractivo.';

COMMENT ON TABLE public.ruta_parada_traduccion IS
    'Nombre y contenido de una parada por idioma, incluidos puntos interiores sin coordenadas propias.';

COMMENT ON COLUMN public.ruta_parada_traduccion.imagen_texto_alternativo IS
    'Descripción de la imagen de la parada en este idioma para lectores de pantalla.';

COMMENT ON FUNCTION public.comprobar_ruta_publicable(uuid) IS
    'Comprueba duración positiva, traducciones es/en y paradas consecutivas con traducciones es/en. Lanza una excepción si falta contenido.';

COMMENT ON TRIGGER ruta_publicacion_completa_trg
ON public.ruta IS
    'Al finalizar la transacción, exige contenido completo si la ruta queda publicada.';

COMMENT ON TRIGGER ruta_traduccion_marcar_cambio_trg
ON public.ruta_traduccion IS
    'Actualiza y bloquea la ruta al modificar sus traducciones, activando la validación diferida de publicación.';

COMMENT ON TRIGGER ruta_parada_marcar_cambio_trg
ON public.ruta_parada IS
    'Los cambios de paradas bloquean y actualizan su ruta para comprobar la publicación al finalizar la transacción.';

COMMENT ON TRIGGER ruta_parada_traduccion_marcar_cambio_trg
ON public.ruta_parada_traduccion IS
    'Los cambios de traducciones de paradas activan la comprobación diferida de su ruta.';

COMMENT ON FUNCTION public.exigir_administrador(text) IS
    'Función interna: devuelve la identidad de una sesión válida con rol administrador; rechaza el acceso en caso contrario. No asigna roles.';

COMMENT ON FUNCTION public.admin_crear_ruta(text) IS
    'Crea una ruta en borrador tras comprobar la sesión y el rol administrador. Devuelve su identificador.';

COMMENT ON FUNCTION
    public.admin_actualizar_ruta(text, uuid, integer, text) IS
    'Exige administrador y reemplaza duración e imagen de una ruta. NULL elimina el valor. No cambia su estado; las restricciones de publicación siguen aplicándose.';

COMMENT ON FUNCTION public.admin_guardar_ruta_traduccion(
    text, uuid, text, text, text, text
) IS
    'Exige administrador y crea o actualiza una traducción de ruta. Reemplaza sus textos; NULL elimina el texto alternativo. Conserva las reglas de publicación.';

COMMENT ON FUNCTION public.admin_crear_ruta_parada(
    text, uuid, integer, uuid, text, double precision, double precision
) IS
    'Exige administrador y crea una parada. Atractivo, imagen y coordenadas son opcionales; longitud y latitud deben proporcionarse juntas. Mantiene las reglas de publicación.';

COMMENT ON FUNCTION public.admin_guardar_parada_traduccion(
    text, uuid, text, text, text, text
) IS
    'Exige administrador y crea o actualiza una traducción de parada. Reemplaza sus textos; NULL elimina el texto alternativo. Mantiene las reglas de publicación de la ruta.';

COMMENT ON FUNCTION public.admin_publicar_ruta(text, uuid) IS
    'Exige administrador, bloquea la ruta, comprueba su contenido y cambia su estado a publicado. La revisión diferida protege el resultado final de la transacción.';

COMMENT ON FUNCTION public.admin_retirar_ruta(text, uuid, text) IS
    'Exige administrador y cambia la ruta a borrador o archivado sin borrar su contenido. No permite publicar.';

COMMENT ON FUNCTION public.admin_actualizar_ruta_parada(
    text, uuid, uuid, text, double precision, double precision
) IS
    'Exige administrador y reemplaza atractivo, imagen y ubicación de una parada. NULL elimina los valores opcionales. No cambia ruta ni orden.';

COMMENT ON CONSTRAINT ruta_parada_orden_unico
ON public.ruta_parada IS
    'Evita posiciones repetidas por ruta y permite intercambiarlas en una sola instrucción, comprobando la unicidad al finalizarla.';

COMMENT ON FUNCTION public.admin_reordenar_ruta_paradas(
    text, uuid, uuid[]
) IS
    'Exige administrador y la lista completa de paradas de una ruta, sin nulos ni duplicados. Asigna posiciones consecutivas desde 1 en el orden recibido.';

COMMENT ON FUNCTION public.listar_rutas_publicadas(text) IS
    'Lista exclusivamente rutas publicadas con sus textos en es o en. No requiere sesión y no modifica datos.';

COMMENT ON FUNCTION public.listar_paradas_ruta_publicada(uuid, text) IS
    'Devuelve las paradas de una ruta publicada, ordenadas y traducidas a es o en. Usa sus imágenes y coordenadas propias, que pueden ser NULL. No requiere sesión.';

COMMENT ON FUNCTION public.admin_eliminar_ruta_parada(text, uuid) IS
    'Requiere administrador y ruta en borrador. Elimina el QR, las traducciones y la parada, y compacta el orden restante. Si un recorrido abierto impide la eliminación, se revierten todos los cambios de la llamada.';

COMMENT ON FUNCTION public.asignar_administrador_inicial(uuid) IS
    'Preparación desde una conexión administrativa: asigna el primer administrador a una cuenta activa y verificada. Rechaza la operación si ya existe una asignación. No está disponible para la API.';

COMMENT ON FUNCTION public.admin_crear_atractivo(text) IS
    'Exige una sesión de administrador y crea un atractivo en borrador. Devuelve su identificador.';

COMMENT ON FUNCTION public.admin_actualizar_atractivo(
    text, uuid, text, double precision, double precision
) IS
    'Exige administrador y reemplaza imagen y ubicación del atractivo. NULL elimina los valores opcionales en borrador. No cambia el estado; conserva las restricciones de publicación.';

COMMENT ON FUNCTION public.admin_guardar_atractivo_traduccion(
    text, uuid, text, text, text, text
) IS
    'Exige administrador y crea o actualiza una traducción del atractivo. Reemplaza los textos; NULL elimina el texto alternativo.';

COMMENT ON FUNCTION public.comprobar_atractivo_publicable(uuid) IS
    'Comprueba imagen, ubicación y traducciones es/en del atractivo. Lanza una excepción si falta contenido. No verifica el archivo real de imagen.';

COMMENT ON TRIGGER atractivo_publicacion_completa_trg
ON public.atractivo IS
    'Comprueba al finalizar la transacción que un atractivo publicado conserve imagen, ubicación y traducciones es/en.';

COMMENT ON TRIGGER atractivo_traduccion_marcar_cambio_trg
ON public.atractivo_traduccion IS
    'Después de cambiar traducciones, bloquea y actualiza el atractivo para activar su revisión de publicación.';

COMMENT ON FUNCTION public.admin_publicar_atractivo(text, uuid) IS
    'Exige administrador, bloquea el atractivo, comprueba imagen, ubicación y traducciones es/en, y cambia su estado a publicado.';

COMMENT ON FUNCTION public.admin_retirar_atractivo(text, uuid, text) IS
    'Exige administrador y cambia el atractivo a borrador o archivado sin eliminar sus datos ni relaciones. No permite publicar ni cambia el estado de rutas vinculadas.';

COMMENT ON FUNCTION public.admin_crear_categoria_atractivo(
    text, text, text
) IS
    'Exige administrador y crea una categoría inactiva con código único y referencia de icono. No comprueba que el icono exista en el frontend.';

COMMENT ON FUNCTION public.admin_guardar_categoria_traduccion(
    text, uuid, text, text
) IS
    'Exige administrador y crea o actualiza el nombre de una categoría en es o en, sin duplicar el idioma.';

COMMENT ON FUNCTION public.comprobar_categoria_activable(uuid) IS
    'Comprueba que una categoría exista y tenga nombres en es y en antes de activarla. No verifica la existencia real del icono.';

COMMENT ON TRIGGER categoria_activacion_completa_trg
ON public.categoria_atractivo IS
    'Al finalizar la transacción, exige traducciones es/en si la categoría queda activa.';

COMMENT ON TRIGGER categoria_traduccion_marcar_cambio_trg
ON public.categoria_atractivo_traduccion IS
    'Después de cambiar traducciones, bloquea la categoría y activa su revisión diferida.';

COMMENT ON FUNCTION public.admin_cambiar_activacion_categoria(
    text, uuid, boolean
) IS
    'Exige administrador y activa o desactiva una categoría. Activar requiere traducciones es/en; desactivar conserva textos y asignaciones.';

COMMENT ON FUNCTION public.admin_asignar_categoria_atractivo(
    text, uuid, uuid
) IS
    'Exige administrador y vincula una categoría existente, activa o inactiva, con un atractivo existente. Devuelve true si crea el vínculo y false si ya existía.';

COMMENT ON FUNCTION public.admin_quitar_categoria_atractivo(
    text, uuid, uuid
) IS
    'Exige administrador y elimina únicamente la asignación de categoría al atractivo. Devuelve true si eliminó el vínculo y false si no existía.';

COMMENT ON FUNCTION public.listar_categorias_activas(text) IS
    'Lista categorías activas con nombre en es o en y código de icono. No requiere sesión ni modifica datos.';

COMMENT ON FUNCTION public.listar_atractivos_publicados(text, uuid) IS
    'Lista atractivos publicados en es o en con imagen y coordenadas. El filtro opcional acepta solo categorías activas; una categoría inactiva o inexistente devuelve cero filas. No requiere sesión.';

COMMENT ON FUNCTION public.listar_categorias_atractivo_publicado(
    uuid, text
) IS
    'Devuelve las categorías activas de un atractivo publicado, traducidas a es o en. Oculta categorías inactivas y atractivos no publicados. No requiere sesión.';

COMMENT ON FUNCTION public.admin_listar_atractivos(text, text) IS
    'Exige administrador y lista atractivos de todos los estados. Incluye los que aún carecen de traducción en el idioma solicitado, devolviendo sus textos como NULL.';

COMMENT ON FUNCTION public.admin_listar_categorias_atractivo(
    text, text
) IS
    'Exige administrador y lista categorías activas e inactivas. Incluye categorías sin traducción en el idioma solicitado, con nombre NULL.';

COMMENT ON FUNCTION public.admin_actualizar_icono_categoria(
    text, uuid, text
) IS
    'Exige administrador y cambia únicamente el código de icono. Valida formato y longitud, pero no comprueba que el icono exista en el frontend.';

COMMENT ON FUNCTION public.admin_listar_rutas(text, text) IS
    'Exige administrador y lista rutas de todos los estados. Incluye rutas sin traducción en el idioma solicitado, devolviendo sus textos como NULL.';

COMMENT ON FUNCTION public.admin_listar_ruta_paradas(
    text, uuid, text
) IS
    'Exige administrador y lista las paradas ordenadas de una ruta de cualquier estado. Incluye paradas sin traducción, devolviendo textos NULL. Rechaza rutas inexistentes.';

COMMENT ON FUNCTION public.admin_listar_categorias_atractivo_asignadas(
    text, uuid, text
) IS
    'Exige administrador y lista las categorías asignadas a un atractivo de cualquier estado. Incluye categorías inactivas y sin traducción, con nombre NULL. Rechaza atractivos inexistentes.';

COMMENT ON FUNCTION public.comprobar_ruta_atractivos_publicados(uuid) IS
    'Coordina la revisión mediante actualizaciones de los atractivos vinculados y comprueba que estén publicados. Actualiza sus fechas; permite paradas sin atractivo vinculado.';

COMMENT ON TABLE public.recorrido_usuario IS
    'Intentos de usuarios registrados de seguir rutas establecidas. No permite construir itinerarios personalizados.';

COMMENT ON COLUMN public.recorrido_usuario.finalizado_en IS
    'Fecha de cierre del intento, tanto por finalización como por abandono.';

COMMENT ON TABLE public.recorrido_parada IS
    'Paradas incluidas al iniciar un intento, con su orden y fecha de registro. Conserva los pasos aunque se elimine la parada original; no copia sus textos.';

COMMENT ON COLUMN public.recorrido_parada.parada_id IS
    'Referencia a la parada original. Queda NULL si se elimina; el paso del recorrido se conserva.';

COMMENT ON COLUMN public.recorrido_parada.registrado_en IS
    'Fecha de registro del paso. NULL indica pendiente. No acredita por sí sola una visita física.';

COMMENT ON TRIGGER recorrido_parada_validar_trg
ON public.recorrido_parada IS
    'Comprueba pertenencia a la ruta, protege identidad y orden histórico, y permite registrar cada paso una vez mientras el recorrido esté en curso. Permite perder la referencia original por eliminación.';

COMMENT ON TRIGGER recorrido_usuario_validar_cambio_trg
ON public.recorrido_usuario IS
    'Protege identidad e inicio, exige todos los pasos registrados para completar y evita modificar o reabrir intentos cerrados.';

COMMENT ON TRIGGER recorrido_parada_impedir_borrado_trg
ON public.recorrido_parada IS
    'Impide borrar pasos históricos o quitar pendientes para completar un intento. No impide que la FK deje parada_id NULL al eliminar la parada original.';

COMMENT ON COLUMN public.recorrido_usuario.pasos_fijados IS
    'Indicador interno: pasa a true después de copiar y validar las paradas iniciales. Impedirá añadir pasos o volver a modificar la lista.';

COMMENT ON TRIGGER recorrido_usuario_validar_fijacion_trg
ON public.recorrido_usuario IS
    'Exige que la lista inicial coincida con la ruta al fijarla, impide reabrirla y exige fijación antes del cierre.';

COMMENT ON FUNCTION public.iniciar_recorrido(text, uuid) IS
    'Obtiene el usuario desde una sesión válida e inicia una ruta publicada, copiando y fijando sus paradas en una operación atómica. No acepta una identidad ni un itinerario del cliente.';

COMMENT ON FUNCTION public.registrar_paso_recorrido(text, uuid) IS
    'Operación anterior de registro por paso, sin permiso de ejecución para la API. El registro de la aplicación se realiza mediante registrar_paso_por_qr.';

COMMENT ON FUNCTION public.cerrar_recorrido(text, uuid, text) IS
    'Cierra un recorrido propio. Completar exige ruta publicada y todos los pasos registrados; abandonar se permite aunque la ruta esté retirada. Conserva los cierres previos y usa la hora del servidor.';

COMMENT ON FUNCTION public.obtener_mi_recorrido(text, uuid) IS
    'Consulta un recorrido propio y cuenta sus paradas fijadas y registradas. Devuelve cero filas si no existe o pertenece a otro usuario.';

COMMENT ON FUNCTION public.listar_mis_paradas_recorrido(text, uuid) IS
    'Lista los pasos de un recorrido propio en su orden fijado. registrado_en NULL indica pendiente; parada_id puede ser NULL si se eliminó la parada original.';

COMMENT ON FUNCTION public.listar_mis_recorridos(text, integer, integer) IS
    'Lista únicamente los recorridos fijados del usuario autenticado, con conteos de progreso y orden del más reciente al más antiguo. Límite de 1 a 100; desplazamiento no negativo.';

COMMENT ON FUNCTION public.recorrido_parada_proteger_origen() IS
    'Impide perder la referencia a una parada original mientras el recorrido esté en curso. Permite conservar pasos históricos de recorridos cerrados mediante ON DELETE SET NULL.';

COMMENT ON TRIGGER recorrido_parada_proteger_origen_trg
ON public.recorrido_parada IS
    'Protege recorridos abiertos ante la eliminación de su parada original; no impide editar el contenido de la parada.';

COMMENT ON TABLE public.qr_parada IS
    'Identificador estable de la señalética QR de una parada; independiente de las actualizaciones de su contenido.';

COMMENT ON COLUMN public.qr_parada.id IS
    'Identificador usado para construir la dirección del QR. Es público y no constituye una credencial de autenticación.';

COMMENT ON COLUMN public.qr_parada.parada_id IS
    'Parada cuyo contenido identifica el QR. Solo se admite un QR por parada.';

COMMENT ON COLUMN public.qr_parada.activo IS
    'Permite deshabilitar el QR conservando su identificador. Las operaciones de consulta y registro deberán comprobar este valor.';

COMMENT ON COLUMN public.qr_parada.creado_en IS
    'Fecha de creación del identificador QR.';

COMMENT ON FUNCTION public.qr_parada_proteger_identidad() IS
    'Impide cambiar el identificador, la parada asociada o la fecha de creación de un QR existente; permite modificar su activación.';

COMMENT ON TRIGGER qr_parada_proteger_identidad_trg
ON public.qr_parada IS
    'Mantiene estable la identidad y el destino de la señalética QR ante actualizaciones.';

COMMENT ON FUNCTION
    public.admin_obtener_o_crear_qr_parada(text, uuid) IS
    'Requiere administrador. Crea el QR de una parada o devuelve su identificador existente, sin cambiar su destino ni reactivar códigos deshabilitados.';

COMMENT ON FUNCTION
    public.admin_cambiar_activacion_qr(text, uuid, boolean) IS
    'Requiere administrador. Activa o desactiva un QR sin modificar su identidad ni destino. Devuelve true si existe, incluso cuando ya tenía el estado solicitado.';

COMMENT ON FUNCTION public.obtener_contenido_qr(uuid, text) IS
    'Consulta sin sesión el contenido vigente de una parada por QR activo y ruta publicada, en español o inglés. No registra progreso. Devuelve cero filas si no hay contenido disponible.';

COMMENT ON FUNCTION public.registrar_paso_por_qr(text, uuid, uuid) IS
    'Registra una vez un paso fijado de un recorrido propio abierto mediante QR activo. Exige ruta publicada y coordina con su retiro mediante bloqueo. Conserva el progreso anterior; no acredita presencia física.';

COMMENT ON FUNCTION public.admin_estadisticas_recorridos(
    text, timestamptz, timestamptz
) IS
    'Requiere administrador. Por ruta, cuenta intentos fijados iniciados en [desde, hasta) y sus estados actuales. Incluye rutas sin intentos; porcentaje NULL si no hay iniciados. No devuelve identificadores personales ni acredita visitas físicas.';

COMMENT ON FUNCTION public.admin_estadisticas_perfiles(text) IS
    'Requiere administrador. Cuenta perfiles de cuentas activas y verificadas por edad declarada agrupada, nacionalidad y género, sin cruces ni datos identificadores. Enumera todos los grupos y oculta cantidades inferiores a cinco, incluido cero, mediante NULL. Reduce riesgos de identificación sin garantizar anonimato absoluto.';

COMMENT ON FUNCTION public.obtener_credenciales_login(text) IS
    'Consulta interna del backend: devuelve id y hash de una cuenta activa y verificada por correo normalizado. No verifica contraseña ni crea sesión. El hash nunca debe devolverse al cliente.';



GRANT DELETE ON
    public.categoria_atractivo,
    public.categoria_atractivo_traduccion
TO casablanca_admin_owner;

GRANT SELECT (categoria_id)
ON public.atractivo_categoria
TO casablanca_admin_owner;

CREATE FUNCTION public.admin_eliminar_categoria_atractivo(
    p_token text,
    p_categoria_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);

    IF p_categoria_id IS NULL THEN
        RAISE EXCEPTION 'Debe indicar la categoría'
            USING ERRCODE = '22023';
    END IF;

    -- Coordina con ediciones y nuevas relaciones.
    PERFORM 1
    FROM public.categoria_atractivo
    WHERE id = p_categoria_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.atractivo_categoria
        WHERE categoria_id = p_categoria_id
    ) THEN
        RAISE EXCEPTION
            'No se puede eliminar una categoría vinculada a atractivos'
            USING ERRCODE = '23503';
    END IF;

    -- Permite retirar sus traducciones sin exigir contenido activo.
    UPDATE public.categoria_atractivo
    SET activo = false
    WHERE id = p_categoria_id;

    DELETE FROM public.categoria_atractivo_traduccion
    WHERE categoria_id = p_categoria_id;

    DELETE FROM public.categoria_atractivo
    WHERE id = p_categoria_id;

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION
    public.admin_eliminar_categoria_atractivo(text, uuid)
FROM PUBLIC, casablanca_api;

GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;

ALTER FUNCTION public.admin_eliminar_categoria_atractivo(text, uuid)
OWNER TO casablanca_admin_owner;

REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;

GRANT EXECUTE ON FUNCTION
    public.admin_eliminar_categoria_atractivo(text, uuid)
TO casablanca_api;

COMMENT ON FUNCTION
    public.admin_eliminar_categoria_atractivo(text, uuid) IS
    'Elimina una categoría y sus traducciones mediante sesión administrativa. Rechaza categorías vinculadas a atractivos; devuelve false si no existe.';



GRANT UPDATE (id) ON public.usuario TO casablanca_sesion_owner;

CREATE OR REPLACE FUNCTION public.crear_sesion(p_usuario_id uuid)
RETURNS TABLE (
    sesion_id uuid,
    token_original text,
    vence_en timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_sesion_id uuid;
    v_token text;
    v_ahora timestamptz;
    v_expira_en timestamptz;
BEGIN
    -- Serializa emisión de sesiones con el bloqueo de la cuenta.
    PERFORM 1
        FROM public.usuario AS u
        WHERE u.id = p_usuario_id
          AND u.estado = 'activo'
          AND u.email_verificado_en IS NOT NULL
    FOR UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    v_ahora := clock_timestamp();
    v_expira_en := v_ahora + interval '8 hours';

    -- Token aleatorio de 256 bits, representado en hexadecimal.
    v_token := encode(public.gen_random_bytes(32), 'hex');

    INSERT INTO public.sesion_usuario (
        usuario_id, token_hash, creado_en, expira_en
    )
    VALUES (
        p_usuario_id,
        encode(public.digest(v_token, 'sha256'), 'hex'),
        v_ahora,
        v_expira_en
    )
    RETURNING id INTO v_sesion_id;

    RETURN QUERY SELECT v_sesion_id, v_token, v_expira_en;
END;
$$;

GRANT SELECT (id, email, nombre, estado, email_verificado_en, creado_en)
ON public.usuario TO casablanca_admin_owner;
GRANT UPDATE (estado) ON public.usuario TO casablanca_admin_owner;
GRANT SELECT (usuario_id, revocado_en) ON public.sesion_usuario TO casablanca_admin_owner;
GRANT UPDATE (revocado_en) ON public.sesion_usuario TO casablanca_admin_owner;

CREATE OR REPLACE FUNCTION public.obtener_contexto_sesion(p_token text)
RETURNS TABLE (usuario_id uuid, email text, nombre text, administrador boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_usuario uuid;
BEGIN
    v_usuario := public.validar_sesion(p_token);
    IF v_usuario IS NULL THEN RETURN; END IF;
    RETURN QUERY
    SELECT u.id, u.email, u.nombre::text,
        EXISTS (SELECT 1 FROM public.usuario_rol ur JOIN public.rol r ON r.id=ur.rol_id
                WHERE ur.usuario_id=u.id AND r.codigo='administrador')
    FROM public.usuario u WHERE u.id=v_usuario;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_listar_usuarios(
    p_token text, p_busqueda text DEFAULT '', p_limite integer DEFAULT 25, p_offset integer DEFAULT 0
)
RETURNS TABLE (usuario_id uuid, email text, nombre text, estado text,
              correo_verificado boolean, administrador boolean, creado_en timestamptz, total bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM public.exigir_administrador(p_token);
    IF p_busqueda IS NULL OR char_length(p_busqueda)>254 OR p_limite IS NULL OR p_limite NOT BETWEEN 1 AND 50
       OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 1000000 THEN
        RAISE EXCEPTION 'Parámetros de listado inválidos' USING ERRCODE='22023';
    END IF;
    RETURN QUERY
    SELECT u.id, u.email, u.nombre::text, u.estado::text,
        u.email_verificado_en IS NOT NULL,
        EXISTS (SELECT 1 FROM public.usuario_rol ur JOIN public.rol r ON r.id=ur.rol_id
                WHERE ur.usuario_id=u.id AND r.codigo='administrador'),
        u.creado_en, count(*) OVER ()
    FROM public.usuario u
    WHERE position(lower(btrim(p_busqueda)) IN lower(u.email))>0 OR btrim(p_busqueda)=''
    ORDER BY u.creado_en DESC, u.id LIMIT p_limite OFFSET p_offset;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_cambiar_bloqueo_usuario(p_token text, p_usuario uuid, p_bloqueado boolean)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_estado text; v_verificado timestamptz; v_actor uuid;
BEGIN
    v_actor := public.exigir_administrador(p_token);
    IF p_usuario IS NULL OR p_bloqueado IS NULL THEN
        RAISE EXCEPTION 'Usuario y bloqueo son obligatorios' USING ERRCODE='22023';
    END IF;
    SELECT u.estado, u.email_verificado_en INTO v_estado, v_verificado
    FROM public.usuario u WHERE u.id=p_usuario FOR UPDATE;
    IF NOT FOUND THEN RETURN false; END IF;
    -- Esta etapa gestiona turistas; los administradores quedan protegidos.
    IF p_usuario=v_actor OR EXISTS (
        SELECT 1 FROM public.usuario_rol ur JOIN public.rol r ON r.id=ur.rol_id
        WHERE ur.usuario_id=p_usuario AND r.codigo='administrador'
    ) THEN
        RAISE EXCEPTION 'No se permite bloquear o desbloquear administradores en esta etapa' USING ERRCODE='22023';
    END IF;
    IF p_bloqueado THEN
        UPDATE public.usuario SET estado='bloqueado' WHERE id=p_usuario;
        UPDATE public.sesion_usuario SET revocado_en=clock_timestamp()
        WHERE usuario_id=p_usuario AND revocado_en IS NULL;
    ELSIF v_estado='bloqueado' THEN
        UPDATE public.usuario SET estado=CASE WHEN v_verificado IS NULL THEN 'pendiente' ELSE 'activo' END
        WHERE id=p_usuario;
    END IF;
    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.obtener_contexto_sesion(text),
    public.admin_listar_usuarios(text,text,integer,integer),
    public.admin_cambiar_bloqueo_usuario(text,uuid,boolean) FROM PUBLIC, casablanca_api;
GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;
ALTER FUNCTION public.obtener_contexto_sesion(text) OWNER TO casablanca_admin_owner;
ALTER FUNCTION public.admin_listar_usuarios(text,text,integer,integer) OWNER TO casablanca_admin_owner;
ALTER FUNCTION public.admin_cambiar_bloqueo_usuario(text,uuid,boolean) OWNER TO casablanca_admin_owner;
REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;
GRANT EXECUTE ON FUNCTION public.obtener_contexto_sesion(text),
    public.admin_listar_usuarios(text,text,integer,integer),
    public.admin_cambiar_bloqueo_usuario(text,uuid,boolean) TO casablanca_api;
COMMENT ON FUNCTION public.admin_cambiar_bloqueo_usuario(text,uuid,boolean) IS
'Bloquea turistas y revoca sesiones. Desbloquear conserva correo pendiente si no fue verificado. Protege administradores.';

-- Función opcional para la demostración: no prueba la propiedad del correo.
GRANT EXECUTE ON FUNCTION public.emitir_verificacion_email(uuid),
    public.confirmar_email(text) TO casablanca_admin_owner;

CREATE OR REPLACE FUNCTION public.admin_habilitar_cuenta_demo(p_token text, p_usuario uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_estado text;
    v_verificado timestamptz;
    v_token_email text;
BEGIN
    PERFORM public.exigir_administrador(p_token);
    IF p_usuario IS NULL THEN
        RAISE EXCEPTION 'Se requiere el usuario' USING ERRCODE='22023';
    END IF;
    SELECT u.estado, u.email_verificado_en INTO v_estado, v_verificado
    FROM public.usuario AS u WHERE u.id=p_usuario FOR UPDATE;
    IF NOT FOUND THEN RETURN false; END IF;
    IF EXISTS (
        SELECT 1 FROM public.usuario_rol ur JOIN public.rol r ON r.id=ur.rol_id
        WHERE ur.usuario_id=p_usuario AND r.codigo='administrador'
    ) THEN
        RAISE EXCEPTION 'La habilitación de demostración solo admite turistas' USING ERRCODE='22023';
    END IF;
    IF v_estado<>'pendiente' OR v_verificado IS NOT NULL THEN
        RAISE EXCEPTION 'La cuenta debe estar pendiente y sin verificar' USING ERRCODE='55000';
    END IF;

    -- Confirmación simulada por el administrador; no se envía ningún correo.
    SELECT token_original INTO v_token_email
    FROM public.emitir_verificacion_email(p_usuario);
    IF v_token_email IS NULL THEN
        RAISE EXCEPTION 'Se alcanzó el límite temporal de emisión' USING ERRCODE='54000';
    END IF;
    IF public.confirmar_email(v_token_email) IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'No se pudo confirmar la cuenta de demostración' USING ERRCODE='55000';
    END IF;
    -- Las funciones existentes activan la cuenta y consumen el token.
    -- No se cambian contraseña, perfil ni roles, ni se crea una sesión.
    RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_habilitar_cuenta_demo(text,uuid) FROM PUBLIC, casablanca_api;
GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;
ALTER FUNCTION public.admin_habilitar_cuenta_demo(text,uuid) OWNER TO casablanca_admin_owner;
REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;
GRANT EXECUTE ON FUNCTION public.admin_habilitar_cuenta_demo(text,uuid) TO casablanca_api;
COMMENT ON FUNCTION public.admin_habilitar_cuenta_demo(text,uuid) IS
'Opcional para demo: administrador confirma manualmente un turista pendiente, sin envío ni prueba de propiedad del correo. Conserva roles y contraseña.';

-- Actualización sobre una instalación existente. Ejecutar como postgres.
-- No elimina datos ni ejecuta la población inicial.

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



-- Define la carga inicial; no inserta registros hasta que un administrador la solicite.
CREATE OR REPLACE FUNCTION public.admin_cargar_catalogo_inicial(p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $function$
DECLARE
    v_catalogo jsonb := $catalogo${
  "atractivos": [
    {
      "id": "79e650f2-a038-5ac3-90b4-fe77e5a8fd6d",
      "local_id": 1,
      "nombre": "Museo Arqueológico y Antropológico de Casablanca",
      "descripcion": "Espacio cultural municipal que exhibe patrimonio arqueológico y antropológico de la comuna.",
      "nombre_en": "Archaeological and Anthropological Museum of Casablanca",
      "descripcion_en": "Municipal cultural space displaying the archaeological and anthropological heritage of the commune.",
      "imagen": "images/museo.jpg",
      "latitud": -33.3206622,
      "longitud": -71.4112624
    },
    {
      "id": "6ecf2149-2edf-51b4-ae35-dca4d813c0ec",
      "local_id": 2,
      "nombre": "Plaza de Armas de Casablanca",
      "descripcion": "Plaza central de la comuna, punto de encuentro histórico junto a la Parroquia Santa Bárbara.",
      "nombre_en": "Casablanca Main Square",
      "descripcion_en": "The central square, a historic meeting place next to Santa Bárbara Parish.",
      "imagen": "images/plaza.jpg",
      "latitud": -33.32052365,
      "longitud": -71.41010835
    },
    {
      "id": "dda20210-be8b-5063-8849-37c8960d451e",
      "local_id": 3,
      "nombre": "Parroquia Santa Bárbara",
      "descripcion": "Iglesia principal de Casablanca, dedicada a Santa Bárbara, patrona de la comuna.",
      "nombre_en": "Santa Bárbara Parish",
      "descripcion_en": "The main church of Casablanca, dedicated to Santa Bárbara.",
      "imagen": "images/parroquia.jpg",
      "latitud": -33.32043946,
      "longitud": -71.41089435
    },
    {
      "id": "0836ef48-946b-5958-b4bc-76b3fa99d611",
      "local_id": 4,
      "nombre": "Biblioteca Municipal",
      "descripcion": "Espacio cultural municipal de acceso público ubicado dentro del complejo del Centro Cultural de Casablanca.",
      "nombre_en": "Municipal Library",
      "descripcion_en": "A public municipal library within the Casablanca Cultural Centre.",
      "imagen": "images/biblioteca.jpg",
      "latitud": -33.32085,
      "longitud": -71.4109738
    },
    {
      "id": "1f682273-6957-5dbf-8f87-adb8c349a333",
      "local_id": 5,
      "nombre": "Centro Cultural de Casablanca",
      "descripcion": "Espacio municipal dedicado a actividades y difusión cultural de la comuna.",
      "nombre_en": "Casablanca Cultural Centre",
      "descripcion_en": "A municipal space for cultural activities in the commune.",
      "imagen": "images/centroCultural.jpg",
      "latitud": -33.32072069,
      "longitud": -71.41119225
    },
    {
      "id": "59ef1d81-6c45-5bc5-a20e-0c0be94944d6",
      "local_id": 6,
      "nombre": "Teatro Municipal",
      "descripcion": "Espacio cultural municipal para presentaciones y eventos.",
      "nombre_en": "Municipal Theatre",
      "descripcion_en": "A municipal venue for performances and events.",
      "imagen": "images/teatro.png",
      "latitud": null,
      "longitud": null
    }
  ],
  "rutas": [
    {
      "id": "2a92f1d8-b3af-5b37-9d19-2c9ec57f5088",
      "local_id": 1,
      "nombre": "Museo de Casablanca",
      "descripcion": "Visita al Museo Arqueológico y Antropológico de Casablanca.",
      "nombre_en": "Casablanca Museum",
      "descripcion_en": "A visit to the Archaeological and Anthropological Museum of Casablanca.",
      "imagen": "images/museo.jpg",
      "paradas": [
        {
          "key": "museo",
          "order": 1,
          "name": "Museo Arqueológico y Antropológico de Casablanca",
          "description": "Espacio cultural municipal que exhibe patrimonio arqueológico y antropológico de la comuna.",
          "id": "6a472313-4f88-5442-8fd2-c2111a5f3197",
          "atractivo_id": "79e650f2-a038-5ac3-90b4-fe77e5a8fd6d",
          "imagen": "images/museo.jpg",
          "latitud": -33.3206622,
          "longitud": -71.4112624,
          "nombre_en": "Museo Arqueológico y Antropológico de Casablanca",
          "descripcion_en": "Stop 1 on the Casablanca Museum route."
        }
      ]
    },
    {
      "id": "b6875fb0-5938-5ea5-9644-53c7fe5114dc",
      "local_id": 2,
      "nombre": "Casco Histórico",
      "descripcion": "Doce paradas por las plazas, casas y espacios culturales del centro de Casablanca.",
      "nombre_en": "Historic Centre",
      "descripcion_en": "Twelve stops through the squares, houses and cultural spaces of central Casablanca.",
      "imagen": "maps/casco-historico.svg",
      "paradas": [
        {
          "key": "el_control",
          "order": 1,
          "name": "El Control",
          "description": "Punto de inicio del circuito del Casco Histórico.",
          "id": "c8fdc6d6-3131-532b-a94c-f2d47f3d6908",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": -33.3170602,
          "longitud": -71.4088361,
          "nombre_en": "El Control",
          "descripcion_en": "Stop 1 on the Historic Centre route.",
          "referencia_geografica": "Monolito del antiguo camino, junto a Constitución y Buin.",
          "precision": "cartographic"
        },
        {
          "key": "plaza_bicentenario",
          "order": 2,
          "name": "Plaza Bicentenario",
          "description": "Primera plaza del recorrido, antes de continuar por Chacabuco.",
          "id": "c55c39c9-498f-54a0-9d60-77dc44987103",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": null,
          "longitud": null,
          "nombre_en": "Plaza Bicentenario",
          "descripcion_en": "Stop 2 on the Historic Centre route.",
          "referencia_geografica": "Sector de Chacabuco y Chapito indicado en el folleto.",
          "precision": "approximate"
        },
        {
          "key": "casa_jorge_montt",
          "order": 3,
          "name": "Casa Presidente Jorge Montt",
          "description": "Una de las casas señaladas en el circuito del Casco Histórico.",
          "id": "03a56ada-b600-5767-8e6c-f623e353cbb7",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": null,
          "longitud": null,
          "nombre_en": "Casa Presidente Jorge Montt",
          "descripcion_en": "Stop 3 on the Historic Centre route.",
          "referencia_geografica": "Referencia del folleto en Chacabuco, sector Yungay.",
          "precision": "approximate"
        },
        {
          "key": "casa_alejandro_galaz",
          "order": 4,
          "name": "Casa Poeta Alejandro Galaz",
          "description": "Parada del recorrido por las casas del centro de Casablanca.",
          "id": "31986bdd-b821-5eeb-af44-58ed6186c187",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": null,
          "longitud": null,
          "nombre_en": "Casa Poeta Alejandro Galaz",
          "descripcion_en": "Stop 4 on the Historic Centre route.",
          "referencia_geografica": "Referencia del folleto en Chacabuco, entre Portales y Maipú.",
          "precision": "approximate"
        },
        {
          "key": "almacen_don_lalo",
          "order": 5,
          "name": "Almacén Don Lalo",
          "description": "El almacén forma parte del circuito del Casco Histórico.",
          "id": "cb6fd8be-d278-5cab-8ef7-3869344e848c",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": -33.321789,
          "longitud": -71.4076913,
          "nombre_en": "Almacén Don Lalo",
          "descripcion_en": "Stop 5 on the Historic Centre route.",
          "referencia_geografica": "Almacén tradicional en calle Chacabuco.",
          "precision": "cartographic"
        },
        {
          "key": "casa_julio_montt",
          "order": 6,
          "name": "Casa Julio Montt Salamanca",
          "description": "Casa señalada entre Almacén Don Lalo y la Cooperativa Agrícola.",
          "id": "55eaf218-cecf-5708-9554-ea49309a951b",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": null,
          "longitud": null,
          "nombre_en": "Casa Julio Montt Salamanca",
          "descripcion_en": "Stop 6 on the Historic Centre route.",
          "referencia_geografica": "Sector de avenida Portales, entre Chacabuco y Membrillar.",
          "precision": "approximate"
        },
        {
          "key": "cooperativa_agricola",
          "order": 7,
          "name": "Cooperativa Agrícola",
          "description": "Parada previa al paso por la Plaza de Armas.",
          "id": "5615524f-c114-57ff-8435-798413a6475a",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": -33.321371,
          "longitud": -71.4097634,
          "nombre_en": "Cooperativa Agrícola",
          "descripcion_en": "Stop 7 on the Historic Centre route.",
          "referencia_geografica": "Cooperativa Agrícola y Lechera, avenida Diego Portales.",
          "precision": "cartographic"
        },
        {
          "key": "plaza_armas",
          "order": 8,
          "name": "Plaza de Armas",
          "description": "La plaza central de Casablanca, parte del circuito del Casco Histórico.",
          "id": "8b027a01-40a8-5418-85d1-700c9a6cc3bb",
          "atractivo_id": "6ecf2149-2edf-51b4-ae35-dca4d813c0ec",
          "imagen": "images/plaza.jpg",
          "latitud": -33.32052365,
          "longitud": -71.41010835,
          "nombre_en": "Plaza de Armas",
          "descripcion_en": "Stop 8 on the Historic Centre route.",
          "referencia_geografica": "Plaza central, entre Constitución, Portales, Maipú y Óscar Bonilla.",
          "precision": "cartographic"
        },
        {
          "key": "bomberos",
          "order": 9,
          "name": "1.ª Compañía de Bomberos",
          "description": "El circuito continúa desde la Plaza de Armas hacia la compañía de bomberos.",
          "id": "68f27757-6989-5f34-97f2-759ed97c18b5",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": null,
          "longitud": null,
          "nombre_en": "1.ª Compañía de Bomberos",
          "descripcion_en": "Stop 9 on the Historic Centre route.",
          "referencia_geografica": "Sitio del antiguo cuartel de calle Maipú, frente a la Plaza de Armas.",
          "precision": "approximate"
        },
        {
          "key": "municipalidad",
          "order": 10,
          "name": "I. Municipalidad de Casablanca",
          "description": "Edificio señalado en el recorrido por la avenida Constitución.",
          "id": "f1dcc275-90a2-5957-9732-0adcae88b022",
          "atractivo_id": null,
          "imagen": "maps/casco-historico.svg",
          "latitud": -33.3197300133,
          "longitud": -71.4105246733,
          "nombre_en": "I. Municipalidad de Casablanca",
          "descripcion_en": "Stop 10 on the Historic Centre route.",
          "referencia_geografica": "Edificio consistorial de avenida Constitución 111.",
          "precision": "cartographic"
        },
        {
          "key": "parroquia_santa_barbara",
          "order": 11,
          "name": "Parroquia Santa Bárbara",
          "description": "La parroquia es la penúltima parada del circuito.",
          "id": "3f52b10f-1aeb-5c7b-bc9b-cf6cd667a93a",
          "atractivo_id": "dda20210-be8b-5063-8849-37c8960d451e",
          "imagen": "images/parroquia.jpg",
          "latitud": -33.3204394615,
          "longitud": -71.4108943538,
          "nombre_en": "Parroquia Santa Bárbara",
          "descripcion_en": "Stop 11 on the Historic Centre route.",
          "referencia_geografica": "Parroquia Santa Bárbara, junto a la Plaza de Armas.",
          "precision": "cartographic"
        },
        {
          "key": "centro_cultural_museo",
          "order": 12,
          "name": "Centro Cultural y Museo",
          "description": "El circuito del Casco Histórico termina en el Centro Cultural y Museo.",
          "id": "cbef465b-5f47-5115-b70d-34a7d2b4c337",
          "atractivo_id": "1f682273-6957-5dbf-8f87-adb8c349a333",
          "imagen": "images/centroCultural.jpg",
          "latitud": -33.3207206875,
          "longitud": -71.41119225,
          "nombre_en": "Centro Cultural y Museo",
          "descripcion_en": "Stop 12 on the Historic Centre route.",
          "referencia_geografica": "Centro Cultural y Museo, avenida Diego Portales 02.",
          "precision": "cartographic"
        }
      ]
    },
    {
      "id": "6d4f8a88-a6d3-5567-870c-25359cfc7f6f",
      "local_id": 3,
      "nombre": "Plaza de Armas",
      "descripcion": "Un recorrido por la Plaza de Armas de Casablanca.",
      "nombre_en": "Main Square",
      "descripcion_en": "A visit to the main square of Casablanca.",
      "imagen": "images/plaza.jpg",
      "paradas": [
        {
          "key": "plaza_armas",
          "order": 1,
          "name": "Plaza de Armas de Casablanca",
          "description": "Plaza central de la comuna, punto de encuentro histórico junto a la Parroquia Santa Bárbara.",
          "id": "8878943e-7d9e-5ec0-a6ec-1db47979149a",
          "atractivo_id": "6ecf2149-2edf-51b4-ae35-dca4d813c0ec",
          "imagen": "images/plaza.jpg",
          "latitud": -33.32052365,
          "longitud": -71.41010835,
          "nombre_en": "Plaza de Armas de Casablanca",
          "descripcion_en": "Stop 1 on the Main Square route."
        }
      ]
    }
  ]
}$catalogo$::jsonb;
    v jsonb; s jsonb; v_insertado uuid;
    v_atractivos integer := 0; v_rutas integer := 0; v_paradas integer := 0;
BEGIN
    PERFORM public.exigir_administrador(p_token);
    -- Serializa únicamente dos cargas simultáneas de esta población.
    PERFORM pg_catalog.pg_advisory_xact_lock(20261029, 1);
    FOR v IN SELECT value FROM pg_catalog.jsonb_array_elements(v_catalogo->'atractivos') LOOP
        INSERT INTO public.atractivo(id, estado, imagen_principal, ubicacion)
        VALUES ((v->>'id')::uuid, 'borrador', v->>'imagen',
            CASE WHEN v->>'latitud' IS NOT NULL THEN public.ST_SetSRID(public.ST_MakePoint(
                (v->>'longitud')::double precision, (v->>'latitud')::double precision),4326) END)
        ON CONFLICT (id) DO NOTHING RETURNING id INTO v_insertado;
        IF v_insertado IS NOT NULL THEN
            v_atractivos := v_atractivos + 1;
            INSERT INTO public.atractivo_traduccion(atractivo_id,idioma_codigo,nombre,descripcion)
            VALUES (v_insertado,'es',v->>'nombre',v->>'descripcion'),
                   (v_insertado,'en',v->>'nombre_en',v->>'descripcion_en');
        END IF;
    END LOOP;
    FOR v IN SELECT value FROM pg_catalog.jsonb_array_elements(v_catalogo->'rutas') LOOP
        INSERT INTO public.ruta(id,estado,imagen_principal)
        VALUES ((v->>'id')::uuid,'borrador',v->>'imagen')
        ON CONFLICT (id) DO NOTHING RETURNING id INTO v_insertado;
        IF v_insertado IS NOT NULL THEN
            v_rutas := v_rutas + 1;
            INSERT INTO public.ruta_traduccion(ruta_id,idioma_codigo,nombre,descripcion)
            VALUES (v_insertado,'es',v->>'nombre',v->>'descripcion'),
                   (v_insertado,'en',v->>'nombre_en',v->>'descripcion_en');
            -- Una ruta existente conserva sus paradas, incluso si se editaron o eliminaron.
            FOR s IN SELECT value FROM pg_catalog.jsonb_array_elements(v->'paradas') LOOP
                INSERT INTO public.ruta_parada(id,ruta_id,atractivo_id,orden,imagen_principal,ubicacion)
                VALUES ((s->>'id')::uuid,(v->>'id')::uuid,(s->>'atractivo_id')::uuid,
                    (s->>'order')::integer,s->>'imagen',
                    CASE WHEN s->>'latitud' IS NOT NULL THEN public.ST_SetSRID(public.ST_MakePoint(
                        (s->>'longitud')::double precision,(s->>'latitud')::double precision),4326) END);
                INSERT INTO public.ruta_parada_traduccion(parada_id,idioma_codigo,nombre,descripcion)
                VALUES ((s->>'id')::uuid,'es',s->>'name',s->>'description'),
                       ((s->>'id')::uuid,'en',s->>'nombre_en',s->>'descripcion_en');
                v_paradas := v_paradas + 1;
            END LOOP;
        END IF;
    END LOOP;
    RETURN pg_catalog.jsonb_build_object('atractivos_creados',v_atractivos,
        'rutas_creadas',v_rutas,'paradas_creadas',v_paradas);
END;
$function$;
GRANT INSERT (id,estado,imagen_principal,ubicacion) ON public.atractivo TO casablanca_admin_owner;
GRANT INSERT (id,estado,imagen_principal) ON public.ruta TO casablanca_admin_owner;
GRANT INSERT (id,ruta_id,atractivo_id,orden,imagen_principal,ubicacion) ON public.ruta_parada TO casablanca_admin_owner;
REVOKE ALL ON FUNCTION public.admin_cargar_catalogo_inicial(text) FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO casablanca_admin_owner;
ALTER FUNCTION public.admin_cargar_catalogo_inicial(text) OWNER TO casablanca_admin_owner;
REVOKE CREATE ON SCHEMA public FROM casablanca_admin_owner;
GRANT EXECUTE ON FUNCTION public.admin_cargar_catalogo_inicial(text) TO casablanca_api;

COMMIT;
