$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskCli = Join-Path $taskRoot 'tools/verification/node_modules/.bin/supabase.cmd'
$taskFlutter = Join-Path $taskRoot '.tools/flutter/bin/flutter.bat'
if (-not (Test-Path -LiteralPath $taskFlutter)) {
  $taskFlutter = (Get-Command flutter -ErrorAction Stop).Source
}
$taskArtifacts = Join-Path $taskRoot '.tools'
New-Item -ItemType Directory -Path $taskArtifacts -Force | Out-Null
$taskPreviousConfig = $env:DOPMI_LOCAL_CONFIG
$env:PUB_CACHE = Join-Path $taskRoot '.tools/pub-cache'
Push-Location $taskRoot
try {
  & $taskCli start --exclude realtime,storage-api,imgproxy,postgres-meta,studio,edge-runtime,logflare,vector,supavisor > (Join-Path $taskArtifacts 'identity-local-start.log') 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo iniciar Supabase local. Revisa .tools/identity-local-start.log.'
  }
  $taskStatus = & $taskCli status --output json
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar Supabase local.' }
  $env:DOPMI_LOCAL_CONFIG = Join-Path $taskArtifacts 'supabase.local.json'
  $taskStatus | Set-Content -LiteralPath $env:DOPMI_LOCAL_CONFIG -Encoding utf8
  & $taskCli test db
  if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas de permisos.' }
  Set-Location (Join-Path $taskRoot 'apps/mobile')
  & $taskFlutter test test_backend/identity_backend_test.dart --reporter expanded
  if ($LASTEXITCODE -ne 0) { throw 'Falló el recorrido de identidad contra Supabase local.' }
} finally {
  $env:DOPMI_LOCAL_CONFIG = $taskPreviousConfig
  Pop-Location
}
