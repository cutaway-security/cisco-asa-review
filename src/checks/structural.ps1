#Requires -Version 5.1
<#
.SYNOPSIS
    Structural (code) detectors for checks that cannot be expressed as catalog
    patterns (REQUIREMENTS AR-05). Each returns a uniform detection result:
        @{ Fired = [bool]; Status = 'finding'|'not-assessed'; Evidence = @(nodes...) }
    consumed by Invoke-AsaChecks. These depend on the support models
    (Resolve-AsaReferences for object-group resolution).
#>

function New-AsaDetection {
    param([bool]$Fired, [string]$Status = 'finding', $Evidence = @())
    [pscustomobject]@{ Fired = $Fired; Status = $Status; Evidence = @($Evidence) }
}

function Test-AsaConsoleTimeout {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)
    $line = $Model.Lines | Where-Object { $_.Kind -eq 'line' -and $_.Text -match '^console timeout\s+(\d+)\b' } | Select-Object -First 1
    if ($null -eq $line) {
        # Absent: ASA default console timeout is 0 (no timeout) -- a finding.
        return New-AsaDetection -Fired $true -Evidence @()
    }
    [void]($line.Text -match '^console timeout\s+(\d+)\b')
    $val = [int]$Matches[1]
    if ($val -eq 0 -or $val -gt 5) { return New-AsaDetection -Fired $true -Evidence @($line) }
    return New-AsaDetection -Fired $false
}

function Test-AsaSnmpCommunity {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)
    $ev = $Model.Lines | Where-Object {
        $_.Kind -eq 'line' -and (
            $_.Text -match '^snmp-server community\s+\S+' -or
            ($_.Text -match '^snmp-server host\b' -and ($_.Text -match '\bcommunity\s+\S+' -or $_.Text -match '\bversion\s+(1|2c)\b'))
        )
    }
    if ($ev.Count -gt 0) { return New-AsaDetection -Fired $true -Evidence $ev }
    return New-AsaDetection -Fired $false
}

function Test-AsaNtpAuth {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)
    $servers = $Model.Lines | Where-Object { $_.Kind -eq 'line' -and $_.Text -match '^ntp server\b' }
    $authOn  = $Model.Lines | Where-Object { $_.Kind -eq 'line' -and $_.Text -match '^ntp authenticate\b' }
    if ($servers.Count -gt 0 -and $authOn.Count -eq 0) {
        return New-AsaDetection -Fired $true -Evidence $servers
    }
    return New-AsaDetection -Fired $false
}

function Test-AsaAclAnyAny {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)

    # Consume one address element (any | host X | object X | object-group X | IP MASK)
    # from a token array. Returns $true/$false/'not-assessed' and advances [ref]idx.
    $consume = {
        param([string[]]$tok, [ref]$idx)
        $i = $idx.Value
        if ($i -ge $tok.Count) { $idx.Value = $i; return $false }
        switch -Regex ($tok[$i]) {
            '^any$'          { $idx.Value = $i + 1; return $true }
            '^host$'         { $idx.Value = $i + 2; return $false }
            '^object$'       { $idx.Value = $i + 2; return $false }
            '^object-group$' {
                $name = if ($i + 1 -lt $tok.Count) { $tok[$i + 1] } else { '' }
                $idx.Value = $i + 2
                return (Test-AsaNetworkGroupIsAny -Model $Model -Name $name)
            }
            '^interface$'    { $idx.Value = $i + 2; return $false }
            default          { $idx.Value = $i + 2; return ($tok[$i] -eq '0.0.0.0' -and ($i + 1 -lt $tok.Count) -and $tok[$i + 1] -eq '0.0.0.0') }
        }
    }

    $anyAny = [System.Collections.Generic.List[object]]::new()
    $notAssessed = [System.Collections.Generic.List[object]]::new()

    foreach ($aclName in $Model.AccessLists.Keys) {
        foreach ($ace in $Model.AccessLists[$aclName]) {
            if ($ace.Text -notmatch '^access-list\s+\S+\s+(?:line\s+\d+\s+)?extended\s+permit\s+ip\s+(.+)$') { continue }
            $rest = $Matches[1].Trim() -split '\s+'
            $idx = 0
            $src = & $consume $rest ([ref]$idx)
            $dst = & $consume $rest ([ref]$idx)

            if ($src -eq $false -or $dst -eq $false) { continue }                 # definitely not any-any
            elseif ($src -eq $true -and $dst -eq $true) { $anyAny.Add($ace) }     # confirmed any-any
            else { $notAssessed.Add($ace) }                                       # group too deep (OR-03)
        }
    }

    if ($anyAny.Count -gt 0)      { return New-AsaDetection -Fired $true -Status 'finding' -Evidence $anyAny }
    if ($notAssessed.Count -gt 0) { return New-AsaDetection -Fired $true -Status 'not-assessed' -Evidence $notAssessed }
    return New-AsaDetection -Fired $false
}

# --- Phase 6 / issue #1 hygiene detectors (Informational; may return MANY) ---

function Test-AsaUnusedAcl {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)
    if (-not (Get-Command -Name Get-AsaReferenceIndex -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '..\Get-AsaReferenceIndex.ps1') }
    $ref = Get-AsaReferenceIndex -Model $Model
    $out = foreach ($u in $ref.UnusedAcls) { New-AsaDetection -Fired $true -Evidence @($u.Node) }
    return @($out)
}

function Test-AsaUnusedObject {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)
    if (-not (Get-Command -Name Get-AsaReferenceIndex -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '..\Get-AsaReferenceIndex.ps1') }
    $ref = Get-AsaReferenceIndex -Model $Model
    $out = foreach ($u in (@($ref.UnusedObjects) + @($ref.UnusedObjectGroups))) { New-AsaDetection -Fired $true -Evidence @($u.Node) }
    return @($out)
}

function Test-AsaInactiveRules {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)
    # expired time-ranges
    $expired = @{}
    $now = Get-Date
    foreach ($n in $Model.Lines) {
        if ($n.Kind -ne 'line' -or $n.Text -notmatch '^time-range\s+(\S+)') { continue }
        $trName = $Matches[1]
        foreach ($c in $n.Children) {
            if ($c.Text -match '^absolute end\s+(\d{1,2}):(\d{2})\s+(\d{1,2})\s+(\w+)\s+(\d{4})') {
                try {
                    $end = [datetime]::Parse("$($Matches[3]) $($Matches[4]) $($Matches[5]) $($Matches[1]):$($Matches[2])", [System.Globalization.CultureInfo]::InvariantCulture)
                    if ($end -lt $now) { $expired[$trName] = $true }
                } catch { }
            }
        }
    }
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($name in $Model.AccessLists.Keys) {
        foreach ($ace in $Model.AccessLists[$name]) {
            if ($ace.Text -match '\binactive\b') { $out.Add((New-AsaDetection -Fired $true -Evidence @($ace))); continue }
            if ($ace.Text -match '\btime-range\s+(\S+)' -and $expired.ContainsKey($Matches[1])) { $out.Add((New-AsaDetection -Fired $true -Evidence @($ace))) }
        }
    }
    return @($out)
}

function Test-AsaInterfaceNoIp {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($if in $Model.Interfaces) {
        $hasIp   = [bool](@($if.Children | Where-Object { $_.Text -match '^ip address\s+\d' }).Count)
        $isShut  = [bool](@($if.Children | Where-Object { $_.Text -eq 'shutdown' }).Count)
        $isBridge = [bool](@($if.Children | Where-Object { $_.Text -match '^bridge-group\s+\d' }).Count)
        # bridge-group members legitimately have no IP (the BVI holds it) -> skip
        if (-not $hasIp -and -not $isShut -and -not $isBridge) { $out.Add((New-AsaDetection -Fired $true -Evidence @($if))) }
    }
    return @($out)
}

function Test-AsaBvi {
    [CmdletBinding()] param([Parameter(Mandatory)][pscustomobject]$Model)
    $usedGroups = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($n in $Model.Lines) {
        if ($n.Kind -eq 'line' -and $n.Text -match '^bridge-group\s+(\d+)') { [void]$usedGroups.Add($Matches[1]) }
    }
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($if in $Model.Interfaces) {
        if ($if.Text -match '^interface\s+BVI(\d+)') {
            if (-not $usedGroups.Contains($Matches[1])) { $out.Add((New-AsaDetection -Fired $true -Evidence @($if))) }
        }
    }
    return @($out)
}
