#Requires -Version 5.1
<#
.SYNOPSIS
    Derive a network-segmentation zone model and inter-zone allowed-flow edges
    from a parsed ASA model (Phase 5, FR-20..FR-22).
.DESCRIPTION
    Best-effort, stop-gap segmentation derivation -- NOT a commercial-grade
    reachability engine. Zones are in-service interfaces (nameif + effective
    security-level, via the interface-role model). Edges are CONFIGURED/ALLOWED
    flows from the permit ACEs of ACLs bound to interfaces by access-group; they
    are not end-to-end reachability (no routing, NAT translation, or cross-path
    rule-order/shadowing is modeled -- OOS-02).

    Address-to-zone mapping is by longest-prefix match against interface subnets:
      - 'any' (or a 0.0.0.0/0 object-group) spans ALL zones
      - an address inside an interface subnet maps to that zone
      - anything not mappable maps to the explicit 'external' zone (never dropped)
      - object/object-group references resolved via Resolve-AsaReferences;
        resolution deeper than the supported depth is marked unknown (OR-03)

    Known gaps (documented in the output): NAT is not followed; routed/off-box
    subnets surface as 'external'; inbound ACEs attribute the source side to the
    bound interface's zone.
.OUTPUTS
    [pscustomobject] Zones, Edges, Tiers, plus Notes (gaps), Bindings.
#>
function Get-AsaZoneModel {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [pscustomobject]$Model
    )

    begin {
        foreach ($fn in 'Get-AsaInterfaceRoles','Resolve-AsaNetworkGroup','Test-AsaNetworkGroupIsAny') {
            if (-not (Get-Command -Name $fn -ErrorAction SilentlyContinue)) {
                . (Join-Path $PSScriptRoot 'Get-AsaInterfaceRoles.ps1')
                . (Join-Path $PSScriptRoot 'Resolve-AsaReferences.ps1')
                break
            }
        }
    }

    process {
        # --- IP helpers (uint32 math; no network access) ---
        $ipToU = {
            param([string]$ip)
            if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $null }
            $o = $ip.Split('.') | ForEach-Object { [uint32]$_ }
            ($o[0] -shl 24) -bor ($o[1] -shl 16) -bor ($o[2] -shl 8) -bor $o[3]
        }
        $maskToPrefix = {
            param([uint32]$m)
            $c = 0; for ($b = 0; $b -lt 32; $b++) { if (($m -shr (31 - $b)) -band 1) { $c++ } else { break } }
            $c
        }

        # --- zones from in-service interfaces ---
        $roles = @(Get-AsaInterfaceRoles -Model $Model | Where-Object { $_.InService })
        $zones = [System.Collections.Generic.List[object]]::new()
        foreach ($r in $roles) {
            $subnets = [System.Collections.Generic.List[object]]::new()
            foreach ($c in $r.Node.Children) {
                if ($c.Text -match '^ip address\s+(\d{1,3}(?:\.\d{1,3}){3})\s+(\d{1,3}(?:\.\d{1,3}){3})') {
                    $ipU = & $ipToU $Matches[1]; $mU = & $ipToU $Matches[2]
                    if ($null -ne $ipU -and $null -ne $mU) {
                        $subnets.Add([pscustomobject]@{
                            Net = ($ipU -band $mU); Mask = $mU; Prefix = (& $maskToPrefix $mU)
                            Cidr = ('{0}/{1}' -f ($Matches[1] -replace '\.\d+$', '.0'), (& $maskToPrefix $mU))
                        })
                    }
                }
            }
            $tier = if ($r.SecurityLevel -eq 0) { 'Untrusted' } elseif ($r.SecurityLevel -ge 100) { 'Trusted' } else { 'DMZ' }
            $zones.Add([pscustomobject]@{
                Name = $r.Nameif; SecurityLevel = $r.SecurityLevel; Interface = $r.Interface
                IsUntrusted = $r.IsUntrusted; Tier = $tier; Subnets = $subnets
            })
        }
        $zoneNames = @($zones | ForEach-Object { $_.Name })

        # --- address descriptor -> set of zone names (or ALL / external / unknown) ---
        $mapIp = {
            param([uint32]$addr)
            $best = $null; $bestPrefix = -1
            foreach ($z in $zones) {
                foreach ($s in $z.Subnets) {
                    if ((($addr -band $s.Mask) -eq $s.Net) -and $s.Prefix -gt $bestPrefix) { $best = $z.Name; $bestPrefix = $s.Prefix }
                }
            }
            if ($best) { $best } else { 'external' }
        }
        # returns @{ All=$bool; Unknown=$bool; Zones=[set] }
        $mapDesc = {
            param([string]$kind, [string]$a, [string]$b)
            switch ($kind) {
                'any'    { return @{ All = $true; Unknown = $false; Zones = @() } }
                'host'   { $u = & $ipToU $a; if ($null -eq $u) { return @{All=$false;Unknown=$true;Zones=@()} }; return @{ All = $false; Unknown = $false; Zones = @(& $mapIp $u) } }
                'subnet' {
                    $u = & $ipToU $a; $m = & $ipToU $b
                    if ($null -eq $u -or $null -eq $m) { return @{All=$false;Unknown=$true;Zones=@()} }
                    if ($m -eq 0) { return @{ All = $true; Unknown = $false; Zones = @() } }
                    return @{ All = $false; Unknown = $false; Zones = @(& $mapIp $u) }
                }
                'object' {
                    if ($Model.Objects.ContainsKey($a)) {
                        foreach ($c in $Model.Objects[$a].Children) {
                            if ($c.Text -match '^host\s+(\S+)')            { return (& $mapDesc 'host' $Matches[1] $null) }
                            if ($c.Text -match '^subnet\s+(\S+)\s+(\S+)')  { return (& $mapDesc 'subnet' $Matches[1] $Matches[2]) }
                            if ($c.Text -match '^range\s+(\S+)\s+\S+')     { return (& $mapDesc 'host' $Matches[1] $null) }
                        }
                    }
                    return @{ All = $false; Unknown = $true; Zones = @() }
                }
                'object-group' {
                    $isAny = Test-AsaNetworkGroupIsAny -Model $Model -Name $a
                    # NB: keep the type test first. '$isAny -eq ''not-assessed''' with a
                    # [bool] on the left coerces the string to $true and misfires.
                    if ($isAny -isnot [bool]) { return @{ All = $false; Unknown = $true; Zones = @() } }
                    if ($isAny) { return @{ All = $true; Unknown = $false; Zones = @() } }
                    $r = Resolve-AsaNetworkGroup -Model $Model -Name $a
                    $set = [System.Collections.Generic.HashSet[string]]::new()
                    foreach ($mem in $r.Members) {
                        if ($mem -match '^host\s+(\S+)')           { (& $mapDesc 'host' $Matches[1] $null).Zones | ForEach-Object { [void]$set.Add($_) } }
                        elseif ($mem -match '^object\s+(\S+)')     { (& $mapDesc 'object' $Matches[1] $null).Zones | ForEach-Object { [void]$set.Add($_) } }
                        elseif ($mem -match '^(\S+)\s+(\S+)$')     { (& $mapDesc 'subnet' $Matches[1] $Matches[2]).Zones | ForEach-Object { [void]$set.Add($_) } }
                    }
                    if (-not $r.Assessed) { return @{ All = $false; Unknown = $true; Zones = @($set) } }
                    return @{ All = $false; Unknown = $false; Zones = @($set) }
                }
                default { return @{ All = $false; Unknown = $true; Zones = @() } }
            }
        }

        # consume one address element from a token array; returns descriptor + advances idx
        $consume = {
            param([string[]]$tok, [ref]$idx)
            $i = $idx.Value
            if ($i -ge $tok.Count) { $idx.Value = $i; return @{ Kind = 'any'; A = $null; B = $null } }
            switch -Regex ($tok[$i]) {
                '^any$'          { $idx.Value = $i + 1; return @{ Kind = 'any'; A = $null; B = $null } }
                '^host$'         { $idx.Value = $i + 2; return @{ Kind = 'host'; A = $tok[$i+1]; B = $null } }
                '^object$'       { $idx.Value = $i + 2; return @{ Kind = 'object'; A = $tok[$i+1]; B = $null } }
                '^object-group$' { $idx.Value = $i + 2; return @{ Kind = 'object-group'; A = $tok[$i+1]; B = $null } }
                '^interface$'    { $idx.Value = $i + 2; return @{ Kind = 'object'; A = $tok[$i+1]; B = $null } }
                default          { $idx.Value = $i + 2; return @{ Kind = 'subnet'; A = $tok[$i]; B = $tok[$i+1] } }
            }
        }

        # --- access-group bindings: acl -> (iface, direction) ---
        $bindings = [System.Collections.Generic.List[object]]::new()
        foreach ($ag in $Model.AccessGroups) {
            if ($ag.Text -match '^access-group\s+(\S+)\s+(in|out)\s+interface\s+(\S+)') {
                $bindings.Add([pscustomobject]@{ Acl = $Matches[1]; Dir = $Matches[2]; Interface = $Matches[3] })
            }
            elseif ($ag.Text -match '^access-group\s+(\S+)\s+global') {
                $bindings.Add([pscustomobject]@{ Acl = $Matches[1]; Dir = 'global'; Interface = $null })
            }
        }
        # interface (hw or nameif) -> zone name
        $ifaceToZone = @{}
        foreach ($z in $zones) { $ifaceToZone[$z.Name] = $z.Name; $ifaceToZone[$z.Interface] = $z.Name }

        $expand = {
            param($desc, [string]$selfZone)
            if ($desc.All)     { return @($zoneNames + 'external') }
            if ($desc.Unknown) { return @('external') }
            $z = @($desc.Zones | Where-Object { $_ })
            if ($z.Count -eq 0) { return @('external') }
            return $z
        }

        # --- build edges ---
        $edges = [System.Collections.Generic.List[object]]::new()
        foreach ($bnd in $bindings) {
            if (-not $Model.AccessLists.ContainsKey($bnd.Acl)) { continue }
            $zb = if ($bnd.Interface -and $ifaceToZone.ContainsKey($bnd.Interface)) { $ifaceToZone[$bnd.Interface] } else { $null }

            foreach ($ace in $Model.AccessLists[$bnd.Acl]) {
                if ($ace.Text -notmatch '^access-list\s+\S+\s+(?:line\s+\d+\s+)?extended\s+permit\s+(\S+)\s+(.+)$') { continue }
                $proto = $Matches[1]
                $rest = $Matches[2].Trim() -split '\s+'
                $idx = 0
                $srcD = & $consume $rest ([ref]$idx)
                $dstD = & $consume $rest ([ref]$idx)
                $src = & $mapDesc $srcD.Kind $srcD.A $srcD.B
                $dst = & $mapDesc $dstD.Kind $dstD.A $dstD.B
                $anyAny = ($proto -ieq 'ip' -and $src.All -and $dst.All)

                switch ($bnd.Dir) {
                    'in'     { $fromSet = @($zb); $toSet = (& $expand $dst $zb) }
                    'out'    { $fromSet = (& $expand $src $zb); $toSet = @($zb) }
                    'global' { $fromSet = (& $expand $src $null); $toSet = (& $expand $dst $null) }
                }
                $fromSet = @($fromSet | Where-Object { $_ })
                foreach ($f in $fromSet) {
                    foreach ($t in $toSet) {
                        if ($f -eq $t) { continue }
                        $edges.Add([pscustomobject]@{
                            From = $f; To = $t; Proto = $proto; AnyAny = $anyAny
                            Acl = $bnd.Acl; Dir = $bnd.Dir; LineNo = $ace.LineNo
                            Severity = $(if ($anyAny) { 'High' } else { 'Low' })
                            Evidence = $ace.Text
                        })
                    }
                }
            }
        }

        # --- collapse: sources whose ANY/ANY fans out to ALL other zones ---
        # (used to de-clutter topology diagrams by default; the matrix and risk
        # list always remain exhaustive).
        $targetUniverse = @($zoneNames)
        if ($edges | Where-Object { $_.From -eq 'external' -or $_.To -eq 'external' }) { $targetUniverse += 'external' }
        $anyAnyDest = @{}
        foreach ($e in $edges) {
            if (-not $e.AnyAny) { continue }
            if (-not $anyAnyDest.ContainsKey($e.From)) { $anyAnyDest[$e.From] = [System.Collections.Generic.HashSet[string]]::new() }
            [void]$anyAnyDest[$e.From].Add($e.To)
        }
        $collapsed = [System.Collections.Generic.List[string]]::new()
        foreach ($srcName in $anyAnyDest.Keys) {
            $dests = $anyAnyDest[$srcName]
            $others = @($targetUniverse | Where-Object { $_ -ne $srcName })
            if ($dests.Count -ge 2 -and ($others.Count -gt 0) -and -not (@($others | Where-Object { -not $dests.Contains($_) }))) {
                [void]$collapsed.Add($srcName)
            }
        }

        $notes = @(
            'Edges are CONFIGURED/ALLOWED flows from access-group-bound permit ACEs, not end-to-end reachability.',
            'NAT translation, routing, and cross-path rule order/shadowing are NOT modeled.',
            'Addresses not within a configured interface subnet are shown as the external zone.',
            'Best-effort stop-gap: gaps are expected; this is not a commercial segmentation tool.'
        )

        [pscustomobject]@{
            Zones        = $zones
            ZoneNames    = $zoneNames
            Edges        = $edges
            Bindings     = $bindings
            ExternalUsed = [bool](@($edges | Where-Object { $_.From -eq 'external' -or $_.To -eq 'external' }).Count)
            CollapsedSources = @($collapsed)
            Notes        = $notes
        }
    }
}
