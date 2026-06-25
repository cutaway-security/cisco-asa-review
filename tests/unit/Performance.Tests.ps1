#Requires -Version 5.1
#
# Performance.Tests.ps1 -- NFR-04 scaling regression guard. Asserts the parser
# and the full review pipeline scale sub-quadratically on large synthetic
# configs (no quadratic blowup). This is a timing test, so it is OPT-IN: it runs
# only when the environment variable ASA_RUN_PERF is set, to keep the default
# suite fast and free of timing flakiness. The standalone benchmark
# (tests/perf/Measure-AsaPerf.ps1) is the primary, fuller-range evidence.
# Offline, no device, no network. Pester 5.x.

BeforeAll {
    $script:RunPerf = -not [string]::IsNullOrEmpty($env:ASA_RUN_PERF)
    $script:Measure = Join-Path $PSScriptRoot '..\perf\Measure-AsaPerf.ps1'
}

Describe 'NFR-04: sub-quadratic scaling' -Skip:(-not (-not [string]::IsNullOrEmpty($env:ASA_RUN_PERF))) {

    It 'parser and full pipeline scale sub-quadratically up to ~16k lines' {
        # Dot-source returns the verdict object without exiting (the script
        # guards its exit on InvocationName). Tolerances a touch looser than the
        # standalone script's defaults to absorb CI timer noise, but still far
        # below the quadratic signature (exponent ~2.0, doubling ~4.0).
        $v = . $script:Measure -Sizes 4000, 8000, 16000 -MaxExponent 1.7 -MaxDoubleFactor 3.0 -Quiet

        $v.ParseExp     | Should -BeLessOrEqual 1.7 -Because "the parser must stay near-linear (NFR-04)"
        $v.TotalExp     | Should -BeLessOrEqual 1.7 -Because "the pipeline must not grow quadratically"
        $v.DoubleFactor | Should -BeLessOrEqual 3.0 -Because "doubling the lines must not ~quadruple the time"
        $v.Pass         | Should -BeTrue
    }
}
