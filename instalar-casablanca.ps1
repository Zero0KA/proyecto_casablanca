# Instalador local de Casablanca. Instala SQL solo en una base nueva o vacia.
# No borra bases, tablas, usuarios, sesiones ni datos existentes.
$ErrorActionPreference = 'Stop'
# Los SQL del proyecto estan guardados como UTF-8. Evita que psql use WIN1252.
$env:PGCLIENTENCODING = 'UTF8'
$Raiz = $PSScriptRoot
$EnvFile = Join-Path $Raiz 'backend\.env'
$SqlFile = Join-Path $Raiz 'bd\casablanca_instalador_actualizado.sql'

function Fallar([string]$Mensaje) { throw $Mensaje }
function Leer-Env([string]$Clave) {
    foreach ($Linea in (Get-Content -LiteralPath $EnvFile -Encoding UTF8)) {
        if ($Linea -match ('^\s*' + [regex]::Escape($Clave) + '\s*=\s*(.*)$')) {
            $v = $Matches[1].Trim()
            if (($v.StartsWith('"') -and $v.EndsWith('"')) -or
                ($v.StartsWith("'") -and $v.EndsWith("'"))) {
                $v = $v.Substring(1, $v.Length - 2)
            }
            return $v
        }
    }
    return ''
}
function Comprobar-Exit([string]$Accion) {
    if ($LASTEXITCODE -ne 0) { Fallar "Fallo: $Accion (codigo $LASTEXITCODE). Revisa el error mostrado." }
}

try {
    Write-Host 'CASABLANCA - INSTALACION Y ARRANQUE LOCAL' -ForegroundColor Cyan
    foreach ($Archivo in @($EnvFile, $SqlFile, (Join-Path $Raiz 'iniciar-demo.cmd'),
                          (Join-Path $Raiz 'package.json'),
                          (Join-Path $Raiz 'backend\package.json'))) {
        if (-not (Test-Path -LiteralPath $Archivo)) { Fallar "No se encontro: $Archivo. Pon los dos instaladores en la carpeta casablanca_publicacion." }
    }

    $HostBD = Leer-Env 'PGHOST'
    $PuertoBD = Leer-Env 'PGPORT'
    $BaseBD = Leer-Env 'PGDATABASE'
    $UsuarioBD = Leer-Env 'PGUSER'
    $ClaveBD = Leer-Env 'PGPASSWORD'
    if ($HostBD -notin @('127.0.0.1', 'localhost', '::1')) { Fallar 'Por seguridad, este instalador solo acepta PostgreSQL local (PGHOST=127.0.0.1 o localhost).' }
    if ($PuertoBD -notmatch '^\d{1,5}$' -or [int]$PuertoBD -lt 1 -or [int]$PuertoBD -gt 65535) { Fallar 'Revisa PGPORT en backend\.env.' }
    if ($BaseBD -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { Fallar 'Revisa PGDATABASE en backend\.env.' }
    if ($UsuarioBD -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $UsuarioBD -in @('postgres', 'casablanca_api')) { Fallar 'Revisa PGUSER en backend\.env: se requiere un usuario de conexion propio.' }
    if ([string]::IsNullOrWhiteSpace($ClaveBD)) { Fallar 'Falta PGPASSWORD en backend\.env. No se cambia el archivo automaticamente.' }

    # Buscar psql.exe en PATH o en la instalacion habitual de PostgreSQL para Windows.
    $Psql = $null
    $Orden = Get-Command psql.exe -ErrorAction SilentlyContinue
    if ($Orden) { $Psql = $Orden.Source }
    if (-not $Psql) {
        $Candidatos = @()
        foreach ($Directorio in @("$env:ProgramFiles\PostgreSQL", "${env:ProgramFiles(x86)}\PostgreSQL")) {
            if ($Directorio -and (Test-Path -LiteralPath $Directorio)) {
                $Candidatos += Get-ChildItem -LiteralPath $Directorio -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^\d+$' } |
                    Sort-Object { [int]$_.Name } -Descending |
                    ForEach-Object { Join-Path $_.FullName 'bin\psql.exe' }
            }
        }
        $Psql = $Candidatos | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $Psql) { Fallar 'No se encontro psql.exe. Instala PostgreSQL (incluido el cliente de linea de comandos).' }
    Write-Host "PostgreSQL: $HostBD`:$PuertoBD / base $BaseBD"

    # Evita guardar la clave administrativa en archivos o pasarla por la linea de comandos.
    $TeniaPassword = Test-Path Env:PGPASSWORD
    $PasswordAnterior = $env:PGPASSWORD
    $ClaveSegura = Read-Host 'Introduce la contrasena del usuario postgres de PostgreSQL' -AsSecureString
    $Ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClaveSegura)
    try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr) }
    $Creada = $false
    try {
        $Conecta = & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d postgres -tA -v ON_ERROR_STOP=1 -c 'SELECT 1;'
        Comprobar-Exit 'conexion como postgres. Comprueba que el servicio este iniciado y la contrasena sea correcta'
        if (($Conecta | Select-Object -Last 1).Trim() -ne '1') { Fallar 'No se pudo validar la conexion a PostgreSQL.' }
        $Postgis = & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d postgres -tA -v ON_ERROR_STOP=1 -c "SELECT 1 FROM pg_available_extensions WHERE name = 'postgis';"
        Comprobar-Exit 'comprobacion de PostGIS'
        if (($Postgis | Out-String).Trim() -ne '1') { Fallar 'PostGIS no esta instalado en el servidor. Hay que agregar PostGIS a PostgreSQL antes de instalar Casablanca.' }

        $Existe = & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d postgres -tA -v ON_ERROR_STOP=1 -c "SELECT 1 FROM pg_database WHERE datname = '$BaseBD';"
        Comprobar-Exit 'consulta de bases existentes'
        $InstalarSQL = $false
        if (($Existe | Out-String).Trim() -eq '1') {
            # Despues de un error, PostgreSQL revierte el SQL pero la BD creada queda vacia.
            # Solo reintentar si no hay objetos ajenos a extensiones existentes.
            $SqlEstado = @'
SELECT CASE WHEN EXISTS (
  SELECT 1 FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname NOT LIKE 'pg_toast%'
    AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
    AND NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_depend dep
      WHERE dep.classid = 'pg_catalog.pg_class'::regclass
        AND dep.objid = c.oid AND dep.deptype = 'e'
    )
) THEN 'OCUPADA' ELSE 'VACIA' END;
'@
            $EstadoBD = & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d $BaseBD -tA -v ON_ERROR_STOP=1 -c $SqlEstado
            Comprobar-Exit 'inspeccion segura de la base existente'
            if (($EstadoBD | Out-String).Trim() -eq 'VACIA') {
                Write-Host "La base $BaseBD existe, pero esta vacia (instalacion fallida previa). Reintentando SQL..." -ForegroundColor Yellow
                $InstalarSQL = $true
            } else {
                Write-Host "La base $BaseBD YA contiene objetos: no se modifica ni se reinstala SQL." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Creando base NUEVA: $BaseBD ..."
            $SqlCrear = 'CREATE DATABASE "' + $BaseBD + '" TEMPLATE template0 ENCODING ''UTF8'';'
            & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d postgres -v ON_ERROR_STOP=1 -c $SqlCrear
            Comprobar-Exit 'creacion de base de datos'
            $Creada = $true
            $InstalarSQL = $true
        }
        if ($InstalarSQL) {
            Write-Host 'Instalando estructura, PostGIS, funciones y catalogos (UTF-8) ...'
            & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d $BaseBD -v ON_ERROR_STOP=1 -f $SqlFile
            Comprobar-Exit 'instalador SQL (la transaccion se revierte si falla)'

            # El rol casablanca_api es NOLOGIN. Se configura el login del backend
            # con la contrasena YA presente en su .env, sin cambiar ese archivo.
            $RolExiste = & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d postgres -tA -v ON_ERROR_STOP=1 -c "SELECT 1 FROM pg_roles WHERE rolname = '$UsuarioBD';"
            Comprobar-Exit 'consulta de usuario del backend'
            if (($RolExiste | Out-String).Trim() -ne '1') {
                $ClaveSql = $ClaveBD.Replace("'", "''")
                $SqlRol = 'CREATE ROLE "' + $UsuarioBD + '" LOGIN PASSWORD ''' + $ClaveSql + ''';'
                $SqlRol | & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d postgres -v ON_ERROR_STOP=1 -f -
                Comprobar-Exit 'creacion de usuario de conexion del backend'
            } else {
                Write-Host 'El usuario de conexion ya existe: no se cambia su contrasena.' -ForegroundColor Yellow
            }
            $SqlPermiso = 'GRANT casablanca_api TO "' + $UsuarioBD + '";'
            $SqlPermiso | & $Psql -X -w -h $HostBD -p $PuertoBD -U postgres -d postgres -v ON_ERROR_STOP=1 -f -
            Comprobar-Exit 'asignacion de permisos a la API'
        }
    } finally {
        if ($TeniaPassword) { $env:PGPASSWORD = $PasswordAnterior }
        else { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
    }

    if (-not (Get-Command node.exe -ErrorAction SilentlyContinue) -or
        -not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { Fallar 'No esta instalado Node.js/npm.' }
    foreach ($Dir in @($Raiz, (Join-Path $Raiz 'backend'))) {
        if (-not (Test-Path -LiteralPath (Join-Path $Dir 'node_modules'))) {
            Write-Host "Instalando dependencias en $Dir ..."
            Push-Location $Dir
            try {
                & npm.cmd ci
                Comprobar-Exit 'npm.cmd ci'
            } finally { Pop-Location }
        }
    }
    Write-Host 'Verificando la conexion real del backend ...'
    & node (Join-Path $Raiz 'backend\comprobar-bd.cjs')
    Comprobar-Exit 'conexion del backend; revisa PGUSER y PGPASSWORD de backend\.env'

    Write-Host 'BASE DE DATOS CONECTADA.' -ForegroundColor Green
    if ($Creada) {
        Write-Host 'Instalacion nueva: no se recuperan cuentas ni contenido editado de la BD antigua.' -ForegroundColor Yellow
    }
    Write-Host 'Abriendo el lanzador habitual de Casablanca ...'
    Start-Process -FilePath (Join-Path $Raiz 'iniciar-demo.cmd') -WorkingDirectory $Raiz
    Write-Host 'Se abrio iniciar-demo.cmd. Mantener sus ventanas API y FRONT abiertas.' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No se elimino ninguna base existente. No se modifico backend\.env.'
    exit 1
}
