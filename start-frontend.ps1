$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot 'frontend')
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    & $flutterCommand.Source run -d chrome --web-hostname localhost --web-port 5173 --no-web-resources-cdn
} else {
    & "$env:USERPROFILE\develop\flutter\bin\flutter.bat" run -d chrome --web-hostname localhost --web-port 5173 --no-web-resources-cdn
}
exit $LASTEXITCODE

