#Requires -Version 5.1
<#
.SYNOPSIS
    Build the shared interface-role model (nameif + security-level per interface).
.DESCRIPTION
    v0.1b-prep shared subsystem (REQUIREMENTS FR-08a, ARCHITECTURE section 5).
    Several context-conditional checks (uRPF, no-SSH-on-outside,
    outside-security-level-0) need to know which interfaces are untrusted. This
    model is designed once and consumed by all of them, rather than re-derived
    per check.

    Encodes the ASA security-level default: when an interface has a nameif but no
    explicit security-level, the level defaults to 100 for nameif 'inside' and 0
    for any other name. An interface with no nameif is not in service.

    Untrusted rule (the formalized uRPF condition): an interface is untrusted if
    its (effective) security-level is 0 OR its nameif is 'outside'.
.OUTPUTS
    [pscustomobject] one per interface: Interface, Nameif, SecurityLevel,
    SecurityLevelExplicit, IsShutdown, InService, IsUntrusted, Node.
.EXAMPLE
    $roles = ConvertTo-AsaModel -Path .\asa.txt | Get-AsaInterfaceRoles
    $roles | Where-Object IsUntrusted
#>
function Get-AsaInterfaceRoles {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [pscustomobject]$Model
    )

    process {
        $roles = [System.Collections.Generic.List[object]]::new()

        foreach ($if in $Model.Interfaces) {
            $hw = ($if.Text -replace '^interface\s+', '')
            $nameif = $null
            $secExplicit = $null
            $shutdown = $false

            foreach ($c in $if.Children) {
                if ($c.Text -match '^nameif\s+(\S+)')         { $nameif = $Matches[1] }
                elseif ($c.Text -match '^security-level\s+(\d+)') { $secExplicit = [int]$Matches[1] }
                elseif ($c.Text -eq 'shutdown')               { $shutdown = $true }
            }

            $inService = ($null -ne $nameif -and -not $shutdown)

            # Effective security level: explicit wins; else the ASA default.
            $secLevel = $secExplicit
            if ($null -eq $secLevel -and $null -ne $nameif) {
                $secLevel = if ($nameif -ieq 'inside') { 100 } else { 0 }
            }

            $isUntrusted = $false
            if ($inService) {
                $isUntrusted = ($secLevel -eq 0) -or ($nameif -ieq 'outside')
            }

            $roles.Add([pscustomobject]@{
                Interface             = $hw
                Nameif                = $nameif
                SecurityLevel         = $secLevel
                SecurityLevelExplicit = ($null -ne $secExplicit)
                IsShutdown            = $shutdown
                InService             = $inService
                IsUntrusted           = $isUntrusted
                Node                  = $if
            })
        }

        Write-Output $roles.ToArray()
    }
}
