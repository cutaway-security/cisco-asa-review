#Requires -Version 5.1
<#
.SYNOPSIS
    Render a single self-contained HTML deliverable consolidating the findings and
    the segmentation map (Phase 5b, FR-23..FR-26 client-deliverable variant).
.DESCRIPTION
    Produces one .html file that opens in any browser on any OS with NOTHING
    installed and NO internet: embedded CSS only, no JavaScript, no external
    resources. The network topology is drawn as inline SVG (renders and prints
    identically everywhere; no diagram-as-code renderer required); the
    connectivity matrix is a colored HTML table. Findings are included so the
    HTML is a standalone client report. PDF is produced by the analyst/client via
    the browser's Print -> Save as PDF (zero tools).

    No JS is emitted on purpose: HTML-with-JS attachments are frequently stripped
    by client mail/secure-transfer gateways, and inline SVG + CSS is the most
    portable, print-stable form. Secret values are masked by default (SR-04).
    Output is deterministic (NFR-06).
.OUTPUTS
    [pscustomobject] HtmlPath, Html (string).
#>
function Write-AsaHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Findings,
        [Parameter(Mandatory)][pscustomobject]$ZoneModel,
        [Parameter(Mandatory)][pscustomobject]$Model,
        [Parameter(Mandatory)][string]$ConfigPath,
        [string]$OutputDirectory,
        [string]$Profile = 'commercial',
        [switch]$RevealSecrets,
        [switch]$ExpandAnyAny,
        [string]$Timestamp,
        [int]$ChecksEvaluated
    )

    if (-not (Get-Command -Name Protect-AsaLine -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'Protect-AsaSecret.ps1')
    }
    $mask = { param($t) if ($RevealSecrets) { $t } else { Protect-AsaLine -Line $t } }
    $esc  = { param($t) ([string]$t).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;') }

    if ([string]::IsNullOrEmpty($Timestamp)) { $Timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss') }
    if ([string]::IsNullOrEmpty($OutputDirectory)) {
        $OutputDirectory = Split-Path -Path $ConfigPath -Parent
        if ([string]::IsNullOrEmpty($OutputDirectory)) { $OutputDirectory = '.' }
    }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($ConfigPath)
    $htmlPath = Join-Path $OutputDirectory ("{0}_asa-report_{1}.html" -f $base, $Timestamp)
    if ([System.IO.Path]::GetFullPath($htmlPath) -eq [System.IO.Path]::GetFullPath($ConfigPath)) {
        throw "[x] Refusing to overwrite the configuration file: $htmlPath"
    }

    # ---- aggregate zone edges (zone pair -> any-any? + protos) ----
    $agg = @{}
    foreach ($e in $ZoneModel.Edges) {
        $k = "$($e.From)|$($e.To)"
        if (-not $agg.ContainsKey($k)) { $agg[$k] = [pscustomobject]@{ AnyAny=$false; Protos=[System.Collections.Generic.HashSet[string]]::new() } }
        if ($e.AnyAny) { $agg[$k].AnyAny = $true }
        [void]$agg[$k].Protos.Add($e.Proto.ToLowerInvariant())
    }

    $collapse = -not $ExpandAnyAny
    $collapsedSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($cs in @($ZoneModel.CollapsedSources)) { [void]$collapsedSet.Add($cs) }

    $tierRank = @{ Untrusted = 0; DMZ = 1; Trusted = 2 }
    $orderedZones = @($ZoneModel.Zones | Sort-Object @{Expression={$tierRank[$_.Tier]}}, @{Expression={$_.Name}})
    $colNames = @($orderedZones | ForEach-Object { $_.Name })
    if ($ZoneModel.ExternalUsed) { $colNames += 'external' }

    # ---- counts ----
    $real = @($Findings | Where-Object { $_.Status -eq 'finding' })
    $na   = @($Findings | Where-Object { $_.Status -eq 'not-assessed' })
    $high = @($real | Where-Object { $_.Severity -eq 'High' }).Count
    $med  = @($real | Where-Object { $_.Severity -eq 'Medium' }).Count
    $low  = @($real | Where-Object { $_.Severity -eq 'Low' }).Count

    $sb = [System.Text.StringBuilder]::new()
    $w = { param($s) [void]$sb.AppendLine($s) }

    & $w '<!DOCTYPE html>'
    & $w '<html lang="en"><head><meta charset="utf-8">'
    & $w "<title>ASA Review - $(& $esc ([System.IO.Path]::GetFileName($ConfigPath)))</title>"
    & $w @'
<style>
  body{font-family:Segoe UI,Arial,sans-serif;color:#1a1a1a;margin:24px;line-height:1.4}
  h1{font-size:22px;margin:0 0 4px} h2{font-size:17px;border-bottom:2px solid #ccc;padding-bottom:4px;margin-top:28px}
  .meta{color:#555;font-size:13px} .note{background:#f4f6f8;border-left:4px solid #888;padding:8px 12px;font-size:13px;margin:10px 0}
  table{border-collapse:collapse;width:100%;font-size:13px;margin:8px 0} th,td{border:1px solid #bbb;padding:5px 8px;text-align:left;vertical-align:top}
  th{background:#eef1f4} code{font-family:Consolas,monospace;font-size:12px}
  .sev-High{background:#f8d7da} .sev-Medium{background:#fff3cd} .sev-Low{background:#e2e3e5} .sev-na{background:#d1ecf1}
  .pill{display:inline-block;padding:1px 7px;border-radius:9px;font-size:11px;font-weight:700}
  .pill.High{background:#b00000;color:#fff} .pill.Medium{background:#9a6700;color:#fff} .pill.Low{background:#555;color:#fff}
  .cell-risk{background:#f8d7da;font-weight:700} .cell-ok{background:#fff} .matrix td:first-child,.matrix th:first-child{background:#eef1f4;font-weight:700}
  .legend span{display:inline-block;margin-right:14px;font-size:12px}
  .sw{display:inline-block;width:12px;height:12px;vertical-align:middle;margin-right:4px;border:1px solid #999}
  @media print{body{margin:8px} h2{page-break-after:avoid} table{page-break-inside:auto}}
</style></head><body>
'@

    & $w "<h1>Cisco ASA Configuration Review</h1>"
    & $w "<div class='meta'>Configuration: <b>$(& $esc ([System.IO.Path]::GetFileName($ConfigPath)))</b> &middot; Profile: $Profile &middot; Generated: $Timestamp</div>"
    & $w "<div class='meta'>Tool: cisco-asa-review (passive, offline, read-only static analysis; no device contact)</div>"
    if ($RevealSecrets) { & $w "<div class='note'><b>Note:</b> secret values are SHOWN (-RevealSecrets); treat this report as credential-bearing.</div>" }

    & $w "<h2>Executive summary</h2>"
    & $w "<p>Findings: <b>$($real.Count)</b> (High: $high, Medium: $med, Low: $low). Not assessed: $($na.Count). Checks evaluated: $ChecksEvaluated. Config lines parsed: $($Model.LineCount).</p>"
    & $w "<div class='note'>To save as PDF: open this file in any web browser and choose <b>Print &rarr; Save as PDF</b>. No software is required.</div>"

    # ---- findings ----
    & $w "<h2>Findings</h2>"
    if ($Findings.Count -eq 0) {
        & $w "<p>No findings. (Absence of findings is bounded by the implemented check set, not a clean bill of health.)</p>"
    } else {
        & $w "<table><tr><th>Severity</th><th>Check</th><th>Category</th><th>Authority</th><th>Evidence</th><th>Recommendation</th></tr>"
        foreach ($f in $Findings) {
            $sevClass = if ($f.Status -eq 'not-assessed') { 'na' } else { $f.Severity }
            $sevText  = if ($f.Status -eq 'not-assessed') { 'NOT ASSESSED' } else { $f.Severity }
            $pill = if ($f.Status -eq 'not-assessed') { "<span class='pill Low'>N/A</span>" } else { "<span class='pill $($f.Severity)'>$sevText</span>" }
            $ev = if ($f.EvidenceLineNo -gt 0) { "line $($f.EvidenceLineNo): <code>$(& $esc (& $mask $f.Evidence))</code>" } else { "<i>setting absent</i>" }
            & $w "<tr class='sev-$sevClass'><td>$pill</td><td><b>$(& $esc $f.CheckId)</b></td><td>$(& $esc $f.Category)</td><td>$(& $esc $f.Authority)</td><td>$ev</td><td>$(& $esc $f.Remediation)</td></tr>"
        }
        & $w "</table>"
    }

    # ---- segmentation: SVG topology ----
    & $w "<h2>Network segmentation and data flow</h2>"
    & $w "<div class='note'>Best-effort, offline stop-gap. Shows <b>configured/allowed flows per the ruleset</b>, not end-to-end reachability (NAT, routing, and rule shadowing are not modeled). Addresses not within a configured interface subnet are shown as the <b>external</b> zone.</div>"
    & $w "<div class='legend'><span><span class='sw' style='background:#b00000'></span>permit ip any any (high risk)</span><span><span class='sw' style='background:#888'></span>scoped permit</span><span><span class='sw' style='background:#fde2e2;border-color:#b00000'></span>untrusted zone</span></div>"
    if ($collapse -and $collapsedSet.Count -gt 0) {
        & $w "<div class='note'>A zone with a <b>permit ip any any</b> that reaches every other zone is shown with an <b>ANY/ANY to ALL ZONES</b> badge instead of one arrow per destination (de-cluttered by default). The matrix and risk list below remain exhaustive; re-run with <code>-ExpandAnyAny</code> to draw every individual flow.</div>"
    }

    # SVG layout: tier columns x rows
    $boxW = 170; $boxH = 64; $colGap = 90; $rowGap = 28; $margin = 16
    $tiersPresent = @()
    foreach ($tn in 'Untrusted','DMZ','Trusted') { if (@($orderedZones | Where-Object { $_.Tier -eq $tn }).Count) { $tiersPresent += $tn } }
    if ($ZoneModel.ExternalUsed) { $tiersPresent += 'External' }

    $pos = @{}   # zoneName -> @{x,y,cx,cy,col}
    $colOf = @{}
    for ($c = 0; $c -lt $tiersPresent.Count; $c++) { $colOf[$tiersPresent[$c]] = $c }
    $rowCount = @{}
    foreach ($z in $orderedZones) {
        $tier = $z.Tier; $col = $colOf[$tier]
        if (-not $rowCount.ContainsKey($tier)) { $rowCount[$tier] = 0 }
        $row = $rowCount[$tier]; $rowCount[$tier] = $row + 1
        $x = $margin + $col * ($boxW + $colGap); $y = $margin + 24 + $row * ($boxH + $rowGap)
        $pos[$z.Name] = @{ X=$x; Y=$y; CX=($x + $boxW/2); CY=($y + $boxH/2); Col=$col }
    }
    if ($ZoneModel.ExternalUsed) {
        $col = $colOf['External']; $row = 0
        $x = $margin + $col * ($boxW + $colGap); $y = $margin + 24
        $pos['external'] = @{ X=$x; Y=$y; CX=($x + $boxW/2); CY=($y + $boxH/2); Col=$col }
    }
    $maxRows = ($rowCount.Values + 1 | Measure-Object -Maximum).Maximum
    $svgW = $margin + $tiersPresent.Count * ($boxW + $colGap)
    $svgH = $margin + 24 + $maxRows * ($boxH + $rowGap) + 10

    $svg = [System.Text.StringBuilder]::new()
    [void]$svg.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 $svgW $svgH' width='$svgW' height='$svgH' font-family='Segoe UI,Arial,sans-serif'>")
    [void]$svg.AppendLine("<defs><marker id='ah' markerWidth='9' markerHeight='9' refX='8' refY='3' orient='auto'><path d='M0,0 L9,3 L0,6 Z' fill='#666'/></marker><marker id='ahr' markerWidth='10' markerHeight='10' refX='8' refY='3' orient='auto'><path d='M0,0 L9,3 L0,6 Z' fill='#b00000'/></marker></defs>")
    # tier headers
    for ($c = 0; $c -lt $tiersPresent.Count; $c++) {
        $hx = $margin + $c * ($boxW + $colGap) + $boxW/2
        [void]$svg.AppendLine("<text x='$hx' y='14' text-anchor='middle' font-size='12' font-weight='700' fill='#444'>$(& $esc $tiersPresent[$c])</text>")
    }
    # edges first (so boxes draw on top)
    $pairKeys = @($agg.Keys | Sort-Object)
    foreach ($k in $pairKeys) {
        $parts = $k -split '\|'; $f = $parts[0]; $t = $parts[1]
        # collapse any-to-all-zones into a node badge (default) to de-clutter
        if ($collapse -and $agg[$k].AnyAny -and $collapsedSet.Contains($f)) { continue }
        if (-not $pos.ContainsKey($f) -or -not $pos.ContainsKey($t)) { continue }
        $pf = $pos[$f]; $pt = $pos[$t]
        if ($pf.Col -lt $pt.Col) { $x1 = $pf.X + $boxW; $y1 = $pf.CY; $x2 = $pt.X; $y2 = $pt.CY }
        elseif ($pf.Col -gt $pt.Col) { $x1 = $pf.X; $y1 = $pf.CY; $x2 = $pt.X + $boxW; $y2 = $pt.CY }
        else { $x1 = $pf.CX; $y1 = $pf.Y + $boxH; $x2 = $pt.CX; $y2 = $pt.Y }
        if ($agg[$k].AnyAny) { $stroke = '#b00000'; $sw = 3; $m = 'ahr' } else { $stroke = '#888'; $sw = 1.3; $m = 'ah' }
        [void]$svg.AppendLine("<line x1='$([math]::Round($x1))' y1='$([math]::Round($y1))' x2='$([math]::Round($x2))' y2='$([math]::Round($y2))' stroke='$stroke' stroke-width='$sw' marker-end='url(#$m)'/>")
    }
    # zone boxes
    foreach ($z in $orderedZones + @(if ($ZoneModel.ExternalUsed) { [pscustomobject]@{ Name='external'; SecurityLevel=$null; Subnets=@(); IsUntrusted=$false; Tier='External' } } else {})) {
        if (-not $pos.ContainsKey($z.Name)) { continue }
        $p = $pos[$z.Name]
        $fill = if ($z.IsUntrusted) { '#fde2e2' } elseif ($z.Name -eq 'external') { '#eeeeee' } else { '#eef5ff' }
        $strokec = if ($z.IsUntrusted) { '#b00000' } else { '#5b78a8' }
        [void]$svg.AppendLine("<rect x='$($p.X)' y='$($p.Y)' width='$boxW' height='$boxH' rx='6' fill='$fill' stroke='$strokec' stroke-width='1.5'/>")
        $cx = $p.CX
        [void]$svg.AppendLine("<text x='$cx' y='$($p.Y + 22)' text-anchor='middle' font-size='13' font-weight='700' fill='#1a1a1a'>$(& $esc $z.Name)</text>")
        $sub = if ($z.Name -eq 'external') { 'unmapped / off-box' } else { "sl $($z.SecurityLevel)" }
        [void]$svg.AppendLine("<text x='$cx' y='$($p.Y + 39)' text-anchor='middle' font-size='11' fill='#444'>$(& $esc $sub)</text>")
        $cidr = (@($z.Subnets | ForEach-Object { $_.Cidr }) -join ', ')
        if ($cidr) { [void]$svg.AppendLine("<text x='$cx' y='$($p.Y + 55)' text-anchor='middle' font-size='10' fill='#666'>$(& $esc $cidr)</text>") }
        if ($collapse -and $collapsedSet.Contains($z.Name)) {
            $by = $p.Y + $boxH - 9
            [void]$svg.AppendLine("<rect x='$([math]::Round($cx-58))' y='$by' width='116' height='16' rx='8' fill='#b00000'/>")
            [void]$svg.AppendLine("<text x='$cx' y='$($by + 12)' text-anchor='middle' font-size='10' font-weight='700' fill='#ffffff'>ANY/ANY to ALL ZONES</text>")
        }
    }
    [void]$svg.AppendLine('</svg>')
    & $w "<div>$($svg.ToString())</div>"

    # ---- matrix ----
    & $w "<h3>Zone-to-zone connectivity matrix</h3>"
    & $w "<p style='font-size:13px'>Most-permissive configured flow from each source zone (row) to each destination zone (column). Red = <b>permit ip any any</b> exposure.</p>"
    & $w "<table class='matrix'><tr><th>src &rarr; dst</th>$(($colNames | ForEach-Object { "<th>$(& $esc $_)</th>" }) -join '')</tr>"
    foreach ($f in $colNames) {
        $cells = foreach ($t in $colNames) {
            if ($f -eq $t) { "<td class='cell-ok'>-</td>"; continue }
            $k = "$f|$t"
            if (-not $agg.ContainsKey($k)) { "<td class='cell-ok'>-</td>"; continue }
            if ($agg[$k].AnyAny) { "<td class='cell-risk'>ANY-ANY</td>" }
            else { "<td class='cell-ok'>$(& $esc ((@($agg[$k].Protos) | Sort-Object) -join '/'))</td>" }
        }
        & $w "<tr><td>$(& $esc $f)</td>$($cells -join '')</tr>"
    }
    & $w "</table>"

    # ---- risk flows ----
    $riskPairs = @($pairKeys | Where-Object { $agg[$_].AnyAny })
    & $w "<h3>Highlighted risk flows</h3>"
    if ($riskPairs.Count -eq 0) {
        & $w "<p>No permit ip any any inter-zone flows detected (within the implemented checks).</p>"
    } else {
        & $w "<ul>"
        foreach ($k in $riskPairs) {
            $parts = $k -split '\|'
            $line = $ZoneModel.Edges | Where-Object { $_.From -eq $parts[0] -and $_.To -eq $parts[1] -and $_.AnyAny } | Sort-Object LineNo | Select-Object -First 1
            & $w "<li><b>ANY/ANY</b> $(& $esc $parts[0]) &rarr; $(& $esc $parts[1]) (ACL $(& $esc $line.Acl), line $($line.LineNo)): <code>$(& $esc (& $mask $line.Evidence))</code></li>"
        }
        & $w "</ul>"
    }

    & $w "</body></html>"

    Set-Content -LiteralPath $htmlPath -Value $sb.ToString() -Encoding UTF8
    [pscustomobject]@{ HtmlPath = $htmlPath; Html = $sb.ToString() }
}
