$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot 'backend')
& .\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
exit $LASTEXITCODE
