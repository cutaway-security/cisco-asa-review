#Requires -Version 5.1
<#
.SYNOPSIS
    Run the MVP security checks against a parsed ASA model and return findings.
.DESCRIPTION
    The v0.1b check engine (REQUIREMENTS FR-06/FR-07, AR-01/AR-03). Loads the
    declarative catalog (data/check-catalog.psd1) and dispatches each check by
    detector type:
        present  -- finding when any catalog Pattern matches a config line
        absent   -- finding when NO line matches the Pattern (ASA default-backed)
        code     -- a structural detector in checks/structural.ps1
    Produces one finding object per fired check, with config evidence (line
    number + raw text) or an explicit absence marker, and the check metadata.
    Findings are returned in a deterministic order (NFR-06): severity, then check
    id (ordinal), then evidence line number.

    Read-only, in memory, no network.
.PARAMETER Model
    A parsed model from ConvertTo-AsaModel.
.PARAMETER Profile
    Check profile to apply: 'commercial' (default) or 'dod'.
.PARAMETER CatalogPath
    Path to the check catalog. Defaults to data/check-catalog.psd1.
.OUTPUTS
    [pscustomobject[]] findings.
#>
function Invoke-AsaChecks {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [pscustomobject]$Model,

        [ValidateSet('commercial','dod')]
        [string]$Profile = 'commercial',

        [string]$CatalogPath = (Join-Path $PSScriptRoot '..\data\check-catalog.psd1')
    )

    begin {
        if (-not (Get-Command -Name Test-AsaAclAnyAny -ErrorAction SilentlyContinue)) {
            . (Join-Path $PSScriptRoot 'checks\structural.ps1')
        }
        $catalog = Import-PowerShellDataFile -LiteralPath $CatalogPath
        $sevRank = @{ High = 0; Medium = 1; Low = 2 }
    }

    process {
        $findings = [System.Collections.Generic.List[object]]::new()

        $lineNodes = @($Model.Lines | Where-Object { $_.Kind -eq 'line' })

        foreach ($check in $catalog.Checks) {
            if ($check.Profile -notcontains $Profile) { continue }

            $status = 'finding'
            $evNodes = @()
            $fired = $false

            switch ($check.Detector.Type) {
                'present' {
                    foreach ($n in $lineNodes) {
                        foreach ($pat in $check.Detector.Patterns) {
                            if ([regex]::IsMatch($n.Text, $pat, 'IgnoreCase')) { $evNodes += $n; break }
                        }
                    }
                    $fired = ($evNodes.Count -gt 0)
                }
                'absent' {
                    $present = $false
                    foreach ($n in $lineNodes) {
                        if ([regex]::IsMatch($n.Text, $check.Detector.Pattern, 'IgnoreCase')) { $present = $true; break }
                    }
                    $fired = (-not $present)   # absence is the finding
                }
                'code' {
                    $result = & (Get-Command $check.Detector.Function) -Model $Model
                    $fired = $result.Fired
                    $status = $result.Status
                    $evNodes = @($result.Evidence)
                }
            }

            if (-not $fired) { continue }

            $evLines = @($evNodes | ForEach-Object { [pscustomobject]@{ LineNo = $_.LineNo; Text = $_.Text } })
            $firstNo = if ($evLines.Count -gt 0) { ($evLines | Sort-Object LineNo | Select-Object -First 1).LineNo } else { 0 }
            $firstTx = if ($evLines.Count -gt 0) { ($evLines | Sort-Object LineNo | Select-Object -First 1).Text } else { "absent: $($check.Detector.Pattern)" }

            $findings.Add([pscustomobject]@{
                CheckId        = $check.Id
                Category       = $check.Category
                Severity       = $check.Severity
                SeverityRank   = $sevRank[$check.Severity]
                Authority      = $check.Authority
                Verified       = $check.Verified
                Confidence     = $check.Confidence
                Dependency     = ($check.Dependency -join ',')
                Profile        = ($check.Profile -join ',')
                Kind           = $check.Kind
                Status         = $status
                EvidenceLineNo = $firstNo
                EvidenceCount  = $evLines.Count
                Evidence       = $firstTx
                EvidenceLines  = $evLines
                Rationale      = $check.Rationale
                Remediation    = $check.Remediation
            })
        }

        # Deterministic ordering (NFR-06): severity, then ordinal check id, then
        # line. Emit the pipeline directly so an empty result emits nothing (not
        # a stray $null).
        $findings | Sort-Object `
            @{ Expression = 'SeverityRank' }, `
            @{ Expression = { $_.CheckId } }, `
            @{ Expression = 'EvidenceLineNo' }
    }
}
