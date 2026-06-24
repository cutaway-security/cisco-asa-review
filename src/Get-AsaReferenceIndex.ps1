#Requires -Version 5.1
<#
.SYNOPSIS
    Build a reference index: which ACLs / objects / object-groups are referenced,
    and which are unused (Phase 6 / issue #1, FR-31).
.DESCRIPTION
    "Unused" must mean unreferenced at ANY site, not merely missing an
    access-group: an ACL can be used by a crypto map (match address), a NAT rule,
    a VPN filter, a class-map, etc.; an object/object-group can be used by an ACL,
    NAT, or another group (group-object / network-object object). Checking only
    one site would false-positive (e.g., a crypto-only ACL).

    Approach: an entity is REFERENCED if its name appears as a whole token on any
    line that is not one of its own definition lines. This is deliberately
    conservative -- it prefers NOT flagging (under-flagging unused is the safe
    direction; we never wrongly tell an analyst to delete something in use).
    Findings built on this are Informational and analyst-reviewed.
.OUTPUTS
    [pscustomobject] UnusedAcls / UnusedObjects / UnusedObjectGroups, each a list
    of @{ Name; Node } for the unused entity (Node = an evidence node).
#>
function Get-AsaReferenceIndex {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [pscustomobject]$Model
    )

    process {
        # Per-line token sets (whitespace split), for 'line' nodes only.
        $lineTokens = [System.Collections.Generic.List[object]]::new()
        foreach ($n in $Model.Lines) {
            if ($n.Kind -ne 'line') { continue }
            $set = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($t in ($n.Text -split '\s+')) { if ($t) { [void]$set.Add($t) } }
            $lineTokens.Add([pscustomobject]@{ Node = $n; Tokens = $set })
        }

        # Is $name referenced anywhere outside a definition line of $defKind?
        $isReferenced = {
            param([string]$name, [string]$defKind)
            $escaped = [regex]::Escape($name)
            $defRx = switch ($defKind) {
                'acl' { "^access-list\s+$escaped(\s|$)" }
                'obj' { "^object\s+(network|service)\s+$escaped(\s|$)" }
                'og'  { "^object-group\s+(network|service|protocol)\s+$escaped(\s|$)" }
            }
            foreach ($lt in $lineTokens) {
                if (-not $lt.Tokens.Contains($name)) { continue }
                if ($lt.Node.Text -notmatch $defRx) { return $true }   # a non-definition use
            }
            return $false
        }

        $unusedAcls = [System.Collections.Generic.List[object]]::new()
        foreach ($name in $Model.AccessLists.Keys) {
            if (-not (& $isReferenced $name 'acl')) {
                $unusedAcls.Add([pscustomobject]@{ Name = $name; Node = ($Model.AccessLists[$name] | Select-Object -First 1) })
            }
        }

        $unusedObjects = [System.Collections.Generic.List[object]]::new()
        foreach ($name in $Model.Objects.Keys) {
            if (-not (& $isReferenced $name 'obj')) {
                $unusedObjects.Add([pscustomobject]@{ Name = $name; Node = $Model.Objects[$name] })
            }
        }

        $unusedGroups = [System.Collections.Generic.List[object]]::new()
        foreach ($name in $Model.ObjectGroups.Keys) {
            if (-not (& $isReferenced $name 'og')) {
                $unusedGroups.Add([pscustomobject]@{ Name = $name; Node = $Model.ObjectGroups[$name] })
            }
        }

        [pscustomobject]@{
            UnusedAcls         = @($unusedAcls)
            UnusedObjects      = @($unusedObjects)
            UnusedObjectGroups = @($unusedGroups)
        }
    }
}
