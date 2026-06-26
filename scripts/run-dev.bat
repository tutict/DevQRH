@echo off
REM One-click dev launcher for DevQRH on Windows.
REM Builds the Go RAG sidecar, fetches Flutter deps, then runs the desktop app.
REM Flutter auto-discovers the sidecar at mobile\build\sidecar\rag_sidecar.exe
REM (relative to the mobile working dir), so no env var is required.
setlocal

set "DEVICE=%~1"
if "%DEVICE%"=="" set "DEVICE=windows"

set "ROOT=%~dp0.."
set "SIDECAR_DIR=%ROOT%\sidecar\rag"
set "MOBILE_DIR=%ROOT%\mobile"
set "SIDECAR_BUILD_DIR=%MOBILE_DIR%\build\sidecar"
set "SIDECAR_EXE=%SIDECAR_BUILD_DIR%\rag_sidecar.exe"

if not exist "%SIDECAR_BUILD_DIR%" mkdir "%SIDECAR_BUILD_DIR%"

echo [1/3] Building Go RAG sidecar...
pushd "%SIDECAR_DIR%"
set "GOOS=windows"
set "GOARCH=amd64"
go build -o "%SIDECAR_EXE%" .
if errorlevel 1 ( popd & echo Sidecar build failed. & exit /b 1 )
popd
echo       -^> %SIDECAR_EXE%

pushd "%MOBILE_DIR%"
echo [2/3] Fetching Flutter dependencies...
call flutter pub get
if errorlevel 1 ( popd & echo flutter pub get failed. & exit /b 1 )

echo [3/3] Running Flutter app on '%DEVICE%'...
call flutter run -d %DEVICE%
set "RC=%errorlevel%"
popd

endlocal & exit /b %RC%
