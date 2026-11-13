param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK 3.44+ is required and must be on PATH.'
}
$project = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $project
try {
  flutter create --platforms=android,windows --project-name flow_vpn .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' }
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
  if (-not $SkipBuild) {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
    flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) { throw 'AAB build failed' }
  }
} finally {
  Pop-Location
}
