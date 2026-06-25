#Requires -Version 5.1
<#
.SYNOPSIS
    Generate a large, syntactically faithful ASA running-config for the NFR-04
    scaling benchmark. NOT a fixture (not committed as data): it is produced on
    demand, in memory, by the perf harness. Deterministic for a given LineCount.
.DESCRIPTION
    Emits the construct mix that drives the parser's and reference index's hot
    paths on real large configs: many `object network` host objects, nested
    `object-group network` members, and `access-list` lines that reference those
    objects (so the "referenced-anywhere" scan has real work to do). Offline,
    pure text, no network.
.PARAMETER LineCount
    Approximate number of lines to emit (the generator stops once the target is
    reached, so the result is within a few lines of the request).
.OUTPUTS
    [string[]] the config lines, as Read-AsaConfig would return them.
#>
function New-AsaLargeConfig {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [ValidateRange(100, 2000000)]
        [int]$LineCount = 20000
    )

    $L = [System.Collections.Generic.List[string]]::new($LineCount + 64)

    # ---- Prologue (fixed) ----------------------------------------------------
    $L.Add(': Saved')
    $L.Add(': Hardware:   ASA5515, 8192 MB RAM, CPU Clarkdale 3060 MHz')
    $L.Add('ASA Version 9.8(4)')
    $L.Add('hostname perf-asa')
    $L.Add('!')
    foreach ($if in @(
        @{ N = 'GigabitEthernet0/0'; Name = 'outside'; Sec = 0;   Ip = '203.0.113.2' },
        @{ N = 'GigabitEthernet0/1'; Name = 'inside';  Sec = 100; Ip = '10.10.0.1' },
        @{ N = 'GigabitEthernet0/2'; Name = 'dmz';     Sec = 50;  Ip = '10.20.0.1' })) {
        $L.Add("interface $($if.N)")
        $L.Add(" nameif $($if.Name)")
        $L.Add(" security-level $($if.Sec)")
        $L.Add(" ip address $($if.Ip) 255.255.255.0")
        $L.Add('!')
    }
    # A baseline of management/logging so checks have something real to chew on.
    $L.Add('logging enable')
    $L.Add('logging buffered informational')
    $L.Add('ssh version 2')
    $L.Add('ssh 10.10.0.0 255.255.255.0 inside')
    $L.Add('!')

    # ---- Bulk: objects + groups + ACL rules that reference them --------------
    # Each iteration emits a host object (2 lines) and an ACL rule that uses it
    # (1 line); every 8th iteration also emits an object-group of 8 members.
    $i = 0
    while ($L.Count -lt $LineCount) {
        $i++
        # Deterministic, non-overlapping host address from the counter.
        $a = 10 + (($i -shr 16) -band 0xFF)
        $b = ($i -shr 8) -band 0xFF
        $c = $i -band 0xFF
        $name = ('HOST-{0:D6}' -f $i)

        $L.Add("object network $name")
        $L.Add(" host $a.$b.$c.10")

        if (($i % 8) -eq 0 -and $L.Count -lt ($LineCount - 12)) {
            $g = ('GRP-{0:D6}' -f $i)
            $L.Add("object-group network $g")
            for ($k = 0; $k -lt 8; $k++) {
                $member = ('HOST-{0:D6}' -f ([math]::Max(1, $i - $k)))
                $L.Add(" network-object object $member")
            }
            $L.Add("access-list OUTSIDE-IN extended permit ip object-group $g any")
        }

        $L.Add("access-list OUTSIDE-IN extended permit ip object $name any")
        if (($i % 50) -eq 0) { $L.Add('!') }
    }

    # ---- Epilogue ------------------------------------------------------------
    $L.Add('access-group OUTSIDE-IN in interface outside')

    return , $L.ToArray()
}
