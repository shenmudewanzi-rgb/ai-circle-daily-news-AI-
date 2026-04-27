$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$publicDir = Join-Path $root "public-site"
$publicConfigSourcePath = Join-Path $root "public-site-config.json"
$exportsJsonPath = Join-Path $root "exports\latest-report.json"
$exportsMarkdownPath = Join-Path $root "exports\latest-report.md"
$exportsCsvPath = Join-Path $root "exports\latest-topics.csv"

if (-not (Test-Path -LiteralPath $exportsJsonPath)) {
  throw "Missing exported report. Run generate-daily-brief.ps1 first."
}

if (-not (Test-Path -LiteralPath $publicDir)) {
  New-Item -ItemType Directory -Path $publicDir | Out-Null
}

$staticFiles = @(
  "index.html",
  "app.js",
  "styles.css",
  "manifest.webmanifest",
  "icon.svg",
  "sw.js"
)

foreach ($file in $staticFiles) {
  Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $publicDir $file) -Force
}

Copy-Item -LiteralPath $exportsJsonPath -Destination (Join-Path $publicDir "latest-report.json") -Force
Copy-Item -LiteralPath $exportsMarkdownPath -Destination (Join-Path $publicDir "latest-report.md") -Force
Copy-Item -LiteralPath $exportsCsvPath -Destination (Join-Path $publicDir "latest-topics.csv") -Force

$buildMeta = [ordered]@{
  appName = "AI Circle Daily News"
  generatedAt = (Get-Date).ToString("o")
  latestReportJson = "/latest-report.json"
  latestReportMarkdown = "/latest-report.md"
  latestTopicsCsv = "/latest-topics.csv"
}

($buildMeta | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath (Join-Path $publicDir "build-meta.json") -Encoding utf8

$publicConfig = [ordered]@{
  appName = "AI Circle Daily News"
  mode = "read-only"
  apiBaseUrl = ""
  publicDataUrl = "./latest-report.json"
  publicMarkdownUrl = "./latest-report.md"
  publicTopicsCsvUrl = "./latest-topics.csv"
}

if (Test-Path -LiteralPath $publicConfigSourcePath) {
  try {
    $customConfig = Get-Content -LiteralPath $publicConfigSourcePath -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($property in $customConfig.PSObject.Properties) {
      $publicConfig[$property.Name] = $property.Value
    }
  } catch {
    Write-Warning "Failed to parse public-site-config.json. Using default public config."
  }
}

($publicConfig | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath (Join-Path $publicDir "site-config.json") -Encoding utf8

@"
User-agent: *
Allow: /
"@ | Set-Content -LiteralPath (Join-Path $publicDir "robots.txt") -Encoding utf8

@"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="refresh" content="0; url=./index.html" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AI Circle Daily News</title>
  </head>
  <body>
    <p>Redirecting to the home page... <a href="./index.html">Click here</a></p>
  </body>
</html>
"@ | Set-Content -LiteralPath (Join-Path $publicDir "404.html") -Encoding utf8

Write-Host ""
Write-Host "Public site bundle updated at: $publicDir" -ForegroundColor Green
Write-Host ""
