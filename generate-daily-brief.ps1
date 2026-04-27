$ErrorActionPreference = "Stop"
. "$PSScriptRoot\backend.ps1"

Initialize-AIDailyEnvironment
$config = Get-AIDailyConfig
$push = [bool]$config.enableAutoPush
$report = New-AIDailyReport -Persist -Push:$push
& "$PSScriptRoot\generate-miniapp-mock.ps1" | Out-Null
& "$PSScriptRoot\build-public-site.ps1" | Out-Null

Write-Host ""
Write-Host "AI圈今日要闻已生成。" -ForegroundColor Green
Write-Host "生成时间: $($report.generatedAt)"
Write-Host "资讯条数: $($report.counts.total)"
Write-Host "大V/分析师: $($report.counts.creator)"
if ($push -and $report.PSObject.Properties.Name -contains "pushedChannels") {
  Write-Host "已推送渠道: $([string]::Join(', ', $report.pushedChannels))"
}
Write-Host ""
