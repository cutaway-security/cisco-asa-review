#Requires -Version 5.1
<#
.SYNOPSIS
    Refresh the bundled ASA EoL reference (data/asa-eol.psd1) from an online
    source -- an OPT-IN maintenance tool, separate from the review.
.DESCRIPTION
    This is the ONLY script in the project that uses the network, and it is NOT
    part of a config review. The review (Invoke-AsaReview.ps1) is always offline
    and uses the bundled reference; run this updater deliberately, on a connected
    machine, to refresh that reference.

    Behavior (the "check the internet, else use the reference" flow):
      - Attempt to fetch EoL data from -SourceUrl (expects JSON of the shape
        { ReferenceDate, Trains: [ { Train, Status }, ... ], Hardware: [...] }).
      - If reachable and valid, rewrite data/asa-eol.psd1 from it.
      - If unreachable or invalid, leave the existing reference untouched and
        report that the bundled reference will continue to be used.

    Run a config review with NO network; only run this when you choose to update.
.PARAMETER SourceUrl
    URL of a JSON EoL feed. Supply your own maintained source; there is no
    guaranteed public Cisco machine-readable feed, so this has no default.
.PARAMETER ReferencePath
    Path to the reference to update. Defaults to data/asa-eol.psd1.
.PARAMETER TimeoutSec
    Network timeout. Default 15s.
.EXAMPLE
    .\Update-AsaEolData.ps1 -SourceUrl https://intranet.example/asa-eol.json
#>
[CmdletBinding()]
param(
    [string]$SourceUrl,
    [string]$ReferencePath = (Join-Path $PSScriptRoot 'data\asa-eol.psd1'),
    [int]$TimeoutSec = 15
)

function Get-AsaEolFromWeb {
    param([string]$Url, [int]$Timeout)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    try {
        $resp = Invoke-RestMethod -Uri $Url -TimeoutSec $Timeout -ErrorAction Stop
        if ($null -ne $resp -and $resp.Trains) { return $resp }
        return $null
    } catch {
        return $null
    }
}

function ConvertTo-EolPsd1 {
    param($Data)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# asa-eol.psd1 -- refreshed by Update-AsaEolData.ps1')
    [void]$sb.AppendLine('@{')
    [void]$sb.AppendLine('    SchemaVersion = 1')
    $refDate = if ($Data.ReferenceDate) { $Data.ReferenceDate } else { 'unknown' }
    [void]$sb.AppendLine("    ReferenceDate = '$refDate'")
    [void]$sb.AppendLine("    Source        = 'Refreshed from an online feed via Update-AsaEolData.ps1.'")
    [void]$sb.AppendLine('    Hardware = @(')
    foreach ($h in @($Data.Hardware)) {
        if ($null -eq $h) { continue }
        [void]$sb.AppendLine("        @{ Model = '$($h.Model)'; Status = '$($h.Status)' }")
    }
    [void]$sb.AppendLine('    )')
    [void]$sb.AppendLine('    Trains = @(')
    foreach ($t in @($Data.Trains)) {
        if ($null -eq $t) { continue }
        [void]$sb.AppendLine("        @{ Train = '$($t.Train)'; Status = '$($t.Status)' }")
    }
    [void]$sb.AppendLine('    )')
    [void]$sb.AppendLine("    DefaultStatusForUnlisted = 'Unknown'")
    [void]$sb.AppendLine('}')
    $sb.ToString()
}

# Main body runs only when the script is invoked (not when dot-sourced for tests).
if ($MyInvocation.InvocationName -ne '.') {
    $data = Get-AsaEolFromWeb -Url $SourceUrl -Timeout $TimeoutSec
    if ($null -eq $data) {
        Write-Warning "[*] EoL data not available from the internet (no/invalid SourceUrl or unreachable). Keeping the bundled reference: $ReferencePath"
        exit 0
    }
    Set-Content -LiteralPath $ReferencePath -Value (ConvertTo-EolPsd1 -Data $data) -Encoding UTF8
    Write-Output "[+] Updated EoL reference from $SourceUrl -> $ReferencePath"
    exit 0
}
