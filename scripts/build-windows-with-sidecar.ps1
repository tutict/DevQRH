$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$sidecarDir = Join-Path $root "sidecar\rag"
$mobileDir = Join-Path $root "mobile"
$sidecarBuildDir = Join-Path $mobileDir "build\sidecar"
$sidecarExe = Join-Path $sidecarBuildDir "rag_sidecar.exe"
$releaseDir = Join-Path $mobileDir "build\windows\x64\runner\Release"

New-Item -ItemType Directory -Force -Path $sidecarBuildDir | Out-Null

Push-Location $sidecarDir
try {
  $env:GOOS = "windows"
  $env:GOARCH = "amd64"
  go build -o $sidecarExe .
} finally {
  Pop-Location
}

Push-Location $mobileDir
try {
  flutter build windows
} finally {
  Pop-Location
}

Copy-Item -LiteralPath $sidecarExe -Destination (Join-Path $releaseDir "rag_sidecar.exe") -Force

Write-Host "Built Flutter app with Go sidecar:"
Write-Host $releaseDir
