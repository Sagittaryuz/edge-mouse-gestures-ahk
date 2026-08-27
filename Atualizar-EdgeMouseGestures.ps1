[CmdletBinding()]
param(
    [switch]$Launch,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Repositório público usado pelo atualizador.
$RepositoryOwner = 'Sagittaryuz'
$RepositoryName = 'edge-mouse-gestures-ahk'
$RepositoryBranch = 'main'
$ScriptName = 'EdgeMouseGestures.ahk'

$InstallDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalScript = Join-Path $InstallDirectory $ScriptName
$RawUrl = "https://raw.githubusercontent.com/$RepositoryOwner/$RepositoryName/$RepositoryBranch/$ScriptName"

function Write-UpdateMessage {
    param([string]$Message)

    if (-not $Quiet) {
        Write-Host $Message
    }
}

function Get-AutoHotkeyPath {
    $command = Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue

    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\v2\AutoHotkey.exe'),
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\AutoHotkey.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\v2\AutoHotkey.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\AutoHotkey.exe')
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Update-LocalScript {
    $temporaryFile = Join-Path $env:TEMP ("EdgeMouseGestures-{0}.ahk" -f ([guid]::NewGuid().ToString('N')))
    $backupFile = "$LocalScript.bak"

    try {
        Invoke-WebRequest `
            -Uri $RawUrl `
            -OutFile $temporaryFile `
            -UseBasicParsing `
            -Headers @{ 'Cache-Control' = 'no-cache' }

        if (-not (Test-Path -LiteralPath $temporaryFile)) {
            throw 'O GitHub não retornou o arquivo esperado.'
        }

        $remoteHash = (Get-FileHash -LiteralPath $temporaryFile -Algorithm SHA256).Hash
        $localHash = $null

        if (Test-Path -LiteralPath $LocalScript) {
            $localHash = (Get-FileHash -LiteralPath $LocalScript -Algorithm SHA256).Hash
        }

        if ($localHash -eq $remoteHash) {
            Write-UpdateMessage "Gestos do Mouse já estão atualizados."
            return $false
        }

        if (Test-Path -LiteralPath $LocalScript) {
            Copy-Item -LiteralPath $LocalScript -Destination $backupFile -Force
        }

        Move-Item -LiteralPath $temporaryFile -Destination $LocalScript -Force
        Write-UpdateMessage "Gestos do Mouse foram atualizados pelo GitHub."
        return $true
    }
    finally {
        if (Test-Path -LiteralPath $temporaryFile) {
            Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Update-LocalScript | Out-Null

    if ($Launch) {
        $autoHotkey = Get-AutoHotkeyPath

        if (-not $autoHotkey) {
            throw 'AutoHotkey v2 não foi encontrado. Instale-o ou abra o arquivo EdgeMouseGestures.ahk manualmente.'
        }

        Start-Process -FilePath $autoHotkey -ArgumentList ('"{0}"' -f $LocalScript)
    }
}
catch {
    if ($Quiet) {
        exit 1
    }

    Write-Warning ("Não foi possível atualizar Gestos do Mouse: " + $_.Exception.Message)
    exit 1
}
