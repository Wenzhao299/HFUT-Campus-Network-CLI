param()

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

function Invoke-LogoutDrcom {
  foreach ($gateway in $Gateways) {
    $response = Invoke-CampusCurl @("-sS", "--connect-timeout", "2", "-m", "5", "$gateway/F.htm")
    if (-not [string]::IsNullOrWhiteSpace($response)) {
      return $true
    }
  }

  $response = Invoke-CampusCurl @("-sS", "--connect-timeout", "2", "-m", "5", "$LegacyPortal/F.htm")
  return -not [string]::IsNullOrWhiteSpace($response)
}

function Invoke-LogoutEportal {
  $ip = Get-LocalIp
  if ([string]::IsNullOrWhiteSpace($ip)) {
    return $false
  }

  $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $logoutUrl = "$EportalHost/eportal/?c=Portal&a=logout&callback=dr1004&login_method=1&user_account=drcom&user_password=123&ac_logout=1&register_mode=1&wlan_user_ip=$ip&wlan_user_ipv6=&wlan_vlan_id=1&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=4.1.3&v=$ts"
  $response = Invoke-CampusCurl @("-sS", "--connect-timeout", "2", "-m", "6", $logoutUrl)
  if (-not [string]::IsNullOrWhiteSpace($response)) {
    return $true
  }

  $unbindUrl = "$EportalHost/eportal/?c=Portal&a=unbind_mac&callback=dr1004&user_account=drcom&wlan_user_ip=$ip&jsVersion=4.1.3&v=$ts"
  $response = Invoke-CampusCurl @("-sS", "--connect-timeout", "2", "-m", "6", $unbindUrl)
  return -not [string]::IsNullOrWhiteSpace($response)
}

Require-Command "curl.exe"

if (Invoke-LogoutDrcom) {
  Write-Output "offline: logout request sent (drcom)"
  exit 0
}

if (Invoke-LogoutEportal) {
  Write-Output "offline: logout request sent (eportal)"
  exit 0
}

Write-Output "offline: no reachable auth server"
exit 1
