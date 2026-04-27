$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$source = Join-Path $root "data\latest-report.json"

if (-not (Test-Path -LiteralPath $source)) {
  throw "Missing source report. Run generate-daily-brief.ps1 first."
}

$raw = Get-Content -LiteralPath $source -Raw -Encoding utf8
$report = $raw | ConvertFrom-Json
$json = $report | ConvertTo-Json -Depth 10
$content = @"
module.exports = $json;
"@

$targets = @(
  (Join-Path $root "wechat-miniprogram\mock\report.js"),
  (Join-Path $root "alipay-miniprogram\mock\report.js")
)

foreach ($target in $targets) {
  $dir = Split-Path -Parent $target
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  Set-Content -LiteralPath $target -Value $content -Encoding utf8
}

Write-Host ""
Write-Host "Mini-program mock data updated." -ForegroundColor Green
Write-Host ""
