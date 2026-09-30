[CmdletBinding()]
param([Parameter(Mandatory)][string]$Package,
      [Parameter(Mandatory)][string]$GameExecutable,
      [ValidateSet('Auto','ASI','Standalone')][string]$Mode = 'Auto')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AmpereDeployment.psm1') -Force
$manifest = Install-AmperePackage -Package $Package -GameExecutable $GameExecutable -Mode $Mode
Write-Output "Installed NVIDIA Ampere backend. Restore manifest: $manifest"
