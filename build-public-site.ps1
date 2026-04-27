$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$publicDir = Join-Path $root "public-site"

if (-not (Test-Path -LiteralPath (Join-Path $root "exports\latest-report.json"))) {
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

Copy-Item -LiteralPath (Join-Path $root "exports\latest-report.json") -Destination (Join-Path $publicDir "latest-report.json") -Force
Copy-Item -LiteralPath (Join-Path $root "exports\latest-report.md") -Destination (Join-Path $publicDir "latest-report.md") -Force
Copy-Item -LiteralPath (Join-Path $root "exports\latest-topics.csv") -Destination (Join-Path $publicDir "latest-topics.csv") -Force

$buildMeta = [ordered]@{
  appName = "AI圈今日要闻"
  generatedAt = (Get-Date).ToString("o")
  latestReportJson = "/latest-report.json"
  latestReportMarkdown = "/latest-report.md"
  latestTopicsCsv = "/latest-topics.csv"
}

($buildMeta | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath (Join-Path $publicDir "build-meta.json") -Encoding utf8

@"
User-agent: *
Allow: /
"@ | Set-Content -LiteralPath (Join-Path $publicDir "robots.txt") -Encoding utf8

@"
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="refresh" content="0; url=./index.html" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AI圈今日要闻</title>
  </head>
  <body>
    <p>正在返回首页… <a href="./index.html">点击这里</a></p>
  </body>
</html>
"@ | Set-Content -LiteralPath (Join-Path $publicDir "404.html") -Encoding utf8

Write-Host ""
Write-Host "Public site bundle updated at: $publicDir" -ForegroundColor Green
Write-Host ""
