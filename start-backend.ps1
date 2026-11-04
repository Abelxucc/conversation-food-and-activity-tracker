param([switch]$SetApiKey)

$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'On macOS, use ./start-backend.sh.'
}

$backend = Join-Path $PSScriptRoot 'backend'
$python = Join-Path $backend '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw 'Set up the Windows backend virtual environment first. See README.md.'
}

$keyDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TrackTalk'
$keyFile = Join-Path $keyDirectory 'openai-api-key.xml'
$previousKey = $env:OPENAI_API_KEY
Push-Location $backend

try {
    if ($SetApiKey) {
        $secureKey = Read-Host 'Paste your OpenAI API key and press Enter' -AsSecureString
        if ($secureKey.Length -eq 0) {
            throw 'Enter an API key to enable AI features.'
        }
        New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
        [PSCredential]::new('TrackTalk', $secureKey) | Export-Clixml -LiteralPath $keyFile
    }

    if ($SetApiKey -or [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
        if (Test-Path -LiteralPath $keyFile -PathType Leaf) {
            $credential = Import-Clixml -LiteralPath $keyFile
            $env:OPENAI_API_KEY = $credential.GetNetworkCredential().Password
        } else {
            Write-Host 'To enable AI on this computer, run start-backend.ps1 with -SetApiKey.'
        }
    }

    & $python manage.py runserver 127.0.0.1:8000
    $backendExitCode = $LASTEXITCODE
} finally {
    $env:OPENAI_API_KEY = $previousKey
    Pop-Location
}
exit $backendExitCode
