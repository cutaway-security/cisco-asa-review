#Requires -Version 5.1
<#
.SYNOPSIS
    Render ASA review findings to a Markdown report and a CSV findings file.
.DESCRIPTION
    The v0.1b output stage (REQUIREMENTS FR-16, DR-02/DR-03, SR-04, NFR-06).
    Writes a timestamped Markdown report and CSV into the OutputDirectory (which
    defaults, in the entry point, to the configuration file's own directory), and
    returns the Markdown lines so the caller can also emit them to stdout. Secret
    values in evidence are masked by default; -RevealSecrets disables masking and
    is the caller's responsibility to warn about.

    Filenames carry a YYYYMMDD_HHMMSS timestamp and are guarded so they can never
    equal the input configuration file (the config is never overwritten).

    Read-only with respect to the input. Writes only the two report artifacts.
.OUTPUTS
    [pscustomobject] with MarkdownPath, CsvPath, and Markdown (string[]).
#>
function Write-AsaReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Findings,
        [Parameter(Mandatory)][pscustomobject]$Model,
        [Parameter(Mandatory)][string]$ConfigPath,
        [string]$OutputDirectory,
        [string]$Profile = 'commercial',
        [switch]$RevealSecrets,
        [string]$Timestamp,
        [int]$ChecksEvaluated
    )

    if (-not (Get-Command -Name Protect-AsaLine -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'Protect-AsaSecret.ps1')
    }

    if ([string]::IsNullOrEmpty($Timestamp)) { $Timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss') }
    if ([string]::IsNullOrEmpty($OutputDirectory)) {
        $OutputDirectory = Split-Path -Path $ConfigPath -Parent
        if ([string]::IsNullOrEmpty($OutputDirectory)) { $OutputDirectory = '.' }
    }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($ConfigPath)
    $mdPath  = Join-Path $OutputDirectory ("{0}_asa-review_{1}.md"  -f $base, $Timestamp)
    $csvPath = Join-Path $OutputDirectory ("{0}_asa-review_{1}.csv" -f $base, $Timestamp)

    $cfgFull = [System.IO.Path]::GetFullPath($ConfigPath)
    foreach ($p in @($mdPath, $csvPath)) {
        if ([System.IO.Path]::GetFullPath($p) -eq $cfgFull) {
            throw "[x] Refusing to overwrite the configuration file: $p"
        }
    }

    $mask = { param($t) if ($RevealSecrets) { $t } else { Protect-AsaLine -Line $t } }

    # ---- counts ----
    $real = @($Findings | Where-Object { $_.Status -eq 'finding' -and $_.Severity -ne 'Informational' })
    $na   = @($Findings | Where-Object { $_.Status -eq 'not-assessed' })
    $info = @($Findings | Where-Object { $_.Status -eq 'finding' -and $_.Severity -eq 'Informational' })
    $high = @($real | Where-Object { $_.Severity -eq 'High' }).Count
    $med  = @($real | Where-Object { $_.Severity -eq 'Medium' }).Count
    $low  = @($real | Where-Object { $_.Severity -eq 'Low' }).Count

    # ---- Markdown ----
    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add('# Cisco ASA Configuration Review')
    $md.Add('')
    $md.Add("- Configuration: $([System.IO.Path]::GetFileName($ConfigPath))")
    $md.Add("- Profile: $Profile")
    $md.Add("- Generated: $Timestamp")
    $md.Add("- Tool: cisco-asa-review (passive, offline, read-only static analysis; no device contact)")
    if ($RevealSecrets) { $md.Add('- NOTE: secret values are SHOWN (-RevealSecrets); treat this report as credential-bearing.') }
    $md.Add('')
    $md.Add('## Summary')
    $md.Add('')
    $md.Add("- Findings: $($real.Count) (High: $high, Medium: $med, Low: $low)")
    $md.Add("- Informational (hygiene/cleanup): $($info.Count)")
    $md.Add("- Not assessed: $($na.Count)")
    if ($PSBoundParameters.ContainsKey('ChecksEvaluated')) { $md.Add("- Checks evaluated: $ChecksEvaluated") }
    $md.Add("- Config lines parsed: $($Model.LineCount)")
    $md.Add('')
    $md.Add('## Findings')
    $md.Add('')

    if ($Findings.Count -eq 0) {
        $md.Add('No findings. (Note: absence of findings is bounded by the implemented check set, not a clean bill of health.)')
    }
    foreach ($f in $Findings) {
        $tag = if ($f.Status -eq 'not-assessed') { 'NOT ASSESSED' } else { $f.Severity.ToUpperInvariant() }
        $md.Add("### [$tag] $($f.CheckId)")
        $md.Add('')
        $md.Add("- Category: $($f.Category) | Severity: $($f.Severity) | Confidence: $($f.Confidence)")
        $md.Add("- Authority: $($f.Authority) (verified: $($f.Verified))")
        if ($f.EvidenceLineNo -gt 0) {
            $md.Add("- Evidence (line $($f.EvidenceLineNo)): ``$(& $mask $f.Evidence)``")
            if ($f.EvidenceCount -gt 1) {
                $md.Add("- Additional evidence lines: $($f.EvidenceCount - 1)")
                foreach ($e in ($f.EvidenceLines | Sort-Object LineNo | Select-Object -Skip 1)) {
                    $md.Add("  - line $($e.LineNo): ``$(& $mask $e.Text)``")
                }
            }
        } else {
            $md.Add("- Evidence: setting absent ($($f.Kind))")
        }
        $md.Add("- Rationale: $($f.Rationale)")
        $md.Add("- Remediation: $($f.Remediation)")
        $md.Add('')
    }

    Set-Content -LiteralPath $mdPath -Value $md -Encoding UTF8

    # ---- CSV (DR-02 schema) ----
    # CSV is the tracking artifact (DR-02a): includes Informational rows and two
    # team-filled columns (RemediationState defaults to Open; RemediationNotes empty).
    $rows = foreach ($f in $Findings) {
        [pscustomobject]@{
            CheckId          = $f.CheckId
            Category         = $f.Category
            Severity         = $f.Severity
            Status           = $f.Status
            Authority        = $f.Authority
            Verified         = $f.Verified
            Confidence       = $f.Confidence
            EvidenceLineNo   = $f.EvidenceLineNo
            Evidence         = if ($f.EvidenceLineNo -gt 0) { & $mask $f.Evidence } else { "absent ($($f.Kind))" }
            Remediation      = $f.Remediation
            RemediationState = 'Open'
            RemediationNotes = ''
        }
    }
    $csvHeader = 'CheckId,Category,Severity,Status,Authority,Verified,Confidence,EvidenceLineNo,Evidence,Remediation,RemediationState,RemediationNotes'
    if ($rows) { $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8 }
    else { Set-Content -LiteralPath $csvPath -Value $csvHeader -Encoding UTF8 }

    [pscustomobject]@{
        MarkdownPath = $mdPath
        CsvPath      = $csvPath
        Markdown     = $md.ToArray()
    }
}
