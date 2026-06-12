# Chat App 启动脚本
# 自动建立 ADB 端口转发并启动 Flutter

Write-Host "[1/2] 建立 ADB 端口转发..." -ForegroundColor Cyan
& "C:\Users\sjh\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:3000 tcp:3000
if (0 -eq 0) {
    Write-Host "  adb reverse 3000 -> 3000  成功" -ForegroundColor Green
} else {
    Write-Host "  adb reverse 失败，请确认设备已连接" -ForegroundColor Red
}

Write-Host "[2/2] 启动 Flutter..." -ForegroundColor Cyan
flutter run --dart-define=USE_ADB_REVERSE=true
