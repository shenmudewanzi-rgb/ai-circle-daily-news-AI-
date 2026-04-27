param(
  [int]$Port = 8765,
  [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\backend.ps1"

Initialize-AIDailyEnvironment

$root = $PSScriptRoot
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"

if (-not [System.Net.HttpListener]::IsSupported) {
  throw "HttpListener is not supported on this system."
}

$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host ""
Write-Host "AI圈今日要闻 is running at $prefix" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the local server." -ForegroundColor Yellow
Write-Host ""

if (-not $NoBrowser) {
  Start-Process $prefix | Out-Null
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

function Read-BodyText {
  param(
    [Parameter(Mandatory)]
    [System.Net.HttpListenerRequest]$Request
  )

  $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
  try {
    $reader.ReadToEnd()
  } finally {
    $reader.Close()
  }
}

function Send-JsonResponse {
  param(
    [Parameter(Mandatory)]
    [System.Net.HttpListenerResponse]$Response,
    [Parameter(Mandatory)]
    $Payload,
    [int]$StatusCode = 200
  )

  $json = $Payload | ConvertTo-Json -Depth 8
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $Response.StatusCode = $StatusCode
  $Response.ContentType = "application/json; charset=utf-8"
  $Response.ContentLength64 = $bytes.Length
  $Response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
  $Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Response.Close()
}

function Serve-StaticFile {
  param(
    [Parameter(Mandatory)]
    [System.Net.HttpListenerRequest]$Request,
    [Parameter(Mandatory)]
    [System.Net.HttpListenerResponse]$Response
  )

  $relativePath = $Request.Url.AbsolutePath.TrimStart("/")
  if ([string]::IsNullOrWhiteSpace($relativePath)) {
    $relativePath = "index.html"
  }

  $filePath = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
    $Response.StatusCode = 404
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.Close()
    return
  }

  $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
  $contentType = if ($contentTypes.ContainsKey($extension)) { $contentTypes[$extension] } else { "application/octet-stream" }
  $bytes = [System.IO.File]::ReadAllBytes($filePath)
  $Response.ContentType = $contentType
  $Response.ContentLength64 = $bytes.Length
  $Response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
  $Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Response.Close()
}

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    try {
      switch -Regex ($request.Url.AbsolutePath) {
        "^/api/health$" {
          Send-JsonResponse -Response $response -Payload @{
            ok = $true
            app = "AI圈今日要闻"
            now = (Get-Date).ToString("o")
          }
          continue
        }

        "^/api/config$" {
          if ($request.HttpMethod -eq "GET") {
            Send-JsonResponse -Response $response -Payload (Get-AIDailyConfig)
            continue
          }

          if ($request.HttpMethod -eq "POST") {
            $body = Read-BodyText -Request $request
            $payload = if ($body.Trim()) { ConvertTo-AIDailyHashtable -InputObject ($body | ConvertFrom-Json) } else { @{} }
            Send-JsonResponse -Response $response -Payload (Save-AIDailyConfig -Config $payload)
            continue
          }
        }

        "^/api/report/latest$" {
          $refresh = $request.Url.Query -match "refresh=1"
          Send-JsonResponse -Response $response -Payload (Get-AIDailyLatestReport -Refresh:$refresh)
          continue
        }

        "^/api/report/generate$" {
          $body = Read-BodyText -Request $request
          $payload = if ($body.Trim()) { ConvertTo-AIDailyHashtable -InputObject ($body | ConvertFrom-Json) } else { @{} }
          $push = $false
          if ($payload.ContainsKey("push")) {
            $push = [bool]$payload["push"]
          }
          Send-JsonResponse -Response $response -Payload (New-AIDailyReport -Persist -Push:$push)
          continue
        }

        "^/api/push/test$" {
          $report = Get-AIDailyLatestReport
          $channels = Send-AIDailyPush -Report $report
          Send-JsonResponse -Response $response -Payload @{
            ok = $true
            channels = $channels
          }
          continue
        }

        default {
          Serve-StaticFile -Request $request -Response $response
          continue
        }
      }
    } catch {
      Send-JsonResponse -Response $response -StatusCode 500 -Payload @{
        ok = $false
        error = $_.Exception.Message
      }
    }
  }
}
finally {
  if ($listener.IsListening) {
    $listener.Stop()
  }
  $listener.Close()
}
