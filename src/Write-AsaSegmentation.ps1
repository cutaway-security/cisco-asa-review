#Requires -Version 5.1
<#
.SYNOPSIS
    Render a segmentation + data-flow visualization (Mermaid topology + zone
    matrix) from the zone model (Phase 5, FR-23..FR-26).
.DESCRIPTION
    Emits a self-contained Markdown file (offline text only -- no renderer is
    invoked, SR-01): a zone-level Mermaid flowchart and a zone-to-zone
    connectivity matrix. Risk conditions (permit ip any any) are highlighted as
    thick red edges / flagged matrix cells, each tied to the offending ACL line.
    Secret values in any shown evidence are masked by default (SR-04). Output is
    deterministic (NFR-06). The file states the configured-flows-not-reachability
    boundary and the known best-effort gaps.
.OUTPUTS
    [pscustomobject] MarkdownPath, Markdown (string[]), RiskEdgeCount.
#>
function Write-AsaSegmentation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$ZoneModel,
        [Parameter(Mandatory)][string]$ConfigPath,
        [string]$OutputDirectory,
        [switch]$RevealSecrets,
        [string]$Timestamp
    )

    if (-not (Get-Command -Name Protect-AsaLine -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'Protect-AsaSecret.ps1')
    }
    $mask = { param($t) if ($RevealSecrets) { $t } else { Protect-AsaLine -Line $t } }

    if ([string]::IsNullOrEmpty($Timestamp)) { $Timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss') }
    if ([string]::IsNullOrEmpty($OutputDirectory)) {
        $OutputDirectory = Split-Path -Path $ConfigPath -Parent
        if ([string]::IsNullOrEmpty($OutputDirectory)) { $OutputDirectory = '.' }
    }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($ConfigPath)
    $mdPath = Join-Path $OutputDirectory ("{0}_asa-segmentation_{1}.md" -f $base, $Timestamp)
    if ([System.IO.Path]::GetFullPath($mdPath) -eq [System.IO.Path]::GetFullPath($ConfigPath)) {
        throw "[x] Refusing to overwrite the configuration file: $mdPath"
    }

    $nodeId = { param($n) 'Z_' + ($n -replace '[^A-Za-z0-9]', '_') }

    # display order: tier (Untrusted, DMZ, Trusted) then name; external last
    $tierRank = @{ Untrusted = 0; DMZ = 1; Trusted = 2 }
    $orderedZones = @($ZoneModel.Zones | Sort-Object @{Expression={$tierRank[$_.Tier]}}, @{Expression={$_.Name}})
    $allZoneNames = @($orderedZones | ForEach-Object { $_.Name })
    if ($ZoneModel.ExternalUsed) { $allZoneNames += 'external' }

    # aggregate edges by From|To
    $agg = @{}
    foreach ($e in $ZoneModel.Edges) {
        $k = "$($e.From)`u{1}$($e.To)"
        if (-not $agg.ContainsKey($k)) {
            $agg[$k] = [pscustomobject]@{ From=$e.From; To=$e.To; AnyAny=$false; Protos=[System.Collections.Generic.HashSet[string]]::new(); Lines=[System.Collections.Generic.List[object]]::new() }
        }
        if ($e.AnyAny) { $agg[$k].AnyAny = $true }
        [void]$agg[$k].Protos.Add($e.Proto.ToLowerInvariant())
        $agg[$k].Lines.Add($e)
    }
    $aggEdges = @($agg.Values | Sort-Object @{Expression='From'}, @{Expression='To'})

    # ---- Markdown ----
    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add('# Cisco ASA Segmentation and Data-Flow Map')
    $md.Add('')
    $md.Add("- Configuration: $([System.IO.Path]::GetFileName($ConfigPath))")
    $md.Add("- Generated: $Timestamp")
    $md.Add('- Tool: cisco-asa-review (passive, offline static analysis)')
    $md.Add('')
    $md.Add('> Scope and limits (best-effort, stop-gap):')
    foreach ($n in $ZoneModel.Notes) { $md.Add("> - $n") }
    $md.Add('')
    $md.Add('## Zone topology')
    $md.Add('')
    $md.Add('```mermaid')
    $md.Add('flowchart LR')

    foreach ($tier in 'Untrusted','DMZ','Trusted') {
        $inTier = @($orderedZones | Where-Object { $_.Tier -eq $tier })
        if ($inTier.Count -eq 0) { continue }
        $md.Add("  subgraph TIER_$tier[`"$tier`"]")
        foreach ($z in $inTier) {
            $cidr = ($z.Subnets | ForEach-Object { $_.Cidr }) -join ','
            $label = "$($z.Name) / sl$($z.SecurityLevel)"
            if ($cidr) { $label += " / $cidr" }
            $md.Add("    $(& $nodeId $z.Name)[`"$label`"]")
        }
        $md.Add('  end')
    }
    if ($ZoneModel.ExternalUsed) {
        $md.Add('  subgraph TIER_External["External / off-box"]')
        $md.Add('    Z_external["external / unmapped or off-box"]')
        $md.Add('  end')
    }

    $riskIdx = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $aggEdges.Count; $i++) {
        $e = $aggEdges[$i]
        if ($e.AnyAny) {
            $first = $e.Lines | Where-Object { $_.AnyAny } | Sort-Object LineNo | Select-Object -First 1
            $label = "ANY-ANY $($first.Acl) L$($first.LineNo)"
            $riskIdx.Add($i)
        } else {
            $label = (@($e.Protos) | Sort-Object) -join '/'
            if (-not $label) { $label = 'permit' }
        }
        $md.Add("  $(& $nodeId $e.From) -->|`"$label`"| $(& $nodeId $e.To)")
    }

    $md.Add('  classDef untrusted fill:#fde2e2,stroke:#b00000,color:#000000;')
    foreach ($z in ($orderedZones | Where-Object { $_.IsUntrusted })) {
        $md.Add("  class $(& $nodeId $z.Name) untrusted;")
    }
    foreach ($ix in $riskIdx) {
        $md.Add("  linkStyle $ix stroke:#b00000,stroke-width:4px,color:#b00000;")
    }
    $md.Add('```')
    $md.Add('')

    # ---- matrix ----
    $md.Add('## Zone-to-zone connectivity matrix')
    $md.Add('')
    $md.Add('Most-permissive configured flow from each source zone (row) to each destination zone (column). `ANY-ANY (!)` marks a permit ip any any exposure.')
    $md.Add('')
    $header = '| src \\ dst | ' + (($allZoneNames | ForEach-Object { $_ }) -join ' | ') + ' |'
    $sep = '|' + ('---|' * ($allZoneNames.Count + 1))
    $md.Add($header)
    $md.Add($sep)
    foreach ($f in $allZoneNames) {
        $cells = foreach ($t in $allZoneNames) {
            if ($f -eq $t) { '-'; continue }
            $k = "$f`u{1}$t"
            if (-not $agg.ContainsKey($k)) { '-'; continue }
            if ($agg[$k].AnyAny) { '**ANY-ANY (!)**' }
            else { (@($agg[$k].Protos) | Sort-Object) -join '/' }
        }
        $md.Add("| **$f** | " + ($cells -join ' | ') + ' |')
    }
    $md.Add('')

    # ---- risk flows ----
    $riskEdges = @($aggEdges | Where-Object { $_.AnyAny })
    $md.Add('## Highlighted risk flows')
    $md.Add('')
    if ($riskEdges.Count -eq 0) {
        $md.Add('No permit ip any any inter-zone flows detected (within the implemented checks).')
    } else {
        foreach ($e in $riskEdges) {
            $first = $e.Lines | Where-Object { $_.AnyAny } | Sort-Object LineNo | Select-Object -First 1
            $md.Add("- ANY/ANY  $($e.From) -> $($e.To)  (ACL $($first.Acl), line $($first.LineNo)): ``$(& $mask $first.Evidence)``")
        }
    }
    $md.Add('')

    Set-Content -LiteralPath $mdPath -Value $md -Encoding UTF8

    [pscustomobject]@{
        MarkdownPath  = $mdPath
        Markdown      = $md.ToArray()
        RiskEdgeCount = $riskEdges.Count
    }
}
