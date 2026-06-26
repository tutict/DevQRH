# One-click dev launcher for DevQRH on Windows.
# Builds the Go RAG sidecar, fetches Flutter deps, then runs the desktop app.
# Flutter auto-discovers the sidecar at mobile\build\sidecar\rag_sidecar.exe
# (relative to the mobile working dir), so no env var is required.
param(
  [string]$Device = "windows"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$sidecarDir = Join-Path $root "sidecar\rag"
$mobileDir = Join-Path $root "mobile"
$sidecarBuildDir = Join-Path $mobileDir "build\sidecar"
$sidecarExe = Join-Path $sidecarBuildDir "rag_sidecar.exe"

New-Item -ItemType Directory -Force -Path $sidecarBuildDir | Out-Null

Write-Host "[1/3] Building Go RAG sidecar..."
Push-Location $sidecarDir
try {
  $env:GOOS = "windows"
  $env:GOARCH = "amd64"
  go build -o $sidecarExe .
} finally {
  Pop-Location
}
Write-Host "      -> $sidecarExe"

Push-Location $mobileDir
try {
  Write-Host "[2/3] Fetching Flutter dependencies..."
  flutter pub get

  Write-Host "[3/3] Running Flutter app on '$Device'..."
  flutter run -d $Device
} finally {
  Pop-Location
}
