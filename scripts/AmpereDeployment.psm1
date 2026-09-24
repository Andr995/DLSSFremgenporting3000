Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileDigest([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-ClosedGame([string]$Executable) {
    $processName = [IO.Path]::GetFileNameWithoutExtension($Executable)
    if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
        throw "Close $processName before changing its files."
    }
}

function Install-AmperePackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Package,
          [Parameter(Mandatory)][string]$GameExecutable)
    $executable = (Resolve-Path -LiteralPath $GameExecutable).ProviderPath
    if ([IO.Path]::GetFileName($executable) -ine 'Cyberpunk2077.exe') {
        throw 'This deployment handles Cyberpunk2077.exe only.'
    }
    Assert-ClosedGame $executable
    $directory = [IO.Path]::GetDirectoryName($executable)
    $packageRoot = (Resolve-Path -LiteralPath $Package).ProviderPath
    $manifest = Get-Content -LiteralPath (Join-Path $packageRoot 'package.json') -Raw | ConvertFrom-Json
    $lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ampere-backend.lock.json') -Raw | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.commit -ne $lock.commit) { throw 'Unknown package revision.' }
    $installNames = @('version.dll', 'dlssg_sm86.ini')
    $newFiles = foreach ($name in $installNames) {
        $entries = @($manifest.files | Where-Object name -CEQ $name)
        if ($entries.Count -ne 1) { throw "Missing or duplicate package entry: $name" }
        $source = Join-Path $packageRoot $name
        $hash = Get-FileDigest $source
        if ($hash -ne $entries[0].sha256) { throw "Package hash mismatch: $name" }
        if ($name -eq 'version.dll' -and $hash -ne $lock.files[0].sha256) { throw 'Unrecognized backend DLL.' }
        [PSCustomObject]@{ name = $name; sha256 = $hash }
    }
    # These exact, previously identified mods compete for the same NGX route.
    # Preserve the game's NVIDIA/AMD/Intel runtimes and ReShade itself.
    $replaceNames = @('version.dll', 'dlssg_sm86.ini', 'nvngx.dll',
        'dlssg_to_fsr3_amd_is_better.dll', 'RTX40MFG.asi', 'RTX40MFGCore.dll', 'RTX40MFG-UI.addon64')
    $backup = Join-Path $directory ('.rtx30fg-backup-' + [Guid]::NewGuid().ToString('N'))
    $originals = foreach ($name in $replaceNames) {
        $path = Join-Path $directory $name
        if (Test-Path -LiteralPath $path) {
            if ((Get-Item -LiteralPath $path).PSIsContainer) { throw "Expected a file: $path" }
            [PSCustomObject]@{ name = $name; sha256 = Get-FileDigest $path }
        }
    }
    New-Item -ItemType Directory -Path $backup | Out-Null
    [PSCustomObject]@{
        schema = 1; gameExecutable = $executable; createdUtc = [DateTime]::UtcNow.ToString('o')
        backendCommit = $lock.commit; originals = @($originals); installed = @($newFiles)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backup 'restore.json') -Encoding UTF8
    $moved = [Collections.Generic.List[string]]::new()
    $deployed = [Collections.Generic.List[string]]::new()
    $staged = [Collections.Generic.List[string]]::new()
    try {
        # Stage and verify before moving any existing file. File.Copy/Move
        # never overwrite a destination that appeared concurrently.
        foreach ($file in $newFiles) {
            $pending = Join-Path $backup ($file.name + '.pending')
            $staged.Add($pending)
            [IO.File]::Copy((Join-Path $packageRoot $file.name), $pending, $false)
            if ((Get-FileDigest $pending) -ne $file.sha256) { throw 'Staged file verification failed.' }
        }
        Assert-ClosedGame $executable
        foreach ($file in $originals) {
            $path = Join-Path $directory $file.name
            if ((Get-FileDigest $path) -ne $file.sha256) { throw "File changed during installation: $path" }
            [IO.File]::Move($path, (Join-Path $backup $file.name))
            $moved.Add($file.name)
        }
        foreach ($file in $newFiles) {
            [IO.File]::Move((Join-Path $backup ($file.name + '.pending')), (Join-Path $directory $file.name))
            $deployed.Add($file.name)
        }
    } catch {
        $failure = $_
        foreach ($name in $deployed) {
            $path = Join-Path $directory $name
            $expected = ($newFiles | Where-Object name -CEQ $name).sha256
            if ((Get-FileDigest $path) -eq $expected) { [IO.File]::Delete($path) }
        }
        foreach ($name in $moved) { [IO.File]::Move((Join-Path $backup $name), (Join-Path $directory $name)) }
        foreach ($path in $staged) { if (Test-Path -LiteralPath $path) { [IO.File]::Delete($path) } }
        throw $failure
    }
    return (Join-Path $backup 'restore.json')
}

function Restore-AmperePackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Manifest)
    $manifestPath = (Resolve-Path -LiteralPath $Manifest).ProviderPath
    $state = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $backup = [IO.Path]::GetDirectoryName($manifestPath)
    $directory = [IO.Path]::GetDirectoryName($backup)
    if ($state.schema -ne 1 -or [IO.Path]::GetFileName($backup) -notmatch '^\.rtx30fg-backup-[0-9a-f]{32}$' -or
        [IO.Path]::GetFullPath($state.gameExecutable) -ine (Join-Path $directory 'Cyberpunk2077.exe')) {
        throw 'Invalid restore manifest location or game path.'
    }
    Assert-ClosedGame $state.gameExecutable
    $allowed = @('version.dll','dlssg_sm86.ini','nvngx.dll','dlssg_to_fsr3_amd_is_better.dll',
        'RTX40MFG.asi','RTX40MFGCore.dll','RTX40MFG-UI.addon64')
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $state.originals) {
        if ($file.name -cnotin $allowed -or -not $seen.Add($file.name)) { throw 'Invalid original file entry.' }
        if ((Get-FileDigest (Join-Path $backup $file.name)) -ne $file.sha256) { throw 'Backup integrity mismatch.' }
        if ($file.name -notin @($state.installed.name) -and (Test-Path -LiteralPath (Join-Path $directory $file.name))) {
            throw "Restore would overwrite a new file: $($file.name)"
        }
    }
    $seen.Clear()
    foreach ($file in $state.installed) {
        if ($file.name -cnotin @('version.dll','dlssg_sm86.ini') -or -not $seen.Add($file.name)) { throw 'Invalid installed file entry.' }
        if ((Get-FileDigest (Join-Path $directory $file.name)) -ne $file.sha256) {
            throw "Installed file changed: $($file.name). Preserve it before restoring."
        }
    }
    # Validate the entire manifest before the first mutation. Keep the new
    # files in the backup too, so rollback never destroys either version.
    foreach ($file in $state.installed) {
        if (Test-Path -LiteralPath (Join-Path $backup ($file.name + '.installed'))) { throw 'Already restored or occupied backup.' }
    }
    foreach ($file in $state.installed) {
        [IO.File]::Move((Join-Path $directory $file.name), (Join-Path $backup ($file.name + '.installed')))
    }
    foreach ($file in $state.originals) { [IO.File]::Move((Join-Path $backup $file.name), (Join-Path $directory $file.name)) }
}

Export-ModuleMember -Function Install-AmperePackage,Restore-AmperePackage
