<#
.SYNOPSIS
  Completely removes Microsoft OneDrive from Windows 11.

.DESCRIPTION
  Stops OneDrive processes, uninstalls OneDrive, removes leftover files and
  scheduled tasks, and cleans related registry entries for the current machine.

.NOTES
  Run in an elevated PowerShell session.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

function Invoke-IfShouldProcess {
  param(
    [string]$Target,
    [string]$Action,
    [scriptblock]$ScriptBlock
  )

  if ($PSCmdlet.ShouldProcess($Target, $Action)) {
    & $ScriptBlock
  }
}

Write-Host 'Stopping OneDrive processes...' -ForegroundColor Cyan
Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name 'OneDriveSetup' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$system32Setup = Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'
$syswow64Setup = Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'

Write-Host 'Uninstalling OneDrive (if present)...' -ForegroundColor Cyan
if (Test-Path $syswow64Setup) {
  Invoke-IfShouldProcess -Target $syswow64Setup -Action 'Uninstall OneDrive' -ScriptBlock {
    Start-Process -FilePath $syswow64Setup -ArgumentList '/uninstall' -Wait
  }
} elseif (Test-Path $system32Setup) {
  Invoke-IfShouldProcess -Target $system32Setup -Action 'Uninstall OneDrive' -ScriptBlock {
    Start-Process -FilePath $system32Setup -ArgumentList '/uninstall' -Wait
  }
} else {
  Write-Host 'OneDriveSetup.exe not found. Skipping uninstall step.' -ForegroundColor Yellow
}

Write-Host 'Removing OneDrive folders...' -ForegroundColor Cyan
$foldersToRemove = @(
  Join-Path $env:UserProfile 'OneDrive',
  Join-Path $env:LocalAppData 'Microsoft\OneDrive',
  Join-Path $env:ProgramData 'Microsoft OneDrive',
  Join-Path $env:SystemDrive 'OneDriveTemp'
)

foreach ($folder in $foldersToRemove) {
  if (Test-Path $folder) {
    Invoke-IfShouldProcess -Target $folder -Action 'Remove directory' -ScriptBlock {
      Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Write-Host 'Removing OneDrive scheduled tasks...' -ForegroundColor Cyan
$taskPaths = @(
  '\Microsoft\Windows\OneDrive\OneDrive Standalone Update Task v2',
  '\Microsoft\Windows\OneDrive\OneDrive Standalone Update Task v2 (User)'
)

foreach ($taskPath in $taskPaths) {
  $taskName = Split-Path $taskPath -Leaf
  $taskFolder = Split-Path $taskPath -Parent

  $task = Get-ScheduledTask -TaskPath ($taskFolder + '\') -TaskName $taskName -ErrorAction SilentlyContinue
  if ($null -ne $task) {
    Invoke-IfShouldProcess -Target $taskPath -Action 'Unregister scheduled task' -ScriptBlock {
      Unregister-ScheduledTask -TaskPath ($taskFolder + '\') -TaskName $taskName -Confirm:$false
    }
  }
}

Write-Host 'Cleaning OneDrive registry entries...' -ForegroundColor Cyan

Invoke-IfShouldProcess -Target 'HKCU:\Software\Microsoft\OneDrive' -Action 'Remove registry key' -ScriptBlock {
  if (Test-Path 'HKCU:\Software\Microsoft\OneDrive') {
    Remove-Item -Path 'HKCU:\Software\Microsoft\OneDrive' -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Invoke-IfShouldProcess -Target 'HKLM:\Software\Microsoft\OneDrive' -Action 'Remove registry key' -ScriptBlock {
  if (Test-Path 'HKLM:\Software\Microsoft\OneDrive') {
    Remove-Item -Path 'HKLM:\Software\Microsoft\OneDrive' -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Invoke-IfShouldProcess -Target 'HKLM:\Software\Policies\Microsoft\Windows\OneDrive' -Action 'Remove registry key' -ScriptBlock {
  if (Test-Path 'HKLM:\Software\Policies\Microsoft\Windows\OneDrive') {
    Remove-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows\OneDrive' -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Invoke-IfShouldProcess -Target 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Action 'Remove OneDrive autorun value' -ScriptBlock {
  if (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run') {
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -ErrorAction SilentlyContinue
  }
}

Write-Host 'OneDrive removal completed.' -ForegroundColor Green
