#Requires -Version 5.1
<#
.SYNOPSIS
    NFR-04 scaling benchmark: measure parse + full-pipeline time across config
    sizes and report whether scaling is sub-quadratic (no quadratic blowup).
.DESCRIPTION
    Generates synthetic ASA configs at several sizes (default up to ~20,000
    lines), times the parser (ConvertTo-AsaModel) and the full review pipeline
    (parse + reference index + zone model + checks), and computes the empirical
    growth exponent from a log-log fit plus the doubling factor between the two
    largest sizes. Linear work doubles per 2x lines (factor ~2, exponent ~1);
    quadratic work quadruples (factor ~4, exponent ~2).

    Offline, read-only, no network. Prints a table to the information stream and
    returns/exits 0 if scaling is sub-quadratic, 1 otherwise.
.PARAMETER Sizes
    Line counts to benchmark. Default 2500, 5000, 10000, 20000.
.PARAMETER MaxExponent
    Fail threshold for the fitted growth exponent. Default 1.5 (linear = 1.0;
    a clean quadratic = 2.0). Generous to absorb timer noise and fixed overhead.
.PARAMETER MaxDoubleFactor
    Fail threshold for the time ratio between the two largest sizes (which double
    in line count). Linear work yields ~2.0, quadratic ~4.0. Default 2.6. This is
    the more sensitive test: a log-log fit over a range that includes the
    pre-quadratic regime can read low even when the tail is quadratic.
.PARAMETER Quiet
    Suppress the per-size table (still returns the verdict object).
.OUTPUTS
    [pscustomobject] with the measurements and the PASS/FAIL verdict.
#>
[CmdletBinding()]
param(
    [int[]]$Sizes = @(2500, 5000, 10000, 20000),
    [double]$MaxExponent = 1.5,
    [double]$MaxDoubleFactor = 2.6,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$src  = Join-Path $here '..\..\src'

. (Join-Path $here 'New-AsaLargeConfig.ps1')
foreach ($f in 'Read-AsaConfig', 'ConvertTo-AsaModel', 'Get-AsaInterfaceRoles', 'Resolve-AsaReferences',
               'Get-AsaSecrets', 'Get-AsaReferenceIndex', 'Invoke-AsaChecks', 'Get-AsaZoneModel') {
    . (Join-Path $src "$f.ps1")
}
. (Join-Path $src 'checks\structural.ps1')

function Measure-Ms {
    param([scriptblock]$Action)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Action | Out-Null
    $sw.Stop()
    return $sw.Elapsed.TotalMilliseconds
}

# Warm up: JIT the compiled regexes and the pipeline once so the first timed
# size is not penalized by one-time costs.
$warm = New-AsaLargeConfig -LineCount 1000
$null = ConvertTo-AsaModel -Lines $warm

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($n in ($Sizes | Sort-Object)) {
    $lines = New-AsaLargeConfig -LineCount $n
    $actual = $lines.Count

    $beforeMem = [GC]::GetTotalMemory($true)
    $parseMs = Measure-Ms { $script:model = ConvertTo-AsaModel -Lines $lines }
    $refMs   = Measure-Ms { Get-AsaReferenceIndex -Model $script:model }
    $totalMs = Measure-Ms {
        $m = ConvertTo-AsaModel -Lines $lines
        Get-AsaReferenceIndex -Model $m | Out-Null
        Get-AsaZoneModel -Model $m | Out-Null
        Invoke-AsaChecks -Model $m -Profile commercial | Out-Null
    }
    $afterMem = [GC]::GetTotalMemory($false)

    $rows.Add([pscustomobject]@{
        Lines      = $actual
        ParseMs    = [math]::Round($parseMs, 1)
        RefIdxMs   = [math]::Round($refMs, 1)
        TotalMs    = [math]::Round($totalMs, 1)
        UsPerLine  = [math]::Round(($totalMs * 1000.0 / $actual), 2)
        HeapMB     = [math]::Round((($afterMem - $beforeMem) / 1MB), 1)
    })
}

# Fit a power law total = c * lines^exponent via least squares on the logs.
function Get-Exponent {
    param([object[]]$Points, [string]$YField)
    $xs = $Points | ForEach-Object { [math]::Log($_.Lines) }
    $ys = $Points | ForEach-Object { [math]::Log([math]::Max(0.001, $_.$YField)) }
    $nN = $xs.Count
    $mx = ($xs | Measure-Object -Average).Average
    $my = ($ys | Measure-Object -Average).Average
    $num = 0.0; $den = 0.0
    for ($j = 0; $j -lt $nN; $j++) {
        $num += ($xs[$j] - $mx) * ($ys[$j] - $my)
        $den += ($xs[$j] - $mx) * ($xs[$j] - $mx)
    }
    if ($den -eq 0) { return 0.0 }
    return $num / $den
}

$parseExp = Get-Exponent -Points $rows -YField 'ParseMs'
$totalExp = Get-Exponent -Points $rows -YField 'TotalMs'

# Doubling factor between the two largest sizes (linear ~2.0, quadratic ~4.0).
$last = $rows[$rows.Count - 1]
$prev = $rows[$rows.Count - 2]
$doubleFactor = if ($prev.TotalMs -gt 0) { [math]::Round($last.TotalMs / $prev.TotalMs, 2) } else { 0 }

# Sub-quadratic requires BOTH a bounded fitted exponent and a bounded tail
# doubling factor; the latter is what actually catches a quadratic tail.
$pass = ($totalExp -le $MaxExponent) -and ($parseExp -le $MaxExponent) -and
        ($doubleFactor -le $MaxDoubleFactor)

if (-not $Quiet) {
    Write-Information ('[*] NFR-04 scaling benchmark (offline, synthetic configs)') -InformationAction Continue
    ($rows | Format-Table -AutoSize | Out-String).TrimEnd().Split("`n") |
        ForEach-Object { Write-Information ("    " + $_) -InformationAction Continue }
    Write-Information ('') -InformationAction Continue
    Write-Information ('[*] parser growth exponent : {0:N2}  (linear=1.0, quadratic=2.0)' -f $parseExp) -InformationAction Continue
    Write-Information ('[*] pipeline growth exponent: {0:N2}' -f $totalExp) -InformationAction Continue
    Write-Information ('[*] doubling factor (top two sizes): {0:N2}x  (linear=2.0, quadratic=4.0; max {1:N2})' -f $doubleFactor, $MaxDoubleFactor) -InformationAction Continue
    if ($pass) {
        Write-Information ('[+] PASS: scaling is sub-quadratic (exponent <= {0:N2}, doubling <= {1:N2}x)' -f $MaxExponent, $MaxDoubleFactor) -InformationAction Continue
    }
    else {
        Write-Information ('[-] FAIL: scaling indicates quadratic blowup (exponent > {0:N2} or doubling > {1:N2}x)' -f $MaxExponent, $MaxDoubleFactor) -InformationAction Continue
    }
}

$verdict = [pscustomobject]@{
    Rows         = $rows
    ParseExp        = [math]::Round($parseExp, 3)
    TotalExp        = [math]::Round($totalExp, 3)
    DoubleFactor    = $doubleFactor
    MaxExponent     = $MaxExponent
    MaxDoubleFactor = $MaxDoubleFactor
    Pass            = $pass
}

# Only set an exit code when run as a script, not when dot-sourced for tests.
if ($MyInvocation.InvocationName -ne '.') {
    $verdict
    if (-not $pass) { exit 1 } else { exit 0 }
}
else {
    $verdict
}
