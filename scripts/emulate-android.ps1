param([switch]$Rebuild)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskSdk = Join-Path $taskRoot '.tools/android-sdk'
$taskEmulator = Join-Path $taskSdk 'emulator/emulator.exe'
$taskAdb = Join-Path $taskSdk 'platform-tools/adb.exe'
$taskApk = Join-Path $taskRoot 'apps/mobile/build/app/outputs/flutter-apk/app-debug.apk'
$taskAvd = 'Dopmi_API_35'
$taskSerial = 'emulator-5556'
$env:ANDROID_HOME = $taskSdk

if (-not (Test-Path -LiteralPath $taskEmulator)) {
  throw 'Falta Android Emulator. Consulta docs/development.md.'
}
if (-not ((& $taskEmulator -list-avds) -contains $taskAvd)) {
  throw "Falta el dispositivo $taskAvd. Consulta docs/development.md."
}
& $taskEmulator -accel-check
if ($LASTEXITCODE -ne 0) {
  throw 'Activa Plataforma de hipervisor de Windows y reinicia el equipo antes de abrir el emulador.'
}

if ($Rebuild -or -not (Test-Path -LiteralPath $taskApk)) {
  & (Join-Path $PSScriptRoot 'dev.ps1') android
}

$taskDevices = & $taskAdb devices
if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar ADB.' }
if ($taskDevices -match "^$taskSerial\s") {
  $taskExistingAvd = & $taskAdb -s $taskSerial emu avd name
  if ($LASTEXITCODE -ne 0 -or $taskExistingAvd -notcontains $taskAvd) {
    throw "El puerto 5556 ya pertenece a otro emulador. Ciérralo antes de continuar."
  }
} else {
  # La ventana es el emulador interactivo solicitado por el usuario.
  Start-Process -FilePath $taskEmulator -ArgumentList @(
    '-avd', $taskAvd, '-port', '5556', '-memory', '1536', '-cores', '2',
    '-no-snapshot', '-no-boot-anim', '-camera-back', 'none', '-camera-front', 'none'
  ) -WorkingDirectory $taskRoot -WindowStyle Normal `
    -RedirectStandardOutput (Join-Path $taskRoot '.tools/android-emulator.log') `
    -RedirectStandardError (Join-Path $taskRoot '.tools/android-emulator-error.log') | Out-Null
}

Write-Host 'Esperando a que Android termine de iniciar...'
$taskDeadline = (Get-Date).AddMinutes(5)
$taskBooted = $false
do {
  $taskDevices = & $taskAdb devices
  if ($taskDevices -match "^$taskSerial\s+device$") {
    $taskBooted = ((& $taskAdb -s $taskSerial shell getprop sys.boot_completed) -join '').Trim() -eq '1'
    if ($taskBooted) { break }
  }
  Start-Sleep -Seconds 3
} while ((Get-Date) -lt $taskDeadline)
if (-not $taskBooted) {
  throw 'Android no terminó de iniciar. Revisa .tools/android-emulator-error.log.'
}

& $taskAdb -s $taskSerial install -r $taskApk
if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar el APK de Dopmi.' }
$taskLaunch = & $taskAdb -s $taskSerial shell am start -W -n io.dopmi.dopmi_mobile/.MainActivity
$taskLaunch | Write-Host
if ($LASTEXITCODE -ne 0 -or $taskLaunch -match '^Error:') { throw 'No se pudo abrir Dopmi.' }
$taskAppPid = & $taskAdb -s $taskSerial shell pidof io.dopmi.dopmi_mobile
if ($LASTEXITCODE -ne 0 -or -not $taskAppPid) { throw 'Dopmi no tiene un proceso activo en Android.' }
$taskActivities = & $taskAdb -s $taskSerial shell dumpsys activity activities
if ($LASTEXITCODE -ne 0 -or -not ($taskActivities -match 'topResumedActivity=.*io\.dopmi\.dopmi_mobile/')) {
  throw 'Android no confirmó a Dopmi en primer plano. Revisa la ventana del emulador.'
}
Write-Host 'Dopmi se está ejecutando en primer plano. Usa -Rebuild para compilar cambios recientes.'
