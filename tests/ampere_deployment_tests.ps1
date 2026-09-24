[CmdletBinding()]
param([Parameter(Mandatory)][string]$Package)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../scripts/AmpereDeployment.psm1') -Force
function Check([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function MustFail([scriptblock]$Action) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Check $failed 'Expected operation to fail.'
}
$root = Join-Path $PSScriptRoot ('../build-tests/deployment-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$root = (Resolve-Path -LiteralPath $root).ProviderPath
$exe = Join-Path $root 'Cyberpunk2077.exe'
'fixture only, never executed' | Set-Content -LiteralPath $exe
$originalNames = @('version.dll','nvngx.dll','dlssg_to_fsr3_amd_is_better.dll',
    'RTX40MFG.asi','RTX40MFGCore.dll','RTX40MFG-UI.addon64','dlssg_sm86.ini','dxgi.dll','nvngx_dlssg.dll')
$originalHashes = @{}
foreach ($name in $originalNames) {
    $path = Join-Path $root $name
    "original fixture for $name" | Set-Content -LiteralPath $path
    $originalHashes[$name] = (Get-FileHash -LiteralPath $path).Hash
}
$manifest = Install-AmperePackage -Package $Package -GameExecutable $exe
Check (-not (Test-Path -LiteralPath (Join-Path $root 'nvngx.dll'))) 'FSR bridge was not disabled.'
Check (-not (Test-Path -LiteralPath (Join-Path $root 'RTX40MFG.asi'))) 'Old core loader was not disabled.'
foreach ($name in @('dxgi.dll','nvngx_dlssg.dll')) {
    Check ((Get-FileHash -LiteralPath (Join-Path $root $name)).Hash -eq $originalHashes[$name]) 'Unrelated file changed.'
}
$configPath = Join-Path $root 'dlssg_sm86.ini'
$installedConfig = [IO.File]::ReadAllBytes($configPath)
'user changed config' | Add-Content -LiteralPath $configPath
MustFail { Restore-AmperePackage -Manifest $manifest }
Check (-not (Test-Path -LiteralPath (Join-Path $root 'nvngx.dll'))) 'Partial restore on modified config.'
[IO.File]::WriteAllBytes($configPath, $installedConfig)
$stateBytes = [IO.File]::ReadAllBytes($manifest)
$state = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
$state.originals[0].name = '../escape.dll'
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifest
MustFail { Restore-AmperePackage -Manifest $manifest }
[IO.File]::WriteAllBytes($manifest, $stateBytes)
Restore-AmperePackage -Manifest $manifest
foreach ($name in $originalNames) {
    Check ((Get-FileHash -LiteralPath (Join-Path $root $name)).Hash -eq $originalHashes[$name]) "Restore mismatch: $name"
}
MustFail { Restore-AmperePackage -Manifest $manifest }
# Corrupt package is rejected before making any additional backup or mutation.
$bad = Join-Path $root 'bad-package'
New-Item -ItemType Directory -Path $bad | Out-Null
Copy-Item -LiteralPath (Join-Path $Package 'package.json') -Destination $bad
'not the pinned DLL' | Set-Content -LiteralPath (Join-Path $bad 'version.dll')
$backupCount = @(Get-ChildItem -LiteralPath $root -Directory -Filter '.rtx30fg-backup-*').Count
MustFail { Install-AmperePackage -Package $bad -GameExecutable $exe }
Check (@(Get-ChildItem -LiteralPath $root -Directory -Filter '.rtx30fg-backup-*').Count -eq $backupCount) 'Bad package mutated game.'
Write-Output 'Deployment tests passed: backup, isolation, tamper rejection, path validation and exact restore.'
Write-Output "Test artifacts retained: $root"
