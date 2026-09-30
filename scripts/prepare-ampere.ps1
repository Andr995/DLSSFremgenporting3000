[CmdletBinding()]
param([string]$CacheDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ampere-backend.lock.json') -Raw | ConvertFrom-Json
if (-not $CacheDirectory) { $CacheDirectory = Join-Path $repo 'deps/dlssg-sm86-review' }
New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
foreach ($file in $lock.files) {
    $path = Join-Path $CacheDirectory $file.name
    if (-not (Test-Path -LiteralPath $path)) {
        $url = 'https://raw.githubusercontent.com/sdli1995/dlssg_for_sm86/' + $lock.commit + '/' + $file.name
        Invoke-WebRequest -Uri $url -OutFile $path
    }
    if ((Get-Item -LiteralPath $path).Length -ne $file.bytes -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) {
        throw "Backend integrity mismatch: $path. Existing file left untouched."
    }
}
$package = Join-Path $repo ('dist/nvidia-ampere-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $package | Out-Null
foreach ($file in $lock.files) { Copy-Item -LiteralPath (Join-Path $CacheDirectory $file.name) -Destination $package }
# Stock numerical path for the first in-game validation. The GPU kernel
# substitutions needed for Ampere remain enabled even at Optimized=0.
@'
; NVIDIA DLSS-G on Ampere; pinned external backend, not the local Ada patch.
[General]
Enabled=1
[FrameGeneration]
Optimized=0
MaxGeneratedFrames=3
[Compatibility]
Preset=Auto
[Logging]
Level=3
EvaluateEvery=120
Directory=dlssg_sm86\logs
[Runtime]
Mode=Bundled
CacheDirectory=
'@ | Set-Content -LiteralPath (Join-Path $package 'dlssg_sm86.ini') -Encoding ASCII
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ampere-backend.lock.json') -Destination $package
foreach ($document in @('README.md', 'TUTORIAL_RTX3000.md', 'VALIDAZIONE_CYBERPUNK.md',
                        'BACKEND_PROVENANCE.md', 'ADA_RESEARCH.md', 'AUDIT.md', 'CHANGELOG.md', 'LICENSE')) {
    Copy-Item -LiteralPath (Join-Path $repo $document) -Destination $package
}
$packageScripts = Join-Path $package 'scripts'
New-Item -ItemType Directory -Path $packageScripts | Out-Null
foreach ($script in @('install-ampere.ps1', 'restore-ampere.ps1', 'AmpereDeployment.psm1',
                     'ampere-backend.lock.json', 'diagnose-ampere.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $script) -Destination $packageScripts
}
$packageEvidence = Join-Path $package 'evidence'
New-Item -ItemType Directory -Path $packageEvidence | Out-Null
foreach ($report in @('cyberpunk-benchmarks.json', 'cyberpunk-backend-summary.json', 'cyberpunk-cet-asi-validation.json')) {
    Copy-Item -LiteralPath (Join-Path $repo ('evidence/' + $report)) -Destination $packageEvidence
}
$files = foreach ($name in @('version.dll', 'dlssg_sm86.ini', 'THIRD_PARTY_NOTICES.txt')) {
    [PSCustomObject]@{ name = $name; sha256 = (Get-FileHash -LiteralPath (Join-Path $package $name)).Hash }
}
[PSCustomObject]@{
    schema = 1; backend = $lock.name; version = $lock.version; commit = $lock.commit
    integrationVersion = '0.3.5-cp2077.2'
    runtime = 'NVIDIA DLSS-G 310.9.1'; configuration = 'stock numerics; maximum 4x; diagnostic logging'
    validation = 'package integrity only; game execution must be verified separately'
    files = @($files)
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $package 'package.json') -Encoding UTF8
Write-Output $package
