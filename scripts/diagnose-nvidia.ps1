[CmdletBinding()]
param([string]$Compiler = 'g++')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo 'build-tests/diagnostics'
New-Item -ItemType Directory -Force $build | Out-Null
$exe = Join-Path $build 'NvidiaDiagnostics.exe'
& $Compiler -std=c++20 -O2 -Wall -Wextra -Wpedantic -Werror -static `
    (Join-Path $repo 'tools/nvidia_diagnostics.cpp') -o $exe
if ($LASTEXITCODE -ne 0) { throw 'NVIDIA diagnostic tool compilation failed.' }
& $exe
if ($LASTEXITCODE -ne 0) { throw 'NVIDIA diagnostic query failed; see the driver error above.' }
