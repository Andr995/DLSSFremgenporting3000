@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   RTX 30/40 MFG Unlock - Local Build Script
echo ========================================================

where cl.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [!] cl.exe (MSVC) was not found in PATH.
    echo [!] Please run this script from the "x64 Native Tools Command Prompt for VS 2022".
    echo [!] Or open Developer PowerShell for VS 2022.
    pause
    exit /b 1
)

where ml64.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [!] ml64.exe (MASM) was not found in PATH.
    echo [!] Ensure MASM is installed in Visual Studio Desktop C++ workload.
    pause
    exit /b 1
)

if not exist "deps" mkdir deps
cd deps

if not exist "Streamline" (
    echo [*] Cloning NVIDIA Streamline SDK...
    git clone --depth 1 https://github.com/NVIDIAGameWorks/Streamline.git
)

if not exist "reshade" (
    echo [*] Cloning ReShade SDK...
    git clone --depth 1 --branch v6.8.0 https://github.com/crosire/reshade.git
)

if not exist "imgui" (
    echo [*] Cloning Dear ImGui...
    git clone --depth 1 --branch v1.91.5 https://github.com/ocornut/imgui.git
)

cd ..

echo [*] Configuring with CMake...
cmake -B build -S source/native -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DSTREAMLINE_ROOT="%CD%/deps/Streamline" ^
    -DRESHADE_ROOT="%CD%/deps/reshade" ^
    -DIMGUI_ROOT="%CD%/deps/imgui" ^
    -DMFG_UNLOCK_BUILD_UNIVERSAL_UI=ON

if %ERRORLEVEL% NEQ 0 (
    echo [!] CMake configuration failed.
    pause
    exit /b 1
)

echo [*] Building binaries...
cmake --build build --config Release

if %ERRORLEVEL% NEQ 0 (
    echo [!] Compilation failed.
    pause
    exit /b 1
)

if not exist "dist" mkdir dist
copy /Y build\RTX40MFGCore.dll dist\
copy /Y build\RTX40MFG.asi dist\
copy /Y build\RTX40MFG-UI.addon64 dist\

echo ========================================================
echo   Build Successful! Artifacts placed in: %CD%\dist
echo ========================================================
pause
