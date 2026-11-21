param([string]$DevEcoHome = 'E:\software\deveco-studio\DevEco Studio')
$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
$env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
$nativeRoot = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $nativeRoot 'harmony')
try {
  & (Join-Path $DevEcoHome 'tools/node/node.exe') (Join-Path $DevEcoHome 'tools/hvigor/bin/hvigorw.js') --mode module -p product=default -p module=entry@default assembleHap --no-daemon
  if ($LASTEXITCODE -ne 0) { throw 'HarmonyOS build failed' }
} finally { Pop-Location }
