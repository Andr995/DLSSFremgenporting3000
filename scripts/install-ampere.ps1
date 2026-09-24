[CmdletBinding()]
param([Parameter(Mandatory)][string]$Package,
      [Parameter(Mandatory)][string]$GameExecutable)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AmpereDeployment.psm1') -Force
$manifest = Install-AmperePackage -Package $Package -GameExecutable $GameExecutable
Write-Output "Installed NVIDIA Ampere backend. Restore manifest: $manifest"
