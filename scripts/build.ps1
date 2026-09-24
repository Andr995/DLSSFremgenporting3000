[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed (exit $LASTEXITCODE)." }
}

try {
    $missing = @('git', 'cmake', 'ctest', 'ninja', 'cl', 'ml64') | Where-Object {
        -not (Get-Command $_ -ErrorAction SilentlyContinue)
    }
    if ($missing) {
        throw "Missing tools: $($missing -join ', '). Use an x64 MSVC developer shell with CMake and Ninja installed."
    }
    if ($env:VSCMD_ARG_TGT_ARCH -and $env:VSCMD_ARG_TGT_ARCH -ne 'x64') {
        throw 'Use the x64 developer shell, not an x86/ARM64 target.'
    }
    $lock = Get-Content (Join-Path $PSScriptRoot 'dependencies.json') -Raw | ConvertFrom-Json
    $deps = Join-Path $repo 'deps'
    New-Item -ItemType Directory -Force $deps | Out-Null
    foreach ($name in @('Streamline', 'reshade')) {
        $spec = $lock.$name
        $path = Join-Path $deps $name
        if (-not (Test-Path -LiteralPath $path)) {
            Invoke-Checked git @('clone', '--depth', '1', '--branch', $spec.tag, $spec.url, $path)
        }
        # Trust only this intended dependency for this command; do not modify global Git config.
        $gitArgs = @('-c', "safe.directory=$($path.Replace('\','/'))", '-C', $path)
        $head = & git @gitArgs rev-parse HEAD
        if ($LASTEXITCODE -ne 0 -or $head -ne $spec.commit) {
            throw "$name must be at $($spec.commit). Existing dependency was left untouched."
        }
        $dirty = & git @gitArgs status --porcelain --untracked-files=no
        if ($LASTEXITCODE -ne 0 -or $dirty) {
            throw "$name has modified tracked files; refusing an unreproducible build."
        }
    }
    $reshade = Join-Path $deps 'reshade'
    Invoke-Checked git @('-c', "safe.directory=$($reshade.Replace('\','/'))", '-C', $reshade,
        'submodule', 'update', '--init', '--depth', '1', '--', 'deps/imgui')
    $imgui = Join-Path $reshade 'deps/imgui'
    $imguiHead = & git -c "safe.directory=$($imgui.Replace('\','/'))" -C $imgui rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $imguiHead -ne $lock.reshade.imguiCommit) {
        throw 'ReShade ImGui ABI revision does not match the dependency lock.'
    }
    $imguiDirty = & git -c "safe.directory=$($imgui.Replace('\','/'))" -C $imgui status --porcelain --untracked-files=no
    if ($LASTEXITCODE -ne 0 -or $imguiDirty) { throw 'ReShade ImGui has modified tracked files.' }

    # A separate directory avoids reusing an old MinGW or x86 CMake cache.
    $build = Join-Path $repo 'build/msvc-x64'
    Invoke-Checked cmake @('-S', (Join-Path $repo 'source/native'), '-B', $build, '-G', 'Ninja',
        '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_C_COMPILER=cl', '-DCMAKE_CXX_COMPILER=cl',
        "-DSTREAMLINE_ROOT=$(Join-Path $deps 'Streamline')", "-DRESHADE_ROOT=$reshade",
        "-DIMGUI_ROOT=$imgui", '-DMFG_UNLOCK_BUILD_UNIVERSAL_UI=ON', '-DBUILD_TESTING=ON')
    Invoke-Checked cmake @('--build', $build, '--config', 'Release')
    Invoke-Checked ctest @('--test-dir', $build, '-C', 'Release', '--output-on-failure', '--no-tests=error')

    # Validate every output before publishing a fresh package directory.
    $artifacts = @('RTX40MFGCore.dll', 'RTX40MFG.asi', 'RTX40MFG-UI.addon64')
    foreach ($name in $artifacts) {
        $file = Get-Item -LiteralPath (Join-Path $build $name)
        if ($file.Length -eq 0) { throw "Empty artifact: $name" }
    }
    $package = Join-Path $repo ('dist/package-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $package | Out-Null
    foreach ($name in $artifacts) { Copy-Item -LiteralPath (Join-Path $build $name) -Destination $package }
    foreach ($name in @('README.md', 'TUTORIAL_RTX3000.md', 'AUDIT.md', 'LICENSE')) { Copy-Item -LiteralPath (Join-Path $repo $name) -Destination $package }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'dependencies.json') -Destination $package
    $notices = Join-Path $package 'licenses'
    New-Item -ItemType Directory -Path $notices | Out-Null
    $licenses = @{
        'MinHook.txt' = (Join-Path $repo 'source/native/third_party/minhook/LICENSE.txt')
        'nlohmann-json.txt' = (Join-Path $deps 'Streamline/external/json/LICENSE.MIT')
        'Streamline.txt' = (Join-Path $deps 'Streamline/license.txt')
        'ReShade.md' = (Join-Path $reshade 'LICENSE.md')
        'ImGui.txt' = (Join-Path $imgui 'LICENSE.txt')
    }
    foreach ($name in $licenses.Keys) {
        Copy-Item -LiteralPath $licenses[$name] -Destination (Join-Path $notices $name)
    }
    $ini = Join-Path $repo 'bin/x64/global.ini'
    if (Test-Path -LiteralPath $ini) { Copy-Item -LiteralPath $ini -Destination $package }
    $hashes = foreach ($name in $artifacts) {
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $package $name)
        "$($hash.Hash)  $name"
    }
    $hashes | Set-Content -LiteralPath (Join-Path $package 'SHA256SUMS.txt') -Encoding ASCII
    if ($env:GITHUB_OUTPUT) { "package=$package" | Add-Content -LiteralPath $env:GITHUB_OUTPUT }
    Write-Host "Build and tests passed. New package: $package"
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
