param(
  [int]$Port = 8765,
  [switch]$NoBrowser,
  [string]$HostName = "localhost",
  [string]$AllowedOrigins = ""
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\backend.ps1"

Initialize-AIDailyEnvironment

$root = $PSScriptRoot
$bindHost = if ([string]::IsNullOrWhiteSpace($HostName)) { "localhost" } else { $HostName.Trim() }
$browserUrl = "http://localhost:$Port/"
$corsOrigins = @(
  ($AllowedOrigins -split ",") |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ }
)

Write-Host ""
Write-Host "AI Circle Daily News is running on port $Port" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the local server." -ForegroundColor Yellow
Write-Host ""

if (-not $NoBrowser -and $bindHost -eq "localhost") {
  Start-Process $browserUrl | Out-Null
}

$contentTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".js" = "application/javascript; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".webmanifest" = "application/manifest+json; charset=utf-8"
  ".svg" = "image/svg+xml"
  ".png" = "image/png"
  ".ico" = "image/x-icon"
  ".md" = "text/markdown; charset=utf-8"
  ".csv" = "text/csv; charset=utf-8"
}

function Get-StatusDescription {
  param(
    [Parameter(Mandatory)]
    [int]$StatusCode
  )

  switch ($StatusCode) {
    200 { "OK" }
    204 { "No Content" }
    400 { "Bad Request" }
    404 { "Not Found" }
    405 { "Method Not Allowed" }
    500 { "Internal Server Error" }
    default { "OK" }
  }
}

function ConvertTo-ResponseBytes {
  param(
    [AllowNull()]
    [string]$Text
  )

  $value = if ($null -eq $Text) { "" } else { $Text }
  [System.Text.Encoding]::UTF8.GetBytes($value)
}

function Write-HttpResponse {
  param(
    [Parameter(Mandatory)]
    [System.Net.Sockets.NetworkStream]$Stream,
    [int]$StatusCode = 200,
    [string]$ContentType = "text/plain; charset=utf-8",
    [byte[]]$BodyBytes = @(),
    [hashtable]$Headers = @{}
  )

  $statusText = Get-StatusDescription -StatusCode $StatusCode
  $writer = [System.IO.StreamWriter]::new($Stream, [System.Text.UTF8Encoding]::new($false), 1024, $true)
  try {
    $writer.NewLine = "`r`n"
    $writer.WriteLine("HTTP/1.1 $StatusCode $statusText")
    $writer.WriteLine("Content-Type: $ContentType")
    $writer.WriteLine("Content-Length: $($BodyBytes.Length)")
    $writer.WriteLine("Connection: close")
    foreach ($entry in $Headers.GetEnumerator()) {
      $writer.WriteLine("$($entry.Key): $($entry.Value)")
    }
    $writer.WriteLine("")
    $writer.Flush()
    if ($BodyBytes.Length -gt 0) {
      $Stream.Write($BodyBytes, 0, $BodyBytes.Length)
      $Stream.Flush()
    }
  } finally {
    $writer.Dispose()
  }
}

function Get-CorsHeaders {
  param(
    [Parameter(Mandatory)]
    $Request
  )

  $headers = @{
    "Cache-Control" = "no-cache, no-store, must-revalidate"
  }

  if (-not $corsOrigins.Count) {
    return $headers
  }

  $origin = $Request.Headers["Origin"]
  if ([string]::IsNullOrWhiteSpace($origin)) {
    return $headers
  }

  if ($corsOrigins -contains "*" -or $corsOrigins -contains $origin) {
    $headers["Access-Control-Allow-Origin"] = if ($corsOrigins -contains "*") { "*" } else { $origin }
    $headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    $headers["Access-Control-Allow-Headers"] = "Content-Type"
    $headers["Vary"] = "Origin"
  }

  $headers
}

function Read-HttpRequest {
  param(
    [Parameter(Mandatory)]
    [System.Net.Sockets.TcpClient]$Client
  )

  $stream = $Client.GetStream()
  $stream.ReadTimeout = 30000
  $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $false, 8192, $true)

  $requestLine = $reader.ReadLine()
  if ([string]::IsNullOrWhiteSpace($requestLine)) {
    return $null
  }

  $parts = $requestLine.Split(" ")
  if ($parts.Length -lt 2) {
    throw "Malformed request line."
  }

  $headers = @{}
  while ($true) {
    $line = $reader.ReadLine()
    if ($null -eq $line -or $line -eq "") {
      break
    }

    $separator = $line.IndexOf(":")
    if ($separator -lt 1) {
      continue
    }

    $key = $line.Substring(0, $separator).Trim()
    $value = $line.Substring($separator + 1).Trim()
    $headers[$key] = $value
  }

  $contentLength = 0
  if ($headers.ContainsKey("Content-Length")) {
    [void][int]::TryParse($headers["Content-Length"], [ref]$contentLength)
  }

  $body = ""
  if ($contentLength -gt 0) {
    $buffer = New-Object char[] $contentLength
    $offset = 0
    while ($offset -lt $contentLength) {
      $read = $reader.Read($buffer, $offset, $contentLength - $offset)
      if ($read -le 0) {
        break
      }
      $offset += $read
    }
    $body = [string]::new($buffer, 0, $offset)
  }

  $target = $parts[1]
  $uri = [System.Uri]::new("http://localhost$target")

  [pscustomobject]@{
    Method = $parts[0].ToUpperInvariant()
    Target = $target
    Path = $uri.AbsolutePath
    Query = $uri.Query
    Body = $body
    Headers = $headers
    Stream = $stream
  }
}

function Send-JsonResponse {
  param(
    [Parameter(Mandatory)]
    $Request,
    [Parameter(Mandatory)]
    $Payload,
    [int]$StatusCode = 200
  )

  $json = $Payload | ConvertTo-Json -Depth 8
  Write-HttpResponse -Stream $Request.Stream -StatusCode $StatusCode -ContentType "application/json; charset=utf-8" -BodyBytes (ConvertTo-ResponseBytes -Text $json) -Headers (Get-CorsHeaders -Request $Request)
}

function Send-TextResponse {
  param(
    [Parameter(Mandatory)]
    $Request,
    [string]$Text,
    [int]$StatusCode = 200,
    [string]$ContentType = "text/plain; charset=utf-8"
  )

  Write-HttpResponse -Stream $Request.Stream -StatusCode $StatusCode -ContentType $ContentType -BodyBytes (ConvertTo-ResponseBytes -Text $Text) -Headers (Get-CorsHeaders -Request $Request)
}

function Serve-StaticFile {
  param(
    [Parameter(Mandatory)]
    $Request
  )

  $relativePath = $Request.Path.TrimStart("/")
  if ([string]::IsNullOrWhiteSpace($relativePath)) {
    $relativePath = "index.html"
  }

  $safeRelativePath = $relativePath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
  $filePath = Join-Path $root $safeRelativePath
  if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
    Send-TextResponse -Request $Request -Text "404 Not Found" -StatusCode 404
    return
  }

  $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
  $contentType = if ($contentTypes.ContainsKey($extension)) { $contentTypes[$extension] } else { "application/octet-stream" }
  $bytes = [System.IO.File]::ReadAllBytes($filePath)
  Write-HttpResponse -Stream $Request.Stream -StatusCode 200 -ContentType $contentType -BodyBytes $bytes -Headers (Get-CorsHeaders -Request $Request)
}

function Parse-JsonBody {
  param(
    [Parameter(Mandatory)]
    [string]$Body
  )

  if ([string]::IsNullOrWhiteSpace($Body)) {
    return @{}
  }

  ConvertTo-AIDailyHashtable -InputObject ($Body | ConvertFrom-Json)
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
$listener.Start()

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $request = Read-HttpRequest -Client $client
      if ($null -eq $request) {
        continue
      }

      if ($request.Method -eq "OPTIONS") {
        Write-HttpResponse -Stream $request.Stream -StatusCode 204 -ContentType "text/plain; charset=utf-8" -BodyBytes @() -Headers (Get-CorsHeaders -Request $request)
        continue
      }

      switch -Regex ($request.Path) {
        "^/api/health$" {
          Send-JsonResponse -Request $request -Payload @{
            ok = $true
            app = "AI Circle Daily News"
            now = (Get-Date).ToString("o")
          }
          continue
        }

        "^/api/config$" {
          if ($request.Method -eq "GET") {
            Send-JsonResponse -Request $request -Payload (Get-AIDailyConfig)
            continue
          }

          if ($request.Method -eq "POST") {
            $payload = Parse-JsonBody -Body $request.Body
            Send-JsonResponse -Request $request -Payload (Save-AIDailyConfig -Config $payload)
            continue
          }

          Send-TextResponse -Request $request -Text "Method Not Allowed" -StatusCode 405
          continue
        }

        "^/api/report/latest$" {
          $refresh = $request.Query -match "refresh=1"
          Send-JsonResponse -Request $request -Payload (Get-AIDailyLatestReport -Refresh:$refresh)
          continue
        }

        "^/api/report/generate$" {
          if ($request.Method -ne "POST") {
            Send-TextResponse -Request $request -Text "Method Not Allowed" -StatusCode 405
            continue
          }

          $payload = Parse-JsonBody -Body $request.Body
          $push = $false
          if ($payload.ContainsKey("push")) {
            $push = [bool]$payload["push"]
          }
          Send-JsonResponse -Request $request -Payload (New-AIDailyReport -Persist -Push:$push)
          continue
        }

        "^/api/push/test$" {
          $report = Get-AIDailyLatestReport
          $channels = Send-AIDailyPush -Report $report
          Send-JsonResponse -Request $request -Payload @{
            ok = $true
            channels = $channels
          }
          continue
        }

        default {
          Serve-StaticFile -Request $request
          continue
        }
      }
    } catch {
      if ($client.Connected) {
        $fallbackRequest = [pscustomobject]@{
          Headers = @{}
          Stream = $client.GetStream()
        }
        Send-JsonResponse -Request $fallbackRequest -Payload @{
          ok = $false
          error = $_.Exception.Message
        } -StatusCode 500
      }
    } finally {
      $client.Close()
    }
  }
}
finally {
  $listener.Stop()
}
