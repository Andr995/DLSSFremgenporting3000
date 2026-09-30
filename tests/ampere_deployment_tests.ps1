[CmdletBinding()]
param([Parameter(Mandatory)][string]$Package)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../scripts/AmpereDeployment.psm1') -Force
function Check([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function MustFail([scriptblock]$Action) {
    $failed=$false
    try { & $Action | Out-Null } catch { $failed=$true }
    Check $failed 'Expected operation to fail.'
}
$root=Join-Path $PSScriptRoot ('../build-tests/deployment-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$root=(Resolve-Path -LiteralPath $root).ProviderPath
function Fixture([string]$Name) {
    $directory=Join-Path $root $Name
    New-Item -ItemType Directory -Path $directory | Out-Null
    'fixture only, never executed' | Set-Content -LiteralPath (Join-Path $directory 'Cyberpunk2077.exe')
    return $directory
}
function Put([string]$Directory,[string]$Name,[string]$Text) {
    $path=Join-Path $Directory $Name
    [IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
    [IO.File]::WriteAllText($path,$Text)
}
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path).Hash }
$cet=Fixture 'cet'
$originals=@('version.dll','plugins/cyber_engine_tweaks.asi','plugins/cyber_engine_tweaks/config.json',
    'dxgi.dll','nvngx_dlssg.dll','nvngx.dll','dlssg_to_fsr3_amd_is_better.dll',
    'RTX40MFG.asi','RTX40MFGCore.dll','RTX40MFG-UI.addon64','dlssg_sm86.ini')
$hashes=@{}
foreach ($name in $originals) { Put $cet $name "original $name"; $hashes[$name]=Hash (Join-Path $cet $name) }
$exe=Join-Path $cet 'Cyberpunk2077.exe'
$manifest=Install-AmperePackage -Package $Package -GameExecutable $exe
Check ((Get-Content $manifest -Raw | ConvertFrom-Json).mode -eq 'ASI') 'Auto did not select ASI for CET.'
foreach ($name in @('version.dll','plugins/cyber_engine_tweaks.asi','plugins/cyber_engine_tweaks/config.json','dxgi.dll','nvngx_dlssg.dll')) {
    Check ((Hash (Join-Path $cet $name)) -eq $hashes[$name]) "CET/unrelated file changed: $name"
}
Check (-not (Test-Path (Join-Path $cet 'nvngx.dll'))) 'Competing bridge left active.'
Check ((Hash (Join-Path $cet 'plugins/dlssg_sm86.asi')) -eq (Hash (Join-Path $Package 'version.dll'))) 'ASI binary changed.'
$configPath=Join-Path $cet 'plugins/dlssg_sm86.ini'
$ini=[IO.File]::ReadAllBytes($configPath)
Add-Content -LiteralPath $configPath -Value 'user change'
MustFail { Restore-AmperePackage -Manifest $manifest }
Check (-not (Test-Path (Join-Path $cet 'nvngx.dll'))) 'Partial restore after integrity failure.'
[IO.File]::WriteAllBytes($configPath,$ini)
$manifestBytes=[IO.File]::ReadAllBytes($manifest)
$state=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
$state.originals[0].name='../escape.dll'
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifest
MustFail { Restore-AmperePackage -Manifest $manifest }
[IO.File]::WriteAllBytes($manifest,$manifestBytes)
Put $cet 'nvngx.dll' 'new user file'
MustFail { Restore-AmperePackage -Manifest $manifest }
[IO.File]::Delete((Join-Path $cet 'nvngx.dll'))
Restore-AmperePackage -Manifest $manifest
foreach ($name in $originals) { Check ((Hash (Join-Path $cet $name)) -eq $hashes[$name]) "Restore mismatch: $name" }
Check (-not (Test-Path (Join-Path $cet 'plugins/dlssg_sm86.asi'))) 'ASI left active after restore.'
MustFail { Restore-AmperePackage -Manifest $manifest }
MustFail { Install-AmperePackage -Package $Package -GameExecutable $exe -Mode Standalone }
$unknown=Fixture 'unknown'
Put $unknown 'version.dll' 'unknown proxy'
$before=Hash (Join-Path $unknown 'version.dll')
MustFail { Install-AmperePackage -Package $Package -GameExecutable (Join-Path $unknown 'Cyberpunk2077.exe') }
Check ((Hash (Join-Path $unknown 'version.dll')) -eq $before) 'Unknown proxy overwritten.'
Check (@(Get-ChildItem $unknown -Directory -Filter '.rtx30fg-backup-*').Count -eq 0) 'Conflict caused mutation.'
$clean=Fixture 'clean'
$cleanExe=Join-Path $clean 'Cyberpunk2077.exe'
MustFail { Install-AmperePackage -Package $Package -GameExecutable $cleanExe -Mode ASI }
$standalone=Install-AmperePackage -Package $Package -GameExecutable $cleanExe
$state=Get-Content -LiteralPath $standalone -Raw | ConvertFrom-Json
Check ($state.mode -eq 'Standalone') 'Clean install mode incorrect.'
$state.schema=1
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $standalone
Restore-AmperePackage -Manifest $standalone
Check (-not (Test-Path (Join-Path $clean 'version.dll'))) 'Legacy restore failed.'
$damaged=Fixture 'damaged-cet'
Copy-Item -LiteralPath (Join-Path $Package 'version.dll') -Destination $damaged
Put $damaged 'plugins/cyber_engine_tweaks.asi' 'CET plugin'
MustFail { Install-AmperePackage -Package $Package -GameExecutable (Join-Path $damaged 'Cyberpunk2077.exe') }
Check ((Hash (Join-Path $damaged 'version.dll')) -eq (Hash (Join-Path $Package 'version.dll'))) 'Damaged-CET preflight changed files.'
Copy-Item -LiteralPath (Join-Path $Package 'version.dll') -Destination (Join-Path $cet 'plugins/dlssg_sm86.asi')
Put $cet 'plugins/dlssg_sm86.ini' 'user custom config'
$upgrade=Install-AmperePackage -Package $Package -GameExecutable $exe
Restore-AmperePackage -Manifest $upgrade
Check ([IO.File]::ReadAllText((Join-Path $cet 'plugins/dlssg_sm86.ini')) -eq 'user custom config') 'Upgrade lost previous settings.'
# Sharing violations after some moves must roll the transaction back without data loss.
$beforeFailure=@{}
foreach ($name in ($originals + @('plugins/dlssg_sm86.asi','plugins/dlssg_sm86.ini'))) { $beforeFailure[$name]=Hash (Join-Path $cet $name) }
$locked=[IO.File]::Open((Join-Path $cet 'dlssg_to_fsr3_amd_is_better.dll'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try { MustFail { Install-AmperePackage -Package $Package -GameExecutable $exe } } finally { $locked.Dispose() }
foreach ($name in $beforeFailure.Keys) { Check ((Hash (Join-Path $cet $name)) -eq $beforeFailure[$name]) "Install rollback lost: $name" }
$restoreFailure=Install-AmperePackage -Package $Package -GameExecutable $exe
$locked=[IO.File]::Open((Join-Path (Split-Path $restoreFailure -Parent) 'nvngx.dll'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try { MustFail { Restore-AmperePackage -Manifest $restoreFailure } } finally { $locked.Dispose() }
Check (-not (Test-Path (Join-Path $cet 'dlssg_sm86.ini'))) 'Restore rollback left an original active.'
Check ((Hash (Join-Path $cet 'plugins/dlssg_sm86.ini')) -eq (Hash (Join-Path $Package 'dlssg_sm86.ini'))) 'Restore rollback lost installed INI.'
Restore-AmperePackage -Manifest $restoreFailure
foreach ($name in $beforeFailure.Keys) { Check ((Hash (Join-Path $cet $name)) -eq $beforeFailure[$name]) "Final restore lost: $name" }
Copy-Item -LiteralPath (Join-Path $Package 'version.dll') -Destination (Join-Path $damaged 'plugins/dlssg_sm86.asi')
Put $damaged 'plugins/dlssg_sm86/logs/backend_123.jsonl' ('{"event":"evaluate","status":0,"actual_sm":86,"failed_launches_total":1,"multi_frame_count":3}' + [Environment]::NewLine + 'invalid')
$diagnostic=& (Join-Path $PSScriptRoot '../scripts/diagnose-ampere.ps1') -GameExecutable (Join-Path $damaged 'Cyberpunk2077.exe') | ConvertFrom-Json
Check (@($diagnostic.findings | Where-Object { $_ -like 'Duplicate backend:*' }).Count -eq 1) 'Duplicate not diagnosed.'
Check ($diagnostic.logs[0].failedSamples -eq 1 -and $diagnostic.logs[0].invalidLines -eq 1) 'Failed/truncated logs misreported.'
$bad=Join-Path $root 'bad-package'
New-Item -ItemType Directory -Path $bad | Out-Null
Copy-Item -LiteralPath (Join-Path $Package 'package.json') -Destination $bad
Put $bad 'version.dll' 'corrupted'
$backupCount=@(Get-ChildItem $clean -Directory -Filter '.rtx30fg-backup-*').Count
MustFail { Install-AmperePackage -Package $bad -GameExecutable $cleanExe }
Check (@(Get-ChildItem $clean -Directory -Filter '.rtx30fg-backup-*').Count -eq $backupCount) 'Bad package mutated game.'
$linkGame=Fixture 'linked-plugins'
$out=Fixture 'outside-target'
New-Item -ItemType Junction -Path (Join-Path $linkGame 'plugins') -Target $out | Out-Null
MustFail { Install-AmperePackage -Package $Package -GameExecutable (Join-Path $linkGame 'Cyberpunk2077.exe') }
Check (@(Get-ChildItem $out -File).Count -eq 1) 'Installer wrote through junction.'
Write-Output 'PASS: CET preservation, standalone, ASI upgrade, exact restore, legacy schema, conflicts, tamper/path rejection, diagnostics, corrupt package, junction guard.'
Write-Output "Test artifacts retained: $root"
