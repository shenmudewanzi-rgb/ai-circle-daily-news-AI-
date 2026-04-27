$ErrorActionPreference = "Stop"

$taskName = "AI圈今日要闻_9点早报"
$scriptPath = Join-Path $PSScriptRoot "generate-daily-brief.ps1"
$quotedScript = '"' + $scriptPath + '"'
$arguments = "powershell.exe -ExecutionPolicy Bypass -File $quotedScript"

schtasks.exe /Create /SC DAILY /TN $taskName /TR $arguments /ST 09:00 /F | Out-Null

if ($LASTEXITCODE -ne 0) {
  throw "Failed to create the Windows scheduled task. Try running PowerShell as Administrator."
}

Write-Host ""
Write-Host "已安装每日 09:00 定时任务: $taskName" -ForegroundColor Green
Write-Host "执行脚本: $scriptPath"
Write-Host ""
