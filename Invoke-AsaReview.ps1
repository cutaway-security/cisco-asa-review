#Requires -Version 5.1
<#
.SYNOPSIS
    Passive, offline security review of a Cisco ASA running-config file.
.DESCRIPTION
    cisco-asa-review reads a Cisco ASA 9.x 'show running-config' text file from
    local disk, parses it, evaluates the MVP security checks, and writes a
    Markdown report and a CSV findings file next to the configuration file
    (never overwriting it). The Markdown report is also emitted to stdout.

    This tool is PASSIVE and OFFLINE: it never contacts a device, never makes a
    network call, and never modifies the input. The analyst supplies a config
    that was exported out-of-band through their own authorized means.

    Secret values in the report are masked by default; -RevealSecrets shows them
    and marks the report as credential-bearing.
.PARAMETER ConfigPath
    Path to the ASA running-config text file to review.
.PARAMETER OutputDirectory
    Directory for the report/CSV. Defaults to the configuration file's directory.
.PARAMETER Profile
    Check profile: 'commercial' (default) or 'dod'.
.PARAMETER RevealSecrets
    Disable default secret masking (use only on a trusted host).
.PARAMETER ExpandAnyAny
    In the topology diagrams, draw every individual any-any flow instead of
    collapsing a zone's "permit ip any any to all zones" into a single badge.
    The matrix and risk list are always exhaustive regardless of this switch.
.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    .\Invoke-AsaReview.ps1 -ConfigPath .\asa-running-config.txt
.EXAMPLE
    .\Invoke-AsaReview.ps1 -ConfigPath .\cfg.txt -Profile dod > review.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath,

    [string]$OutputDirectory,

    [ValidateSet('commercial','dod')]
    [string]$Profile = 'commercial',

    [switch]$RevealSecrets,

    [switch]$ExpandAnyAny
)

$ErrorActionPreference = 'Stop'

$src = Join-Path $PSScriptRoot 'src'
. (Join-Path $src 'Read-AsaConfig.ps1')
. (Join-Path $src 'ConvertTo-AsaModel.ps1')
. (Join-Path $src 'Get-AsaSecrets.ps1')
. (Join-Path $src 'Get-AsaInterfaceRoles.ps1')
. (Join-Path $src 'Resolve-AsaReferences.ps1')
. (Join-Path $src 'checks\structural.ps1')
. (Join-Path $src 'Invoke-AsaChecks.ps1')
. (Join-Path $src 'Protect-AsaSecret.ps1')
. (Join-Path $src 'Write-AsaReport.ps1')
. (Join-Path $src 'Get-AsaZoneModel.ps1')
. (Join-Path $src 'Write-AsaSegmentation.ps1')
. (Join-Path $src 'Write-AsaHtmlReport.ps1')

if ($OutputDirectory -and -not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

try {
    $model = ConvertTo-AsaModel -Path $ConfigPath
}
catch {
    Write-Error "[x] Failed to read/parse configuration: $($_.Exception.Message)"
    exit 1
}

$catalogPath = Join-Path $src '..\data\check-catalog.psd1'
$checksEvaluated = (Import-PowerShellDataFile -LiteralPath $catalogPath).Checks |
    Where-Object { $_.Profile -contains $Profile } | Measure-Object | Select-Object -ExpandProperty Count

$findings = Invoke-AsaChecks -Model $model -Profile $Profile -CatalogPath $catalogPath

$report = Write-AsaReport -Findings @($findings) -Model $model -ConfigPath $ConfigPath `
    -OutputDirectory $OutputDirectory -Profile $Profile -RevealSecrets:$RevealSecrets `
    -ChecksEvaluated $checksEvaluated

# Segmentation + data-flow map (always produced; separate file). Best-effort.
$ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
$zoneModel = Get-AsaZoneModel -Model $model
$seg = Write-AsaSegmentation -ZoneModel $zoneModel -ConfigPath $ConfigPath `
    -OutputDirectory $OutputDirectory -RevealSecrets:$RevealSecrets -ExpandAnyAny:$ExpandAnyAny -Timestamp $ts

# Consolidated self-contained HTML deliverable (findings + segmentation; opens in
# any browser, no install, no internet; Print -> Save as PDF for a PDF).
$html = Write-AsaHtmlReport -Findings @($findings) -ZoneModel $zoneModel -Model $model `
    -ConfigPath $ConfigPath -OutputDirectory $OutputDirectory -Profile $Profile `
    -RevealSecrets:$RevealSecrets -ExpandAnyAny:$ExpandAnyAny -Timestamp $ts -ChecksEvaluated $checksEvaluated

# Status/diagnostics to stderr (information stream); the report to stdout (NFR-06).
$real = @($findings | Where-Object { $_.Status -eq 'finding' })
$na   = @($findings | Where-Object { $_.Status -eq 'not-assessed' })
[Console]::Error.WriteLine("[*] Parsed $($model.LineCount) lines from $([System.IO.Path]::GetFileName($ConfigPath))")
[Console]::Error.WriteLine("[*] Profile: $Profile | Checks evaluated: $checksEvaluated")
[Console]::Error.WriteLine("[$([char]36)] Findings: $($real.Count) (High/Med/Low) + Not-assessed: $($na.Count)")
[Console]::Error.WriteLine("[$([char]36)] Report: $($report.MarkdownPath)")
[Console]::Error.WriteLine("[$([char]36)] CSV:    $($report.CsvPath)")
[Console]::Error.WriteLine("[$([char]36)] Segmentation map: $($seg.MarkdownPath) (risk flows: $($seg.RiskEdgeCount))")
[Console]::Error.WriteLine("[$([char]36)] HTML deliverable: $($html.HtmlPath)")
if ($RevealSecrets) { [Console]::Error.WriteLine('[x] -RevealSecrets set: report contains cleartext secrets. Handle the output files as credential-bearing.') }

# Markdown report to stdout.
$report.Markdown | ForEach-Object { Write-Output $_ }

exit 0
