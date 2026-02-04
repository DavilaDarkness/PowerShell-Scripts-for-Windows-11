#requires -version 5.1
<#[
.SYNOPSIS
  Removes Microsoft Copilot and disables the Windows Recall feature.
.DESCRIPTION
  Removes Copilot AppX packages (installed + provisioned) and sets policy registry keys
  to disable both Copilot and Recall. Run as Administrator.
#>

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-RegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$Value,
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryValueKind]$Type
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

if (-not (Test-IsAdministrator)) {
    Write-Error 'This script must be run as Administrator.'
}

Write-Host 'Removing Microsoft Copilot AppX packages (installed + provisioned)...'
Get-AppxPackage -AllUsers -Name 'Microsoft.Copilot' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Removing installed package: $($_.PackageFullName)"
    Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
}

Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq 'Microsoft.Copilot' | ForEach-Object {
    Write-Host "Removing provisioned package: $($_.PackageName)"
    Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
}

Write-Host 'Disabling Windows Copilot policy...'
Ensure-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' `
    -Name 'TurnOffWindowsCopilot' -Value 1 -Type DWord

Write-Host 'Disabling Windows Recall policy...'
Ensure-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' `
    -Name 'DisableAIDataAnalysis' -Value 1 -Type DWord

Write-Host 'Done. A reboot or sign-out may be required for changes to take effect.'
