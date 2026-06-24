#Requires -Version 5.1
<#
.SYNOPSIS
    Minimal name / object / object-group resolution (v0.1b minimal scope, FR-05a).
.DESCRIPTION
    Resolves only as much as the MVP-15 checks need -- specifically, whether a
    network object-group is functionally "any" (spans 0.0.0.0/0), which the
    ACL-ANY-ANY check needs to catch an object-group-expressed permit ip any any.

    Stated resolution depth: ONE level of group-object expansion. A group-object
    whose own definition contains a further group-object exceeds that depth and
    is reported "not assessed" (Assessed = $false, OR-03) rather than silently
    treated as not-any -- under-flagging is a false negative the zero-FP gate
    cannot catch (ARCHITECTURE section 3, second multi-AI pass). Deep recursive
    resolution is v0.2 (FR-05b).
.EXAMPLE
    $m = ConvertTo-AsaModel -Path .\asa.txt
    Resolve-AsaNetworkGroup -Model $m -Name 'any-net'      # ContainsAny = $true
#>

function Resolve-AsaName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][pscustomobject]$Model,
        [Parameter(Mandatory)][string]$Token
    )
    if ($Model.Names.BySymbol.ContainsKey($Token)) { return $Model.Names.BySymbol[$Token] }
    return $Token
}

function Resolve-AsaNetworkGroup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][pscustomobject]$Model,
        [Parameter(Mandatory)][string]$Name,
        [ValidateRange(0, 8)][int]$MaxGroupDepth = 1
    )

    $members = [System.Collections.Generic.List[string]]::new()
    $state = @{ ContainsAny = $false; Assessed = $true }

    $expand = {
        param($groupName, $depth)

        $node = $null
        if ($Model.ObjectGroups.ContainsKey($groupName)) { $node = $Model.ObjectGroups[$groupName] }
        if ($null -eq $node) { $state.Assessed = $false; return }   # undefined reference: cannot assess

        foreach ($c in $node.Children) {
            $ct = $c.Text
            if ($ct -match '^network-object\s+0\.0\.0\.0\s+0\.0\.0\.0\b') {
                $state.ContainsAny = $true
                $members.Add('any')
            }
            elseif ($ct -match '^network-object\s+host\s+(\S+)') { $members.Add("host $($Matches[1])") }
            elseif ($ct -match '^network-object\s+object\s+(\S+)') { $members.Add("object $($Matches[1])") }
            elseif ($ct -match '^network-object\s+(\S+)\s+(\S+)')   { $members.Add("$($Matches[1]) $($Matches[2])") }
            elseif ($ct -match '^group-object\s+(\S+)') {
                if ($depth + 1 -gt $MaxGroupDepth) {
                    $state.Assessed = $false      # deeper than stated depth -> not assessed (OR-03)
                }
                else {
                    & $expand $Matches[1] ($depth + 1)
                }
            }
        }
    }

    $found = $Model.ObjectGroups.ContainsKey($Name)
    if ($found) { & $expand $Name 0 }
    else { $state.Assessed = $false }

    [pscustomobject]@{
        Name        = $Name
        Found       = $found
        ContainsAny = $state.ContainsAny
        Assessed    = $state.Assessed
        Members     = $members
    }
}

function Test-AsaNetworkGroupIsAny {
    <#
    .SYNOPSIS
        Returns $true / $false / 'not-assessed' for whether a network group spans any.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Model,
        [Parameter(Mandatory)][string]$Name
    )
    $r = Resolve-AsaNetworkGroup -Model $Model -Name $Name
    if (-not $r.Assessed) { return 'not-assessed' }
    return [bool]$r.ContainsAny
}
