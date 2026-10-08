# Builds an installable TEST APK on this Windows PC (demo mode, no Firebase needed).
# Needs: Flutter + Android Studio installed (see README.md).
#   powershell -ExecutionPolicy Bypass -File .\build_test_apk.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path 'android/app/build.gradle.kts') -and -not (Test-Path 'android/app/build.gradle')) {
  & "$PSScriptRoot\setup.ps1"
}
flutter build apk --debug --target-platform android-arm64 --dart-define=DEMO=true
Copy-Item 'build/app/outputs/flutter-apk/app-debug.apk' 'DragonBoatRunner-demo.apk' -Force
Write-Host ''
Write-Host 'Fertig / Done:  DragonBoatRunner-demo.apk  (in this folder)' -ForegroundColor Green
Write-Host 'Copy it to your Android phone and open it to install.' -ForegroundColor Green
