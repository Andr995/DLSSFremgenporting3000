Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:LegacyNames = @('version.dll','dlssg_sm86.ini','nvngx.dll',
    'dlssg_to_fsr3_amd_is_better.dll','RTX40MFG.asi','RTX40MFGCore.dll','RTX40MFG-UI.addon64')
$script:AsiNames = @('plugins/dlssg_sm86.asi','plugins/dlssg_sm86.ini')

function Get-FileDigest([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-ClosedGame([string]$Executable) {
    $processName = [IO.Path]::GetFileNameWithoutExtension($Executable)
    foreach ($process in @(Get-Process -Name $processName -ErrorAction SilentlyContinue)) {
        $runningPath = $null
        try { $runningPath = $process.Path } catch { }
        # If access is denied, fail closed. A different installation need not block fixtures.
        if (-not $runningPath -or [IO.Path]::GetFullPath($runningPath) -ieq [IO.Path]::GetFullPath($Executable)) {
            throw "Close $processName before changing its files."
        }
    }
}
function Assert-OrdinaryPath([string]$Path) {
    # Reject linked ancestors too: plugins junctions can escape the game directory.
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Linked paths are not supported by this installer: $cursor"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
function Get-SafeFile([string]$Root, [string]$Name) {
    if ($Name -cnotin ($script:LegacyNames + $script:AsiNames)) { throw "Invalid file entry: $Name" }
    $path = Join-Path $Root $Name
    Assert-OrdinaryPath $path
    if (Test-Path -LiteralPath $path -PathType Container) { throw "Expected a file: $path" }
    return $path
}
function Move-PreservedFile([string]$Source, [string]$Destination) {
    Assert-OrdinaryPath $Source
    Assert-OrdinaryPath $Destination
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination)) | Out-Null
    [IO.File]::Move($Source, $Destination) # Never overwrite concurrent or unrelated files.
}
function Get-AmpereLoaderState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Directory)
    $lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ampere-backend.lock.json') -Raw | ConvertFrom-Json
    $rootDll = Join-Path $Directory 'version.dll'
    $hasRoot = Test-Path -LiteralPath $rootDll -PathType Leaf
    $rootIsBackend = $hasRoot -and (Get-FileDigest $rootDll) -eq $lock.files[0].sha256
    $cet = Test-Path -LiteralPath (Join-Path $Directory 'plugins/cyber_engine_tweaks.asi') -PathType Leaf
    $loaders = @(foreach ($name in @('version.dll','dinput8.dll','winmm.dll','dsound.dll','dxgi.dll')) {
        $path = Join-Path $Directory $name
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $info = (Get-Item -LiteralPath $path).VersionInfo
            if (($info.FileDescription + ' ' + $info.ProductName) -match 'Ultimate[ -]ASI[ -]Loader') { $name }
        }
    })
    # Recognize CET's standard layout too. Presence is not proof of runtime loading.
    $cetLayout = $cet -and $hasRoot -and -not $rootIsBackend
    [PSCustomObject]@{
        rootProxyPresent = $hasRoot; rootIsBackend = $rootIsBackend
        cetPluginPresent = $cet; cetLayoutPresent = $cetLayout
        asiLoaderCandidates = $loaders; asiLoaderAvailable = ($loaders.Count -gt 0 -or $cetLayout)
    }
}
function Install-AmperePackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Package,
          [Parameter(Mandatory)][string]$GameExecutable,
          [ValidateSet('Auto','ASI','Standalone')][string]$Mode = 'Auto')
    $executable = (Resolve-Path -LiteralPath $GameExecutable).ProviderPath
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'GameExecutable must be a file.' }
    if ([IO.Path]::GetFileName($executable) -ine 'Cyberpunk2077.exe') { throw 'This deployment handles Cyberpunk2077.exe only.' }
    Assert-OrdinaryPath $executable
    Assert-ClosedGame $executable
    $directory = [IO.Path]::GetDirectoryName($executable)
    $packageRoot = (Resolve-Path -LiteralPath $Package).ProviderPath
    $manifest = Get-Content -LiteralPath (Join-Path $packageRoot 'package.json') -Raw | ConvertFrom-Json
    $lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ampere-backend.lock.json') -Raw | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.commit -ne $lock.commit) { throw 'Unknown package revision.' }
    $sources = @(foreach ($name in @('version.dll','dlssg_sm86.ini')) {
        $entries = @($manifest.files | Where-Object name -CEQ $name)
        if ($entries.Count -ne 1) { throw "Missing or duplicate package entry: $name" }
        $hash = Get-FileDigest (Join-Path $packageRoot $name)
        if ($hash -ne $entries[0].sha256) { throw "Package hash mismatch: $name" }
        if ($name -eq 'version.dll' -and $hash -ne $lock.files[0].sha256) { throw 'Unrecognized backend DLL.' }
        [PSCustomObject]@{ source = $name; sha256 = $hash }
    })
    $loader = Get-AmpereLoaderState -Directory $directory
    if ($Mode -eq 'Auto') {
        if ($loader.asiLoaderAvailable) { $Mode = 'ASI' } else { $Mode = 'Standalone' }
    }
    if ($Mode -eq 'ASI' -and -not $loader.asiLoaderAvailable) {
        throw 'ASI mode needs a working ASI loader. Install/repair Cyber Engine Tweaks first, including its original bin/x64/version.dll.'
    }
    if ($Mode -eq 'Standalone' -and $loader.cetPluginPresent) {
        throw 'CET detected. Restore/reinstall CET and use ASI mode; Standalone would conflict with CET.'
    }
    if ($Mode -eq 'Standalone' -and $loader.rootProxyPresent -and -not $loader.rootIsBackend) {
        throw 'An unrelated version.dll already exists. It will not be replaced. Install/repair an ASI loader and use ASI mode.'
    }
    $asiPath = Get-SafeFile $directory 'plugins/dlssg_sm86.asi'
    if ((Test-Path -LiteralPath $asiPath) -and (Get-FileDigest $asiPath) -ne $lock.files[0].sha256) {
        throw 'Unrecognized plugins/dlssg_sm86.asi. Preserve it and resolve this conflict manually.'
    }
    $installNames = if ($Mode -eq 'ASI') { $script:AsiNames } else { @('version.dll','dlssg_sm86.ini') }
    $newFiles = @(for ($i = 0; $i -lt 2; $i++) {
        Get-SafeFile $directory $installNames[$i] | Out-Null
        [PSCustomObject]@{ name = $installNames[$i]; source = $sources[$i].source; sha256 = $sources[$i].sha256 }
    })
    # In ASI mode only the pinned root backend can be moved; CET's loader is preserved.
    $replaceNames = @($script:LegacyNames | Where-Object { $_ -ne 'version.dll' -or $Mode -eq 'Standalone' -or $loader.rootIsBackend }) + $script:AsiNames
    $originals = @(foreach ($name in $replaceNames) {
        $path = Get-SafeFile $directory $name
        if (Test-Path -LiteralPath $path) { [PSCustomObject]@{ name = $name; sha256 = Get-FileDigest $path } }
    })
    $backup = Join-Path $directory ('.rtx30fg-backup-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $backup | Out-Null
    [PSCustomObject]@{
        schema = 2; gameExecutable = $executable; createdUtc = [DateTime]::UtcNow.ToString('o')
        mode = $Mode; backendCommit = $lock.commit; originals = $originals; installed = $newFiles
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backup 'restore.json') -Encoding UTF8
    $moved = [Collections.Generic.List[string]]::new()
    $deployed = [Collections.Generic.List[object]]::new()
    try {
        for ($i = 0; $i -lt $newFiles.Count; $i++) {
            $pending = Join-Path $backup "$i.pending"
            [IO.File]::Copy((Join-Path $packageRoot $newFiles[$i].source), $pending, $false)
            if ((Get-FileDigest $pending) -ne $newFiles[$i].sha256) { throw 'Staged file verification failed.' }
        }
        Assert-ClosedGame $executable
        foreach ($file in $originals) {
            $path = Get-SafeFile $directory $file.name
            if ((Get-FileDigest $path) -ne $file.sha256) { throw "File changed during installation: $path" }
            Move-PreservedFile $path (Get-SafeFile $backup $file.name)
            $moved.Add($file.name)
        }
        for ($i = 0; $i -lt $newFiles.Count; $i++) {
            $file = $newFiles[$i]
            Move-PreservedFile (Join-Path $backup "$i.pending") (Get-SafeFile $directory $file.name)
            $deployed.Add($file)
        }
    } catch {
        $failure = $_
        foreach ($file in $deployed) {
            $path = Get-SafeFile $directory $file.name
            if ((Get-FileDigest $path) -ne $file.sha256) { throw "Installation failed; rollback stopped at changed file $path. Backup: $backup. Original error: $failure" }
            Move-PreservedFile $path (Join-Path $backup ($file.source + '.failed-install'))
        }
        foreach ($name in $moved) { Move-PreservedFile (Get-SafeFile $backup $name) (Get-SafeFile $directory $name) }
        throw $failure
    }
    Write-Verbose "Installed in $Mode mode."
    return (Join-Path $backup 'restore.json')
}
function Restore-AmperePackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Manifest)
    $manifestPath = (Resolve-Path -LiteralPath $Manifest).ProviderPath
    Assert-OrdinaryPath $manifestPath
    $state = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $backup = [IO.Path]::GetDirectoryName($manifestPath)
    $directory = [IO.Path]::GetDirectoryName($backup)
    if ($state.schema -notin @(1,2) -or [IO.Path]::GetFileName($manifestPath) -cne 'restore.json' -or
        [IO.Path]::GetFileName($backup) -notmatch '^\.rtx30fg-backup-[0-9a-f]{32}$' -or
        [IO.Path]::GetFullPath($state.gameExecutable) -ine (Join-Path $directory 'Cyberpunk2077.exe')) {
        throw 'Invalid restore manifest location or game path.'
    }
    Assert-ClosedGame $state.gameExecutable
    $allowed = $script:LegacyNames
    if ($state.schema -eq 2) { $allowed += $script:AsiNames }
    $installedNames = @($state.installed | ForEach-Object { $_.name })
    if ($installedNames.Count -ne 2 -or
        (($installedNames -join '|') -cne 'version.dll|dlssg_sm86.ini' -and
         ($state.schema -ne 2 -or ($installedNames -join '|') -cne 'plugins/dlssg_sm86.asi|plugins/dlssg_sm86.ini'))) {
        throw 'Invalid installed file set.'
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $state.originals) {
        if ($file.name -cnotin $allowed -or -not $seen.Add($file.name) -or $file.sha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Invalid original file entry.' }
        if ((Get-FileDigest (Get-SafeFile $backup $file.name)) -ne $file.sha256) { throw 'Backup integrity mismatch.' }
        $target = Get-SafeFile $directory $file.name
        if ($file.name -notin $installedNames -and (Test-Path -LiteralPath $target)) { throw "Restore would overwrite a new file: $($file.name)" }
    }
    foreach ($file in $state.installed) {
        if ($file.sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or (Get-FileDigest (Get-SafeFile $directory $file.name)) -ne $file.sha256) {
            throw "Installed file changed: $($file.name). Preserve it before restoring."
        }
        $destination = Join-Path $backup ($file.name + '.installed')
        Assert-OrdinaryPath $destination
        if (Test-Path -LiteralPath $destination) { throw 'Already restored or occupied backup.' }
    }
    $removed = [Collections.Generic.List[string]]::new()
    $restored = [Collections.Generic.List[string]]::new()
    try {
        Assert-ClosedGame $state.gameExecutable
        foreach ($file in $state.installed) {
            Move-PreservedFile (Get-SafeFile $directory $file.name) (Join-Path $backup ($file.name + '.installed'))
            $removed.Add($file.name)
        }
        foreach ($file in $state.originals) {
            Move-PreservedFile (Get-SafeFile $backup $file.name) (Get-SafeFile $directory $file.name)
            $restored.Add($file.name)
        }
    } catch {
        $failure = $_
        foreach ($name in $restored) { Move-PreservedFile (Get-SafeFile $directory $name) (Get-SafeFile $backup $name) }
        foreach ($name in $removed) { Move-PreservedFile (Join-Path $backup ($name + '.installed')) (Get-SafeFile $directory $name) }
        throw $failure
    }
}
Export-ModuleMember -Function Install-AmperePackage,Restore-AmperePackage,Get-AmpereLoaderState
