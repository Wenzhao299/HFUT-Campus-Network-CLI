param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$CliArgs
)

$ErrorActionPreference = "Stop"

function Show-Usage {
  @"
usage:
  hfut-net login <username> <password>
  hfut-net logout
  hfut-net keep-online [username] [password]

aliases:
  hfut-net online <username> <password>
  hfut-net offline
  hfut-net keepalive [username] [password]
"@ | Write-Output
}

if ($null -eq $CliArgs -or $CliArgs.Count -lt 1) {
  Show-Usage
  exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cmd = $CliArgs[0].ToLowerInvariant()
$rest = @()
if ($CliArgs.Count -gt 1) {
  $rest = $CliArgs[1..($CliArgs.Count - 1)]
}

switch ($cmd) {
  "login" {
    if ($rest.Count -ne 2) {
      Show-Usage
      exit 1
    }
    & "$scriptDir\online.ps1" $rest[0] $rest[1]
    exit $LASTEXITCODE
  }
  "online" {
    if ($rest.Count -ne 2) {
      Show-Usage
      exit 1
    }
    & "$scriptDir\online.ps1" $rest[0] $rest[1]
    exit $LASTEXITCODE
  }
  "logout" {
    if ($rest.Count -ne 0) {
      Show-Usage
      exit 1
    }
    & "$scriptDir\offline.ps1"
    exit $LASTEXITCODE
  }
  "offline" {
    if ($rest.Count -ne 0) {
      Show-Usage
      exit 1
    }
    & "$scriptDir\offline.ps1"
    exit $LASTEXITCODE
  }
  "keep-online" {
    if ($rest.Count -ne 0 -and $rest.Count -ne 2) {
      Show-Usage
      exit 1
    }
    & "$scriptDir\keep-online.ps1" @rest
    exit $LASTEXITCODE
  }
  "keepalive" {
    if ($rest.Count -ne 0 -and $rest.Count -ne 2) {
      Show-Usage
      exit 1
    }
    & "$scriptDir\keep-online.ps1" @rest
    exit $LASTEXITCODE
  }
  "help" {
    Show-Usage
    exit 0
  }
  "-h" {
    Show-Usage
    exit 0
  }
  "--help" {
    Show-Usage
    exit 0
  }
  default {
    Write-Output "unknown command: $cmd"
    Show-Usage
    exit 1
  }
}
