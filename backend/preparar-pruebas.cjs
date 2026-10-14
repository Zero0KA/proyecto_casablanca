'use strict';
// Genera SQL para preparar SOLO las dos cuentas conocidas de demostración.
// No se conecta a la BD: el usuario revisa y ejecuta el resultado en pgAdmin.
const fs=require('node:fs');
const path=require('node:path');
const argon2=require('argon2');
function ordenar(hash){const p=hash.split('$');const v=Object.fromEntries(p[3].split(',').map(x=>x.split('=')));p[3]=`m=${v.m},t=${v.t},p=${v.p}`;return p.join('$')}
async function main(){
  const opciones={type:argon2.argon2id,memoryCost:65536,timeCost:3,parallelism:1,hashLength:32};
  const admin=ordenar(await argon2.hash('Admin de prueba Casablanca 2026!',opciones));
  const turista=ordenar(await argon2.hash('Turista de prueba Casablanca 2026!',opciones));
  const sql=`-- Exclusivo de demostración local. Contraseñas públicas de prueba; no usar en producción.
-- Requiere las dos cuentas existentes. No crea cuentas ni asigna roles.
BEGIN;
DO $$
DECLARE v_email text; v_id uuid; v_verificado timestamptz; v_estado text; v_token text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuario u JOIN public.usuario_rol ur ON ur.usuario_id=u.id
       JOIN public.rol r ON r.id=ur.rol_id WHERE u.email='demo.admin@example.invalid' AND r.codigo='administrador') THEN
       RAISE EXCEPTION 'Falta la cuenta administradora de demostración';
    END IF;
    IF EXISTS (SELECT 1 FROM public.usuario u JOIN public.usuario_rol ur ON ur.usuario_id=u.id
       JOIN public.rol r ON r.id=ur.rol_id WHERE u.email='registro.prueba.01@example.invalid' AND r.codigo='administrador') THEN
       RAISE EXCEPTION 'La cuenta turista de prueba no debe ser administradora';
    END IF;
    FOREACH v_email IN ARRAY ARRAY['demo.admin@example.invalid','registro.prueba.01@example.invalid'] LOOP
        SELECT id, email_verificado_en, estado INTO v_id, v_verificado, v_estado
        FROM public.usuario WHERE email=v_email FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'Falta la cuenta de prueba %',v_email; END IF;
        IF v_estado='bloqueado' THEN RAISE EXCEPTION 'Primero desbloquea la cuenta de prueba %',v_email; END IF;
        IF v_verificado IS NULL THEN
            SELECT token_original INTO STRICT v_token FROM public.emitir_verificacion_email(v_id);
            IF public.confirmar_email(v_token) IS DISTINCT FROM true THEN
                RAISE EXCEPTION 'No se pudo confirmar manualmente la cuenta de prueba';
            END IF;
        END IF;
        UPDATE public.usuario SET password_hash=CASE WHEN v_email='demo.admin@example.invalid'
            THEN '${admin}' ELSE '${turista}' END WHERE id=v_id;
        UPDATE public.sesion_usuario SET revocado_en=clock_timestamp()
        WHERE usuario_id=v_id AND revocado_en IS NULL;
    END LOOP;
END;
$$;
COMMIT;
-- Resultado esperado: ambas cuentas activas/verificadas, contraseñas de prueba actualizadas y sesiones anteriores revocadas.
`;
  const destino=path.join(__dirname,'..','bd','02_preparar_cuentas_prueba.sql');
  fs.mkdirSync(path.dirname(destino),{recursive:true});fs.writeFileSync(destino,sql,'utf8');
  console.log('SQL generado: bd/02_preparar_cuentas_prueba.sql. Revísalo y ejecútalo en pgAdmin con tu conexión administrativa.');
}
main().catch(()=>{console.error('No se pudo generar la preparación de pruebas.');process.exitCode=1});
