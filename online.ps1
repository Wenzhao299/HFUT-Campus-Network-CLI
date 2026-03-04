param(
  [string]$Username,
  [string]$Password
)

$ErrorActionPreference = "Stop"

$Gateways = @(
  "http://172.16.200.11"
  "http://172.16.200.12"
  "http://192.168.4.1"
)
$LegacyPortal = "http://210.45.240.245"
$EportalHost = "http://210.45.240.105:801"

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

function Get-GatewayPage {
  return (Invoke-CampusCurl @("-sS", "--connect-timeout", "2", "-m", "5", $Gateways[0]))
}

function Invoke-LoginLegacyRedirect {
  param(
    [string]$User,
    [string]$Pass
  )

  $content = Get-GatewayPage
  if ([string]::IsNullOrWhiteSpace($content)) {
    return $false
  }
  if ($content -notmatch "FC_XueShengSuSh" -and $content -notmatch "FCH-HJ_bkl-RG18") {
    return $false
  }

  $redirectMatch = [regex]::Match($content, "'(http[^']+)'")
  $cookie = ""
  if ($redirectMatch.Success) {
    $headers = Invoke-CampusCurl @("-I", "-sS", "--connect-timeout", "2", "-m", "5", $redirectMatch.Groups[1].Value)
    $cookieMatch = [regex]::Match($headers, "(?im)^Set-Cookie:\s*([^;]+;)")
    if ($cookieMatch.Success) {
      $cookie = $cookieMatch.Groups[1].Value
    }
  }

  $payload = "username=$User&password=$Pass&0MKKey=%B5%C7+%C2%BC&savePWD=0"
  if (-not [string]::IsNullOrWhiteSpace($cookie)) {
    $response = Invoke-CampusCurl @("-sS", "--connect-timeout", "2", "-m", "6", "-b", $cookie, "-d", $payload, "$LegacyPortal/post.php")
  } else {
    $response = Invoke-CampusCurl @("-sS", "--connect-timeout", "2", "-m", "6", "-d", $payload, "$LegacyPortal/post.php")
  }

  return -not [string]::IsNullOrWhiteSpace($response)
}

function Get-LocalIp {
  try {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.Connect("1.1.1.1", 53)
    $ep = [System.Net.IPEndPoint]$udp.Client.LocalEndPoint
    $udp.Close()
    if ($null -ne $ep -and $null -ne $ep.Address) {
      $ip = $ep.Address.ToString()
      if (-not [string]::IsNullOrWhiteSpace($ip)) {
        return $ip
      }
    }
  } catch {}

  try {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
      Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -notlike "169.254.*" } |
      Select-Object -First 1 -ExpandProperty IPAddress
    if (-not [string]::IsNullOrWhiteSpace($ip)) {
      return $ip
    }
  } catch {}

  try {
    $text = (& ipconfig) | Out-String
    $match = [regex]::Match($text, "(?im)IPv4 (?:Address|地址)[^:]*:\s*([0-9.]+)")
    if ($match.Success) {
      return $match.Groups[1].Value
    }
  } catch {}

  return ""
}

function Invoke-LoginEportal {
  param(
    [string]$User,
    [string]$Pass
  )

  $content = Get-GatewayPage
  if ([string]::IsNullOrWhiteSpace($content)) {
    return $false
  }
  if ($content -notmatch "HFUT-WiFi" -and $content -notmatch "<NextURL>") {
    return $false
  }

  $parameter = ""
  $redirectMatch = [regex]::Match($content, "<NextURL>(.*?)</NextURL>", [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($redirectMatch.Success) {
    $queryMatch = [regex]::Match($redirectMatch.Groups[1].Value, "\?(.*)")
    if ($queryMatch.Success) {
      $parameter = $queryMatch.Groups[1].Value -replace "(wlan|user|ac|nas)", '$1_'
    }
  }

  if ([string]::IsNullOrWhiteSpace($parameter)) {
    $ip = Get-LocalIp
    if ([string]::IsNullOrWhiteSpace($ip)) {
      return $false
    }
    $parameter = "wlan_user_ip=$ip&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name="
  }

  $null = Invoke-CampusCurl @("-sS", "--connect-timeout", "2", "-m", "5", "$EportalHost/eportal/?c=Portal&a=page_type_data")

  $encUser = [System.Uri]::EscapeDataString($User)
  $encPass = [System.Uri]::EscapeDataString($Pass)
  $response = Invoke-CampusCurl @(
    "-sS", "--connect-timeout", "2", "-m", "6",
    "$EportalHost/eportal/?c=Portal&a=login&callback=dr1003&login_method=1&user_account=$encUser&user_password=$encPass&$parameter"
  )
  return -not [string]::IsNullOrWhiteSpace($response)
}

function Invoke-LoginDrcomDirect {
  param(
    [string]$User,
    [string]$Pass
  )

  foreach ($gateway in $Gateways) {
    $response = Invoke-CampusCurl @(
      "-sS", "--connect-timeout", "2", "-m", "6",
      "--data-urlencode", "DDDDD=$User",
      "--data-urlencode", "upass=$Pass",
      "--data", "0MKKey=123456&R1=0&R2=&R3=0&R6=0&para=00&v6ip=&terminal_type=1&lang=zh-cn",
      $gateway
    )
    if (-not [string]::IsNullOrWhiteSpace($response)) {
      return $true
    }
  }
  return $false
}

if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
  Write-Output "usage: .\online.ps1 <username> <password>"
  exit 1
}

Require-Command "curl.exe"

$attempted = $false

if (Invoke-LoginDrcomDirect $Username $Password) {
  $attempted = $true
}
if (Test-Internet) {
  Write-Output "online: login success (drcom direct)"
  exit 0
}

if (Invoke-LoginLegacyRedirect $Username $Password) {
  $attempted = $true
}
if (Test-Internet) {
  Write-Output "online: login success (legacy portal)"
  exit 0
}

if (Invoke-LoginEportal $Username $Password) {
  $attempted = $true
}
if (Test-Internet) {
  Write-Output "online: login success (eportal)"
  exit 0
}

if ($attempted) {
  Write-Output "login request sent, but internet check failed"
} else {
  Write-Output "no reachable auth page from campus gateway"
}
exit 1
