# 测试脚本 - 验证程序是否能启动且处理 CSV
$csvFile = "c:\Users\lzj\Github\CubeX_PnP\PickAndPlace_PCB5_2026_03_21.csv"
$exePath = "c:\Users\lzj\Github\CubeX_PnP\build\Desktop_Qt_6_10_2_MinGW_64_bit-Debug\appCubeX_PnP.exe"

Write-Host "Starting program test..."
Write-Host "Executable: $exePath"
Write-Host "CSV File: $csvFile"

if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: Executable not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $csvFile)) {
    Write-Host "ERROR: CSV file not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Starting application..." -ForegroundColor Green
Start-Process -FilePath $exePath -WindowStyle Normal

Write-Host "Waiting 5 seconds for application to initialize..."
Start-Sleep -Seconds 5

$proc = Get-Process appCubeX_PnP -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "SUCCESS: Application is running" -ForegroundColor Green
    Write-Host "Process ID: $($proc.Id)"
    Write-Host ""
    Write-Host "Manual Test Steps:"
    Write-Host "1. Click 'Import' button or use File menu"
    Write-Host "2. Select: $csvFile"
    Write-Host "3. Observe PCB preview area for:"
    Write-Host "   - Blue rectangles (based on package size)"
    Write-Host "   - Red center dots (component positions)"
    Write-Host "   - Automatic Y-axis direction selection"
    Write-Host ""
    Write-Host "Check console output for:"
    Write-Host "   - [MODE_DETECT] - Y-axis auto-detection"
    Write-Host "   - [COMPONENT] - Component placement info"
    exit 0
} else {
    Write-Host "ERROR: Application failed to start" -ForegroundColor Red
    exit 1
}
