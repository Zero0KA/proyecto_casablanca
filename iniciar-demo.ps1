param(
    [ValidateSet('INICIO', 'FRONT', 'API')]
    [string]$Modo = 'INICIO',
    [int]$PuertoFront = 5173
)

$ErrorActionPreference = 'Stop'
$Raiz = $PSScriptRoot
$Backend = Join-Path $Raiz 'backend'
$ApiUrl = 'http://127.0.0.1:3001/api/estado'

function Puerto-Ocupado([int]$Puerto) {
    $conexion = Get-NetTCPConnection -State Listen -LocalPort $Puerto -ErrorAction SilentlyContinue
    return [bool]$conexion
}

function Leer-Estado {
    try {
        return Invoke-RestMethod -Uri $ApiUrl -TimeoutSec 2 -ErrorAction Stop
    } catch {
        return $null
    }
}

function Abrir-Terminal([string]$Nombre, [int]$Puerto = 5173) {
    # La ruta se cita como literal de PowerShell y se codifica para conservar espacios.
    $Archivo = $PSCommandPath.Replace("'", "''")
    $Orden = "& '$Archivo' -Modo $Nombre -PuertoFront $Puerto"
    $Codificada = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Orden))
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoLogo', '-NoProfile', '-NoExit', '-ExecutionPolicy', 'Bypass',
        '-EncodedCommand', $Codificada
    ) | Out-Null
}

try {
    if ($Modo -eq 'API') {
        $Host.UI.RawUI.WindowTitle = 'API - Casablanca'
        Set-Location -LiteralPath $Backend
        & node '.\server.cjs'
        if ($LASTEXITCODE -ne 0) { throw 'La API termino con un error. Revisa el mensaje anterior.' }
        exit
    }
    if ($Modo -eq 'FRONT') {
        $Host.UI.RawUI.WindowTitle = 'FRONT - Casablanca'
        Set-Location -LiteralPath $Raiz
        & npm.cmd run dev -- --host 127.0.0.1 --port $PuertoFront --strictPort
        if ($LASTEXITCODE -ne 0) { throw 'Vite termino con un error. Revisa el mensaje anterior.' }
        exit
    }

    $Host.UI.RawUI.WindowTitle = 'COMANDOS - Inicio de Casablanca'
    Write-Host 'CASABLANCA - DEMOSTRACION LOCAL' -ForegroundColor Cyan
    foreach ($Archivo in @('package.json', 'vite.config.js', 'src\pages\Categories.jsx',
            'backend\server.cjs', 'backend\.env', 'renovar-demo.cjs')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Raiz $Archivo))) {
            throw "Falta $Archivo. Coloca los dos lanzadores en la raiz del proyecto actualizado."
        }
    }
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -or
        -not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
        throw 'No se encontro Node.js/npm. Instala Node.js y vuelve a abrir el lanzador.'
    }
    foreach ($Carpeta in @('node_modules', 'backend\node_modules')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Raiz $Carpeta))) {
            throw "Falta $Carpeta. Ejecuta npm.cmd ci en la raiz y en backend antes de usar el lanzador."
        }
    }
    # Solo se lee PORT; nunca se imprime la contrasena ni el token.
    $LineaPuerto = Get-Content -LiteralPath (Join-Path $Backend '.env') |
        Where-Object { $_ -match '^\s*PORT\s*=' } | Select-Object -Last 1
    if ($LineaPuerto -and $LineaPuerto -notmatch '^\s*PORT\s*=\s*["'']?3001["'']?\s*(#.*)?$') {
        throw 'Este lanzador usa el puerto 3001. Revisa PORT=3001 en backend/.env y el proxy de Vite.'
    }

    Write-Host 'Comprobando o renovando la sesion de demostracion...'
    & node (Join-Path $Raiz 'renovar-demo.cjs')
    $ResultadoSesion = $LASTEXITCODE
    if ($ResultadoSesion -ne 0 -and $ResultadoSesion -ne 10) {
        throw 'No se pudo preparar la sesion. Lee el mensaje anterior. No se inicia el frontend.'
    }
    if ($ResultadoSesion -eq 10 -and (Puerto-Ocupado 3001)) {
        throw 'La sesion fue renovada, pero hay una API ejecutandose con la configuracion anterior. Pulsa Ctrl+C en su ventana API, cierrala y vuelve a abrir este lanzador. El nuevo token ya esta guardado.'
    }

    if (Puerto-Ocupado 3001) {
        Write-Host 'El puerto 3001 ya esta ocupado. Comprobando la API existente...'
    } else {
        Write-Host 'Iniciando API...'
        Abrir-Terminal 'API'
    }
    $Estado = $null
    for ($Intento = 0; $Intento -lt 20; $Intento++) {
        $Estado = Leer-Estado
        if ($null -ne $Estado) { break }
        Start-Sleep -Milliseconds 750
    }
    if ($null -eq $Estado) {
        throw ('La API no respondio con estado autorizado. Revisa la ventana API, PostgreSQL y backend/.env. ' +
            'Si el token vencio, genera otra sesion, actualiza DEMO_ADMIN_TOKEN y reinicia API. ' +
            'Si 3001 pertenece a otro programa, no lo cierres sin identificarlo.')
    }
    if ($Estado.conectado -ne $true -or $Estado.administrador -ne $true -or
        $Estado.base -ne 'casablanca' -or $Estado.cuenta_bd -ne 'casablanca_backend') {
        throw 'El estado no coincide con la demo autorizada (casablanca / casablanca_backend / administrador=true). Revisa la API y su configuracion.'
    }
    Write-Host 'BD conectada y consulta administrativa autorizada.' -ForegroundColor Green

    # Elige un puerto libre: no cierra procesos existentes ni depende del puerto anterior.
    $Elegido = $null
    foreach ($Candidato in 5173..5193) {
        if (-not (Puerto-Ocupado $Candidato)) { $Elegido = $Candidato; break }
    }
    if ($null -eq $Elegido) { throw 'No hay un puerto libre entre 5173 y 5193 para FRONT.' }
    Write-Host "Iniciando FRONT en $Elegido..."
    Abrir-Terminal 'FRONT' $Elegido
    $BaseFront = "http://127.0.0.1:$Elegido/proyecto_casablanca/"
    $Listo = $false
    for ($Intento = 0; $Intento -lt 30; $Intento++) {
        try {
            $Pagina = Invoke-WebRequest -UseBasicParsing -Uri $BaseFront -TimeoutSec 2
            if ($Pagina.StatusCode -eq 200) { $Listo = $true; break }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    if (-not $Listo) { throw 'FRONT no termino de iniciar. Revisa la ventana FRONT y vite.config.js.' }
    # Comprueba tambien el proxy, no solo que Vite entregue una pagina.
    $PorProxy = Invoke-RestMethod -Uri ($BaseFront + 'api/estado') -TimeoutSec 5
    if ($PorProxy.administrador -ne $true -or $PorProxy.base -ne 'casablanca' -or
        $PorProxy.cuenta_bd -ne 'casablanca_backend') {
        throw 'La comprobacion a traves de Vite no coincide con la API. Revisa su proxy.'
    }
    $Pantalla = $BaseFront + '#/'
    Start-Process $Pantalla
    Write-Host "Pantalla abierta: $Pantalla" -ForegroundColor Green
    Write-Host 'Deja FRONT y API abiertas mientras uses el CRUD.'
    Write-Host 'Para detenerlo: Ctrl+C en FRONT y API, y luego cerrar sus ventanas.'
    Write-Host 'Esta ventana COMANDOS puede cerrarse. No se modificaron datos de la BD.'
    Read-Host 'Pulsa Enter para cerrar el lanzador' | Out-Null
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host 'No se reinstalo la BD, no se cerraron otros procesos. La sesion pudo renovarse antes de este error.'
    Read-Host 'Pulsa Enter para cerrar' | Out-Null
    exit 1
}
