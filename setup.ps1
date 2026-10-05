# Dragon Boat Runner - one-time project setup (Windows PowerShell)
# Run in this folder:   powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host '1/5  Creating Android + iOS platform files (existing files are kept)...' -ForegroundColor Cyan
flutter create --org de.dragonboatrunner --project-name dragon_boat_runner --platforms android,ios .

Write-Host '2/5  Android: minSdk 24 (needed by Firebase)...' -ForegroundColor Cyan
foreach ($g in @('android/app/build.gradle.kts', 'android/app/build.gradle')) {
  if (Test-Path $g) {
    $c = Get-Content $g -Raw
    $c = $c -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24'
    $c = $c -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24'
    Set-Content -Path $g -Value $c -NoNewline
  }
}

Write-Host '3/5  iOS: deployment target 15.0...' -ForegroundColor Cyan
$pbx = 'ios/Runner.xcodeproj/project.pbxproj'
if (Test-Path $pbx) {
  $c = Get-Content $pbx -Raw
  $c = $c -replace 'IPHONEOS_DEPLOYMENT_TARGET = \d+\.\d+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;'
  Set-Content -Path $pbx -Value $c -NoNewline
}

Write-Host '4/5  Downloading packages...' -ForegroundColor Cyan
flutter pub get

Write-Host '5/5  App icons (dragon)...' -ForegroundColor Cyan
dart run flutter_launcher_icons

Write-Host ''
Write-Host 'Done. Next: connect Firebase with  flutterfire configure  (see README.md).' -ForegroundColor Green
