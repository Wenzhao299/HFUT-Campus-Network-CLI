param(
  [string]$Username,
  [string]$Password
)

$ErrorActionPreference = "Stop"

function Show-Usage {
  @"
usage:
  .\keep-online.ps1 [username] [password]

credentials:
  pass username/password as arguments, or set HFUT_NET_USERNAME and HFUT_NET_PASSWORD
"@ | Write-Output
}

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    Write-Output "missing dependency: $Name"
    exit 1
  }
}

function Invoke-CampusCurl {
  param([string[]]$Args)
  try {
    $output = & curl.exe --noproxy "*" @Args 2>$null
    if ($LASTEXITCODE -ne 0 -or $null -eq $output) {
      return ""
    }
    return ($output -join "`n")
  } catch {
    return ""
  }
}

function Test-CaptiveUrl {
  param([string]$Url)
  $tokens = @("172.16.200.", "192.168.4.1", "210.45.240.", "eportal")
  foreach ($token in $tokens) {
    if ($Url -like "*$token*") {
      return $true
    }
  }
  return $false
}

function Test-Internet {
  $probes = @(
    @{ Url = "http://connect.rom.miui.com/generate_204"; Codes = @("204") }
    @{ Url = "http://connectivitycheck.gstatic.com/generate_204"; Codes = @("204") }
    @{ Url = "http://www.baidu.com"; Codes = @("200", "301", "302") }
  )

  foreach ($probe in $probes) {
    $result = Invoke-CampusCurl @(
      "-4", "-L", "--connect-timeout", "2", "-sS", "-m", "4",
      "-o", "NUL", "-w", "%{http_code} %{url_effective}", $probe.Url
    )
    if ([string]::IsNullOrWhiteSpace($result)) {
      continue
    }

    $parts = $result.Trim() -split "\s+", 2
    $code = $parts[0]
    $effective = if ($parts.Length -gt 1) { $parts[1] } else { "" }
    if (($probe.Codes -contains $code) -and -not (Test-CaptiveUrl $effective)) {
      return $true
    }
  }

  return $false
}

function Resolve-Credentials {
  if (-not [string]::IsNullOrWhiteSpace($Username) -and -not [string]::IsNullOrWhiteSpace($Password)) {
    return @($Username, $Password)
  }

  if (-not [string]::IsNullOrWhiteSpace($env:HFUT_NET_USERNAME) -and -not [string]::IsNullOrWhiteSpace($env:HFUT_NET_PASSWORD)) {
    return @($env:HFUT_NET_USERNAME, $env:HFUT_NET_PASSWORD)
  }

  Show-Usage
  exit 1
}

Require-Command "curl.exe"

$credentials = Resolve-Credentials
if (Test-Internet) {
  Write-Output "keep-online: already online"
  exit 0
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Output "keep-online: offline detected, trying login"
& "$scriptDir\online.ps1" $credentials[0] $credentials[1]
exit $LASTEXITCODE
