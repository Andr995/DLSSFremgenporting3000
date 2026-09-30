[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [ValidateSet('CET-ASI', 'Standalone')][string]$Variant = 'CET-ASI',
    [string]$OutputDirectory,
    [string]$RarPath = 'C:/Program Files/WinRAR/Rar.exe',
    [string]$SevenZipPath = 'C:/Program Files/7-Zip/7z.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$source = (Resolve-Path -LiteralPath $Package).ProviderPath
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repo "dist/nexus-cp2077.2/$Variant" }
foreach ($tool in @($RarPath, $SevenZipPath)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing archiver: $tool" }
}

# Accept only the already prepared, pinned upstream binary and validated INI.
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ampere-backend.lock.json') -Raw | ConvertFrom-Json
$packageInfo = Get-Content -LiteralPath (Join-Path $source 'package.json') -Raw | ConvertFrom-Json
if ($packageInfo.commit -ne $lock.commit -or $packageInfo.version -ne $lock.version) {
    throw 'Prepared package does not match the pinned backend.'
}
foreach ($file in $lock.files) {
    $filePath = Join-Path $source $file.name
    if ((Get-Item -LiteralPath $filePath).Length -ne $file.bytes -or
        (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash -ne $file.sha256) {
        throw "Pinned file integrity mismatch: $($file.name)"
    }
}
$iniRecords = @($packageInfo.files | Where-Object { $_.name -eq 'dlssg_sm86.ini' })
if ($iniRecords.Count -ne 1 -or
    (Get-FileHash -LiteralPath (Join-Path $source 'dlssg_sm86.ini')).Hash -ne $iniRecords[0].sha256) {
    throw 'Prepared configuration integrity mismatch.'
}

$name = "Cyberpunk2077-NVIDIA-FG-RTX3000-0.3.5-cp2077.2-$Variant"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$output = (Resolve-Path -LiteralPath $OutputDirectory).ProviderPath
foreach ($filename in @("$name.rar", "$name.zip", "$name.rar.sha256", "$name.zip.sha256",
                         'NEXUS_DESCRIPTION_EN.txt', 'UPLOAD_NOTES_IT.md', 'verification.json')) {
    if (Test-Path -LiteralPath (Join-Path $output $filename)) {
        throw "Output already exists: $filename. Choose a new OutputDirectory."
    }
}
$runId = [Guid]::NewGuid().ToString('N')
$stage = Join-Path $repo "dist/nexus-stage-$runId"
$verification = Join-Path $repo "build-tests/nexus-verify-$runId"
$docs = Join-Path $stage 'NVIDIA-FG-RTX3000-Docs'
$binaryDir = Join-Path $stage 'bin/x64'
if ($Variant -eq 'CET-ASI') { $binaryDir = Join-Path $binaryDir 'plugins' }
foreach ($directory in @($binaryDir, $docs, (Join-Path $docs 'evidence'), $verification)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$dllName = if ($Variant -eq 'CET-ASI') { 'dlssg_sm86.asi' } else { 'version.dll' }
Copy-Item -LiteralPath (Join-Path $source 'version.dll') -Destination (Join-Path $binaryDir $dllName)
Copy-Item -LiteralPath (Join-Path $source 'dlssg_sm86.ini') -Destination $binaryDir
Copy-Item -LiteralPath (Join-Path $repo 'packaging/nexus/README_NVIDIA_FG_RTX3000.txt') -Destination $stage
foreach ($filename in @('INSTALL_IT.md', 'VALIDATION_EN.md')) {
    Copy-Item -LiteralPath (Join-Path $repo "packaging/nexus/$filename") -Destination $docs
}
Copy-Item -LiteralPath (Join-Path $repo 'BACKEND_PROVENANCE.md') -Destination $docs
Copy-Item -LiteralPath (Join-Path $repo 'CHANGELOG.md') -Destination $docs
$toolDirectory = Join-Path $docs 'tools'
New-Item -ItemType Directory -Path $toolDirectory | Out-Null
foreach ($filename in @('diagnose-ampere.ps1', 'AmpereDeployment.psm1', 'ampere-backend.lock.json')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $filename) -Destination $toolDirectory
}
"Package variant: $Variant. Install only one variant. See README_NVIDIA_FG_RTX3000.txt before extracting into the game." |
    Set-Content -LiteralPath (Join-Path $docs 'VARIANT.txt') -Encoding ASCII
Copy-Item -LiteralPath (Join-Path $source 'THIRD_PARTY_NOTICES.txt') -Destination $docs
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination (Join-Path $docs 'INTEGRATION_LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ampere-backend.lock.json') -Destination $docs
foreach ($filename in @('cyberpunk-benchmarks.json', 'cyberpunk-backend-summary.json', 'cyberpunk-cet-asi-validation.json')) {
    Copy-Item -LiteralPath (Join-Path $repo "evidence/$filename") -Destination (Join-Path $docs 'evidence')
}

function Get-PayloadInventory([string]$Root) {
    foreach ($file in Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object FullName) {
        [PSCustomObject]@{
            path = $file.FullName.Substring($Root.Length + 1).Replace('\', '/')
            bytes = $file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
}
$payload = @(Get-PayloadInventory $stage)
[PSCustomObject]@{
    schema = 1
    version = '0.3.5-cp2077.2'
    variant = $Variant
    installation = 'game root; manual installation documented; Vortex unverified'
    backend = $lock.name
    backendCommit = $lock.commit
    files = $payload
    note = 'Manifest excludes itself. Hashes identify contents, not safety or redistribution rights.'
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $docs 'package-manifest.json') -Encoding UTF8
$expected = @(Get-PayloadInventory $stage)

# Fresh staging contains only explicitly selected files, never other archives.
Push-Location $stage
try {
    & $RarPath a -cfg- -r -m3 -md16m -s- -idq -y (Join-Path $output "$name.rar") bin NVIDIA-FG-RTX3000-Docs README_NVIDIA_FG_RTX3000.txt
    if ($LASTEXITCODE -ne 0) { throw 'RAR creation failed.' }
    & $SevenZipPath a -tzip -mx=6 -mm=Deflate -mmt=2 -bd (Join-Path $output "$name.zip") bin NVIDIA-FG-RTX3000-Docs README_NVIDIA_FG_RTX3000.txt > (Join-Path $verification 'zip-create.log')
    if ($LASTEXITCODE -ne 0) { throw 'ZIP creation failed.' }
} finally { Pop-Location }

& $RarPath t -cfg- -idq (Join-Path $output "$name.rar")
if ($LASTEXITCODE -ne 0) { throw 'Native RAR integrity test failed.' }
$archives = foreach ($extension in @('rar', 'zip')) {
    $archive = Join-Path $output "$name.$extension"
    & $SevenZipPath t -bd $archive > (Join-Path $verification "$extension-test.log")
    if ($LASTEXITCODE -ne 0) { throw "$extension archive test failed." }
    $extract = Join-Path $verification $extension
    & $SevenZipPath x -bd -y "-o$extract" $archive > (Join-Path $verification "$extension-extract.log")
    if ($LASTEXITCODE -ne 0) { throw "$extension extraction failed." }
    $actual = @(Get-PayloadInventory $extract)
    if ($actual.Count -ne $expected.Count) { throw "$extension extracted file count mismatch." }
    foreach ($file in $expected) {
        $match = @($actual | Where-Object { $_.path -ceq $file.path })
        if ($match.Count -ne 1 -or $match[0].bytes -ne $file.bytes -or $match[0].sha256 -ne $file.sha256) {
            throw "$extension extracted content mismatch: $($file.path)"
        }
    }
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    "$hash  $name.$extension" | Set-Content -LiteralPath "$archive.sha256" -Encoding ASCII
    [PSCustomObject]@{
        file = "$name.$extension"
        bytes = (Get-Item -LiteralPath $archive).Length
        sha256 = $hash
        archiveTest = 'passed'
        extractedFiles = $actual.Count
        allExtractedHashesMatch = $true
    }
}
foreach ($filename in @('NEXUS_DESCRIPTION_EN.txt', 'UPLOAD_NOTES_IT.md')) {
    Copy-Item -LiteralPath (Join-Path $repo "packaging/nexus/$filename") -Destination $output
}
[PSCustomObject]@{
    checkedAtUtc = [DateTime]::UtcNow.ToString('o')
    scope = 'Archive integrity and extraction only. Game configuration unchanged; no new benchmark.'
    nativeRarTest = 'passed'
    archives = @($archives)
    files = $expected
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'verification.json') -Encoding UTF8
$archives | Format-Table file, bytes, extractedFiles, allExtractedHashesMatch -AutoSize
Write-Output "Archives and upload notes: $output"
