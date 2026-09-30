[CmdletBinding()]
param([Parameter(Mandatory)][string]$GameExecutable, [string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AmpereDeployment.psm1') -Force
$exe = (Resolve-Path -LiteralPath $GameExecutable).ProviderPath
if ([IO.Path]::GetFileName($exe) -ine 'Cyberpunk2077.exe') { throw 'Select Cyberpunk2077.exe in bin/x64.' }
$directory = Split-Path $exe -Parent
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ampere-backend.lock.json') -Raw | ConvertFrom-Json
$loader = Get-AmpereLoaderState -Directory $directory
$issues = [Collections.Generic.List[string]]::new()
$files = @(foreach ($name in @('version.dll','dlssg_sm86.ini','plugins/dlssg_sm86.asi','plugins/dlssg_sm86.ini',
    'plugins/cyber_engine_tweaks.asi','nvngx.dll','dlssg_to_fsr3_amd_is_better.dll','sl.dlss_g.dll')) {
    $path = Join-Path $directory $name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $item = Get-Item -LiteralPath $path
        $hash = (Get-FileHash -LiteralPath $path).Hash
        [PSCustomObject]@{ path=$name; bytes=$item.Length; sha256=$hash; pinnedBackend=($hash -eq $lock.files[0].sha256) }
    }
})
$backends = @($files | Where-Object pinnedBackend)
if ($backends.Count -eq 0) { $issues.Add('No pinned backend found in the supported locations. Reinstall the correct package variant.') }
if ($backends.Count -gt 1) { $issues.Add('Duplicate backend: retain only the ASI or standalone route. Do not remove the CET loader.') }
if ($loader.cetPluginPresent -and $loader.rootIsBackend) {
    $issues.Add('CET plugin exists but version.dll is the FG backend. Restore CET original version.dll and move FG to plugins/dlssg_sm86.asi with its INI.')
}
if (@($files | Where-Object path -eq 'plugins/dlssg_sm86.asi').Count -gt 0 -and -not $loader.asiLoaderAvailable) {
    $issues.Add('ASI backend present without a recognized ASI loader. Install/repair CET, including its root version.dll.')
}
foreach ($backend in $backends) {
    $iniName = if ($backend.path -eq 'version.dll') { 'dlssg_sm86.ini' } else { 'plugins/dlssg_sm86.ini' }
    if (-not (Test-Path -LiteralPath (Join-Path $directory $iniName) -PathType Leaf)) { $issues.Add("Missing configuration beside backend: $iniName") }
}
if (@($files | Where-Object { $_.path -in @('nvngx.dll','dlssg_to_fsr3_amd_is_better.dll') }).Count) {
    $issues.Add('An NGX/FSR bridge is present. Back up and disable competing frame-generation mods before testing.')
}
if (Test-Path -LiteralPath (Join-Path $directory 'plugins/cyber_engine_tweaks/dlssg_sm86.asi')) {
    $issues.Add('FG is inside the CET subfolder. Place the ASI and INI directly in bin/x64/plugins.')
}
$hags = 'Unknown'
try {
    $value = Get-ItemPropertyValue -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name HwSchMode -ErrorAction Stop
    if ($value -eq 2) { $hags='ConfiguredOn' } elseif ($value -eq 1) { $hags='ConfiguredOff' }
} catch { } # Unset is driver/OS default, not proof that HAGS is disabled.
if ($hags -ne 'ConfiguredOn') { $issues.Add('Check Hardware-accelerated GPU scheduling in Windows Settings > System > Display > Graphics. Enable it if available, then restart Windows.') }
$gpus = @()
try { $gpus = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion) }
catch { $issues.Add('GPU/driver information unavailable. Include GPU model and NVIDIA driver version manually.') }
# Inspect only current-layout locations, never old root logs as proof of an ASI test.
$logFolders = @(foreach ($backend in $backends) {
    if ($backend.path -eq 'version.dll') { 'dlssg_sm86/logs' } else { 'plugins/dlssg_sm86/logs' }
})
$logs = @(foreach ($folder in $logFolders) {
    $path = Join-Path $directory $folder
    if (Test-Path -LiteralPath $path -PathType Container) {
        $latest = Get-ChildItem -LiteralPath $path -Filter 'backend_*.jsonl' -File |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if ($latest) {
            $rows = [Collections.Generic.List[object]]::new()
            $invalid=0
            foreach ($line in (Get-Content -LiteralPath $latest.FullName -Tail 400)) {
                try { $rows.Add(($line | ConvertFrom-Json -ErrorAction Stop)) } catch { $invalid++ }
            }
            $evaluations = @($rows | Where-Object { $_.PSObject.Properties['event'] -and $_.event -eq 'evaluate' })
            $failed = @($evaluations | Where-Object {
                -not $_.PSObject.Properties['status'] -or $_.status -ne 1 -or
                ($_.PSObject.Properties['failed_launches_total'] -and $_.failed_launches_total -gt 0)
            })
            $sm = @($evaluations | Where-Object { $_.PSObject.Properties['actual_sm'] } | ForEach-Object actual_sm | Sort-Object -Unique)
            $frames = @($evaluations | Where-Object { $_.PSObject.Properties['multi_frame_count'] } | ForEach-Object multi_frame_count | Sort-Object -Unique)
            if ($evaluations.Count -eq 0) {
                $issues.Add("No evaluation samples recorded in $folder/$($latest.Name). Exit the game normally to flush logs, then check the matching session; loading alone is not proof of FG execution.")
            }
            if ($failed.Count -gt 0) { $issues.Add("Failed evaluation/launch samples in $folder/$($latest.Name). Include this session when reporting the problem.") }
            [PSCustomObject]@{
                path="$folder/$($latest.Name)"; modifiedUtc=$latest.LastWriteTimeUtc.ToString('o')
                scope='Last 400 lines of latest log; may be a past session. Match the PID and time of your test.'
                evaluationSamples=$evaluations.Count; failedSamples=$failed.Count
                actualSM=$sm; generatedFramesPerSample=$frames; invalidLines=$invalid
            }
        }
    }
})
if ($logs.Count -eq 0) { $issues.Add('No backend logs found for the installed route. Check ASI loading, adjacent INI and custom Logging.Directory settings.') }
$report = [PSCustomObject]@{
    schema=1; integrationVersion='0.3.5-cp2077.2'; collectedUtc=[DateTime]::UtcNow.ToString('o')
    gameVersion=(Get-Item -LiteralPath $exe).VersionInfo.FileVersion
    gpu=$gpus; hags=$hags
    hagsNote='Registry configuration only. Effective state may require a reboot; unset is Unknown.'
    loader=$loader; files=$files; logs=$logs; findings=@($issues)
    limitations='Read-only preflight, not a compatibility certificate. A menu toggle or FPS counter alone does not prove generated-frame execution. RTX 3070m case remains unverified.'
}
$json=$report | ConvertTo-Json -Depth 8
if ($OutputPath) {
    if (Test-Path -LiteralPath $OutputPath) { throw 'OutputPath already exists; choose a new report name.' }
    $stream=[IO.File]::Open([IO.Path]::GetFullPath($OutputPath),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
    try { $bytes=[Text.UTF8Encoding]::new($false).GetBytes($json); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}
Write-Output $json
