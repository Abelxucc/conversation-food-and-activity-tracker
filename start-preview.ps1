$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot 'frontend')
$flutterSdkBin = Join-Path $env:USERPROFILE 'develop\flutter\bin'
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    & $flutterCommand.Source build web --no-web-resources-cdn
} else {
    & (Join-Path $flutterSdkBin 'flutter.bat') build web --no-web-resources-cdn
}
if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
$pythonCommand = Join-Path $PSScriptRoot 'backend\.venv\Scripts\python.exe'
Write-Host 'Open http://localhost:5173 and click Check connection. Press Ctrl+C to stop.'
& $pythonCommand -m http.server 5173 --bind 127.0.0.1 --directory build/web
exit $LASTEXITCODE
