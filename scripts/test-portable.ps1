[CmdletBinding()]
param([string]$Compiler = 'g++')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo 'build-tests/portable'
New-Item -ItemType Directory -Force $build | Out-Null
Push-Location $repo
try {
    $cases = @(
        @{ Name = 'Fp8ReferenceTests'; Sources = @('tests/fp8_reference_tests.cpp', 'source/native/ampere_fp8_emulator.cpp') },
        @{ Name = 'PolicyTests'; Sources = @('tests/policy_tests.cpp') },
        @{ Name = 'ControlConfigTests'; Sources = @('tests/control_config_tests.cpp', 'source/native/control_config.cpp') },
        @{ Name = 'StatusValidationTests'; Sources = @('tests/status_validation_tests.cpp', 'source/native/status_validation.cpp') },
        @{ Name = 'RuntimePathsTests'; Sources = @('tests/runtime_paths_tests.cpp', 'source/native/runtime_paths.cpp') },
        @{ Name = 'ModuleLifetimeTests'; Sources = @('tests/module_lifetime_tests.cpp') }
    )
    $fixture = Join-Path $build 'LifetimeFixture.dll'
    & $Compiler -std=c++20 -shared -static -Isource/native tests/lifetime_fixture.cpp -o $fixture
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed: LifetimeFixture' }
    foreach ($case in $cases) {
        $exe = Join-Path $build ($case.Name + '.exe')
        $arguments = @('-std=c++20', '-O2', '-Wall', '-Wextra', '-Wpedantic', '-Werror',
            '-static', '-pthread', '-DNOMINMAX', '-DWIN32_LEAN_AND_MEAN', '-Isource/native', '-isystem', 'deps/Streamline/external/json/include')
        & $Compiler @arguments @($case.Sources) -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $($case.Name)" }
        if ($case.Name -eq 'ModuleLifetimeTests') { & $exe $fixture } else { & $exe }
        if ($LASTEXITCODE -ne 0) { throw "Test failed: $($case.Name)" }
    }
    Write-Host 'Regression tests passed, including Windows paths and DLL pinning. Game/GPU integration was not exercised.'
} finally {
    Pop-Location
}
