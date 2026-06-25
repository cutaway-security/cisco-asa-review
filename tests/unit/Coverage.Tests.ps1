#Requires -Version 5.1
#
# Coverage.Tests.ps1 -- v0.2 catalog coverage (Slice 1): additional CIS/STIG
# checks beyond the MVP-15. True positives on insecure/coverage fixtures, true
# negatives on the hardened fixture. Offline, no device, no network. Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    foreach ($f in 'Read-AsaConfig','ConvertTo-AsaModel','Get-AsaInterfaceRoles','Resolve-AsaReferences',
                   'Get-AsaSecrets','Get-AsaReferenceIndex','Invoke-AsaChecks') {
        . (Join-Path $src "$f.ps1")
    }
    . (Join-Path $src 'checks\structural.ps1')

    $fx = Join-Path $PSScriptRoot '..\fixtures'
    $script:InFind  = @(Invoke-AsaChecks -Model (ConvertTo-AsaModel -Path (Join-Path $fx 'asa-5515-insecure.txt')) -Profile commercial)
    $script:HdFind  = @(Invoke-AsaChecks -Model (ConvertTo-AsaModel -Path (Join-Path $fx 'asa-5515-hardened.txt')) -Profile commercial)
    $script:CovFind = @(Invoke-AsaChecks -Model (ConvertTo-AsaModel -Path (Join-Path $fx 'asa-5515-coverage.txt')) -Profile commercial)

    function script:Fired($findings, [string]$id) { [bool](@($findings | Where-Object { $_.CheckId -eq $id -and $_.Status -eq 'finding' }).Count) }
}

Describe 'v0.2 coverage: true positives' {

    It 'flags the checks the insecure fixture should trigger' {
        foreach ($id in 'MGMT-SSH-OUTSIDE','AUTH-AAA-SERIAL','LOG-TIMESTAMP','LOG-TRAP','AUTH-PW-LOCKOUT','IF-URPF',
                        'MGMT-SSH-TIMEOUT','MGMT-HTTP-TIMEOUT','CRYPTO-PFS') {
            script:Fired $script:InFind $id | Should -BeTrue -Because "$id should fire on the insecure fixture"
        }
    }

    It 'flags console logging, weak SNMPv3, and a long SA lifetime on the coverage fixture' {
        script:Fired $script:CovFind 'LOG-CONSOLE'        | Should -BeTrue
        script:Fired $script:CovFind 'SNMP-V3-WEAK'       | Should -BeTrue
        script:Fired $script:CovFind 'CRYPTO-SA-LIFETIME' | Should -BeTrue
    }
}

Describe 'v0.2 coverage: true negatives on the hardened fixture' {

    It 'fires none of the new checks on the hardened config' {
        foreach ($id in 'MGMT-SSH-OUTSIDE','AUTH-AAA-SERIAL','LOG-TIMESTAMP','LOG-TRAP','LOG-CONSOLE','AUTH-PW-LOCKOUT','IF-URPF','SNMP-V3-WEAK',
                        'MGMT-SSH-TIMEOUT','MGMT-HTTP-TIMEOUT','CRYPTO-PFS','CRYPTO-SA-LIFETIME') {
            script:Fired $script:HdFind $id | Should -BeFalse -Because "$id must not fire on the hardened fixture"
        }
    }

    It 'still has zero risk findings on the hardened fixture overall' {
        @($script:HdFind | Where-Object { $_.Severity -in 'High','Medium','Low' }).Count | Should -Be 0
    }
}

Describe 'v0.2 coverage: catalog integrity' {

    It 'all catalog checks have a unique id and a known severity' {
        $cat = Import-PowerShellDataFile -LiteralPath (Join-Path $src '..\data\check-catalog.psd1')
        ($cat.Checks.Id | Sort-Object -Unique).Count | Should -Be $cat.Checks.Count
        foreach ($c in $cat.Checks) { $c.Severity | Should -BeIn @('High','Medium','Low','Informational') }
    }
}
