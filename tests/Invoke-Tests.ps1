#Requires -Version 5.1
<#
.SYNOPSIS
    Run the cisco-asa-review test suite (offline, no device, no network).
.DESCRIPTION
    Configures and runs Pester 5.x over tests/unit. Requires Pester 5.x
    installed on the dev host (a development-only dependency; the tool itself
    has no module dependencies). Returns a non-zero exit code if any test fails.
.EXAMPLE
    pwsh -NoProfile -File tests/Invoke-Tests.ps1
#>
[CmdletBinding()]
param(
    [string]$Path = (Join-Path $PSScriptRoot 'unit')
)

$ErrorActionPreference = 'Stop'

$pester = Get-Module -ListAvailable Pester |
    Where-Object { $_.Version.Major -ge 5 } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pester) {
    Write-Error '[x] Pester 5.x not found. Install dev dependency: Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0.0'
    exit 2
}

Import-Module $pester.Path -Force

$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Run.Exit = $false
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $false

$result = Invoke-Pester -Configuration $config

Write-Host ''
Write-Host ("[$([char]36)] Pester summary: {0} passed, {1} failed, {2} skipped" -f `
    $result.PassedCount, $result.FailedCount, $result.SkippedCount)

if ($result.FailedCount -gt 0) { exit 1 } else { exit 0 }
