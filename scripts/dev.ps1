param(
  [ValidateSet('mobile', 'mobile-web', 'admin', 'android', 'verify')]
  [string]$Target = 'mobile-web'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskFlutter = Join-Path $taskRoot '.tools/flutter/bin/flutter.bat'
if ($Target -ne 'admin' -and -not (Test-Path -LiteralPath $taskFlutter)) {
  $taskFlutter = (Get-Command flutter -ErrorAction Stop).Source
}
$env:PUB_CACHE = Join-Path $taskRoot '.tools/pub-cache'
$taskSdk = Join-Path $taskRoot '.tools/android-sdk'
if (Test-Path -LiteralPath $taskSdk) { $env:ANDROID_HOME = $taskSdk }
$taskJdk = Get-ChildItem (Join-Path $taskRoot '.tools/jdk') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($taskJdk) { $env:JAVA_HOME = $taskJdk.FullName }
$env:GRADLE_USER_HOME = Join-Path $taskRoot '.tools/gradle'
function Invoke-Checked([scriptblock]$Command) {
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "El comando terminó con código $LASTEXITCODE" }
}
Push-Location $taskRoot
try {
  switch ($Target) {
    'admin' {
      Set-Location apps/admin
      Invoke-Checked { npm.cmd run dev }
    }
    'verify' {
      Set-Location (Join-Path $taskRoot 'tools/verification')
      Invoke-Checked { npm.cmd test }
      Set-Location (Join-Path $taskRoot 'apps/admin')
      Invoke-Checked { npm.cmd test }
      Invoke-Checked { npm.cmd run build }
      Set-Location (Join-Path $taskRoot 'apps/mobile')
      Invoke-Checked { & $taskFlutter analyze }
      Invoke-Checked { & $taskFlutter test }
    }
    default {
      Set-Location apps/mobile
      if ($Target -eq 'mobile-web') {
        Invoke-Checked { & $taskFlutter run -d web-server --web-hostname 127.0.0.1 --web-port 5175 --dart-define-from-file=config.web.local.json }
      } elseif ($Target -eq 'android') {
        Invoke-Checked { & $taskFlutter build apk --debug --dart-define-from-file=config.local.json }
      } else {
        Invoke-Checked { & $taskFlutter run --dart-define-from-file=config.local.json }
      }
    }
  }
} finally { Pop-Location }
