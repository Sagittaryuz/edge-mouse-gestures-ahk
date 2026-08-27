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
$CommitApiUrl = "https://api.github.com/repos/$RepositoryOwner/$RepositoryName/commits/$RepositoryBranch"

function Write-UpdateMessage {
    param([string]$Message)

    if (-not $Quiet) {
        Write-Host $Message
    }
}

function Get-Sha256 {
    param([string]$Path)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)

    try {
        $bytes = $sha256.ComputeHash($stream)
        return (($bytes | ForEach-Object { $_.ToString('X2') }) -join '')
    }
    finally {
        $stream.Dispose()
        $sha256.Dispose()
    }
}

function Get-AutoHotkeyPath {
    $command = Get-Command AutoHotkey64.exe -ErrorAction SilentlyContinue

    if ($command) {
        return $command.Source
    }

    $command = Get-Command AutoHotkey32.exe -ErrorAction SilentlyContinue

    if ($command) {
        return $command.Source
    }

    $command = Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue

    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\v2\AutoHotkey32.exe'),
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\v2\AutoHotkey.exe'),
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\AutoHotkey64.exe'),
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\AutoHotkey32.exe'),
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\AutoHotkey.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\v2\AutoHotkey32.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\v2\AutoHotkey.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\AutoHotkey64.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\AutoHotkey32.exe'),
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
    $headers = @{
        'User-Agent' = 'EdgeMouseGestures-Updater'
        'Accept' = 'application/vnd.github+json'
        'Cache-Control' = 'no-cache'
    }

    try {
        $latestCommit = (Invoke-RestMethod -Uri $CommitApiUrl -UseBasicParsing -Headers $headers).sha

        if (-not $latestCommit -or $latestCommit -notmatch '^[0-9a-f]{40}$') {
            throw 'O GitHub não retornou um commit válido.'
        }

        $rawUrl = "https://raw.githubusercontent.com/$RepositoryOwner/$RepositoryName/$latestCommit/$ScriptName"

        Invoke-WebRequest `
            -Uri $rawUrl `
            -OutFile $temporaryFile `
            -UseBasicParsing `
            -Headers $headers

        if (-not (Test-Path -LiteralPath $temporaryFile)) {
            throw 'O GitHub não retornou o arquivo esperado.'
        }

        $remoteHash = Get-Sha256 $temporaryFile
        $localHash = $null

        if (Test-Path -LiteralPath $LocalScript) {
            $localHash = Get-Sha256 $LocalScript
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
