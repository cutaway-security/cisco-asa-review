#Requires -Version 5.1
#
# Robustness.Tests.ps1 -- anti-overfit guard (TR-05). Runs the full check
# pipeline against the independently-sourced real sanitized configs (the same
# corpus used for the TR-07 parser gate) and asserts it runs cleanly and emits
# well-formed findings -- so the checks are not overfit to the synthesized
# fixtures. Skips if the (gitignored) real configs are not present locally.
# Offline, no device, no network. Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    foreach ($f in 'Read-AsaConfig','ConvertTo-AsaModel','Get-AsaInterfaceRoles','Resolve-AsaReferences',
                   'Get-AsaSecrets','Get-AsaReferenceIndex','Invoke-AsaChecks','Get-AsaZoneModel') {
        . (Join-Path $src "$f.ps1")
    }
    . (Join-Path $src 'checks\structural.ps1')
    $script:RealDir = Join-Path $PSScriptRoot '..\fixtures\real'
}

Describe 'Anti-overfit: full pipeline on real sanitized configs (TR-05)' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\fixtures\real'))) {

    It 'runs checks + zone model + reference index on each real config without error' {
        $real = Get-ChildItem -LiteralPath $script:RealDir -Filter '*.txt' -ErrorAction SilentlyContinue
        $real.Count | Should -BeGreaterOrEqual 2
        foreach ($f in $real) {
            $model = ConvertTo-AsaModel -Path $f.FullName
            { Get-AsaZoneModel -Model $model | Out-Null } | Should -Not -Throw
            { Get-AsaReferenceIndex -Model $model | Out-Null } | Should -Not -Throw
            $findings = @(Invoke-AsaChecks -Model $model -Profile commercial)

            # well-formed findings: known severity, known status, real id
            foreach ($fd in $findings) {
                $fd.CheckId   | Should -Not -BeNullOrEmpty
                $fd.Severity  | Should -BeIn @('High','Medium','Low','Informational')
                $fd.Status    | Should -BeIn @('finding','not-assessed')
            }
            # a real production config should surface at least some findings
            $findings.Count | Should -BeGreaterThan 0 -Because "$($f.Name) is a real config and should yield findings"
        }
    }
}
