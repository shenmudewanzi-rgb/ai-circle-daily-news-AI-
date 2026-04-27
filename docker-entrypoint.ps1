$ErrorActionPreference = "Stop"

$port = if ($env:PORT) { [int]$env:PORT } else { 8765 }
$hostName = if ($env:HOST_NAME) { $env:HOST_NAME } else { "*" }
$allowedOrigins = if ($env:ALLOWED_ORIGINS) { $env:ALLOWED_ORIGINS } else { "" }

& "$PSScriptRoot\start-server.ps1" -Port $port -NoBrowser -HostName $hostName -AllowedOrigins $allowedOrigins
