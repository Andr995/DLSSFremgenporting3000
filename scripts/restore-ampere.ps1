[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manifest)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AmpereDeployment.psm1') -Force
Restore-AmperePackage -Manifest $Manifest
Write-Output 'Previous game files restored; both versions remain preserved.'
