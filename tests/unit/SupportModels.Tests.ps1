#Requires -Version 5.1
#
# SupportModels.Tests.ps1 -- Phase 3 (v0.1b-prep) support-model tests.
# Secret classifier, interface-role model, object-group resolution, defaults
# model. Offline, no device, no network.
#
# Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    . (Join-Path $src 'Read-AsaConfig.ps1')
    . (Join-Path $src 'ConvertTo-AsaModel.ps1')
    . (Join-Path $src 'Get-AsaSecrets.ps1')
    . (Join-Path $src 'Get-AsaInterfaceRoles.ps1')
    . (Join-Path $src 'Resolve-AsaReferences.ps1')

    $script:FixtureDir = Join-Path $PSScriptRoot '..\fixtures'
    $script:Insecure   = Join-Path $script:FixtureDir 'asa-5515-insecure.txt'
    $script:Hardened   = Join-Path $script:FixtureDir 'asa-5515-hardened.txt'
    $script:Manifest   = Join-Path $script:FixtureDir 'expected-findings.psd1'
    $script:DefaultsFile = Join-Path $PSScriptRoot '..\..\data\asa-defaults.psd1'

    $script:Expected = Import-PowerShellDataFile -LiteralPath $script:Manifest
}

Describe 'Secret classifier: Get-AsaPasswordClass' {

    It 'classifies a pbkdf2 / $sha512$ value as pbkdf2 (not cleartext)' {
        Get-AsaPasswordClass -Value '$sha512$5000$a==$b==' -Tag 'pbkdf2' | Should -Be 'pbkdf2'
        Get-AsaPasswordClass -Value '$sha512$5000$a==$b==' -Tag $null    | Should -Be 'pbkdf2'
    }
    It 'classifies an encrypted-tagged value as encrypted' {
        Get-AsaPasswordClass -Value '8Ry2YjIyt7RRXU24' -Tag 'encrypted' | Should -Be 'encrypted'
    }
    It 'classifies nt-encrypted as not cleartext (TSC-05 relaxation)' {
        $c = Get-AsaPasswordClass -Value '0123456789abcdef' -Tag 'nt-encrypted'
        $c | Should -Be 'nt-encrypted'
        ($c -eq 'cleartext') | Should -BeFalse
    }
    It 'classifies a bare value with no tag as cleartext' {
        Get-AsaPasswordClass -Value 'SuperSecret123' -Tag $null | Should -Be 'cleartext'
    }
    It 'classifies a redacted value' {
        Get-AsaPasswordClass -Value '*****' -Tag $null | Should -Be 'redacted'
    }
}

Describe 'Secret scanner: Get-AsaSecrets against the fixture oracle' {

    BeforeAll {
        $script:InsecureSecrets = ConvertTo-AsaModel -Path $script:Insecure | Get-AsaSecrets
        $script:HardenedSecrets = ConvertTo-AsaModel -Path $script:Hardened | Get-AsaSecrets
    }

    It 'matches every seeded secret in the insecure fixture' {
        foreach ($exp in $script:Expected.Fixtures['asa-5515-insecure.txt'].Secrets) {
            $hit = $script:InsecureSecrets | Where-Object { $_.Node.Text.Contains($exp.Line) } | Select-Object -First 1
            $hit | Should -Not -BeNullOrEmpty -Because "expected to find secret line: $($exp.Line)"
            switch ($exp.Class) {
                'strong-pbkdf2' { $hit.Class | Should -Be 'pbkdf2' }
                'weak-encrypted' { $hit.Class | Should -Be 'encrypted' }
                'not-cleartext' { $hit.IsCleartext | Should -BeFalse }
                'cleartext'     { $hit.IsCleartext | Should -BeTrue }
            }
        }
    }

    It 'flags the cleartext RADIUS key, SNMP community and IKEv1 PSK as cleartext' {
        ($script:InsecureSecrets | Where-Object { $_.Kind -eq 'aaa-key' }).IsCleartext         | Should -BeTrue
        ($script:InsecureSecrets | Where-Object { $_.Kind -eq 'snmp-community' }).IsCleartext  | Should -BeTrue
        ($script:InsecureSecrets | Where-Object { $_.Kind -eq 'tunnel-group-psk' }).IsCleartext | Should -BeTrue
    }

    It 'classifies hardened-fixture secrets correctly (pbkdf2 + the md5 ntp key as cleartext)' {
        ($script:HardenedSecrets | Where-Object { $_.Kind -eq 'enable-password' }).Class | Should -Be 'pbkdf2'
        ($script:HardenedSecrets | Where-Object { $_.Kind -eq 'aaa-key' }).IsCleartext   | Should -BeFalse
        ($script:HardenedSecrets | Where-Object { $_.Kind -eq 'tunnel-group-psk' }).IsCleartext | Should -BeFalse
        ($script:HardenedSecrets | Where-Object { $_.Kind -eq 'ntp-key' }).IsCleartext   | Should -BeTrue
    }
}

Describe 'Interface-role model: Get-AsaInterfaceRoles' {

    BeforeAll { $script:Roles = ConvertTo-AsaModel -Path $script:Insecure | Get-AsaInterfaceRoles }

    It 'marks the outside interface (security-level 0) untrusted' {
        $o = $script:Roles | Where-Object { $_.Nameif -eq 'outside' }
        $o.IsUntrusted | Should -BeTrue
        $o.InService   | Should -BeTrue
    }
    It 'marks inside / dmz / mgmt as trusted' {
        foreach ($name in 'inside','dmz','mgmt') {
            ($script:Roles | Where-Object { $_.Nameif -eq $name }).IsUntrusted | Should -BeFalse
        }
    }
    It 'treats a shutdown interface with no nameif as out of service' {
        $down = $script:Roles | Where-Object { $_.IsShutdown }
        $down | Should -Not -BeNullOrEmpty
        $down.InService | Should -BeFalse
    }
    It 'applies the security-level default (inside=100, other=0) when not explicit' {
        $lines = @(
            'interface GigabitEthernet0/0', ' nameif outside',
            'interface GigabitEthernet0/1', ' nameif inside'
        )
        $r = ConvertTo-AsaModel -Lines $lines | Get-AsaInterfaceRoles
        ($r | Where-Object { $_.Nameif -eq 'inside' }).SecurityLevel  | Should -Be 100
        ($r | Where-Object { $_.Nameif -eq 'inside' }).IsUntrusted    | Should -BeFalse
        ($r | Where-Object { $_.Nameif -eq 'outside' }).SecurityLevel | Should -Be 0
        ($r | Where-Object { $_.Nameif -eq 'outside' }).IsUntrusted   | Should -BeTrue
    }
}

Describe 'Minimal resolution: object-group network' {

    BeforeAll { $script:M = ConvertTo-AsaModel -Path $script:Insecure }

    It 'resolves an explicit any group to any' {
        Test-AsaNetworkGroupIsAny -Model $script:M -Name 'any-net' | Should -BeTrue
    }
    It 'resolves a scoped group to not-any (one level of group-object expansion)' {
        Test-AsaNetworkGroupIsAny -Model $script:M -Name 'internal-nets' | Should -BeFalse
        $nested = Resolve-AsaNetworkGroup -Model $script:M -Name 'nested-admins'
        $nested.Assessed    | Should -BeTrue
        $nested.ContainsAny | Should -BeFalse
    }
    It 'reports not-assessed beyond the stated nesting depth (OR-03)' {
        $lines = @(
            'object-group network gA', ' group-object gB',
            'object-group network gB', ' group-object gC',
            'object-group network gC', ' network-object host 10.0.0.1'
        )
        $deep = ConvertTo-AsaModel -Lines $lines
        Test-AsaNetworkGroupIsAny -Model $deep -Name 'gA' | Should -Be 'not-assessed'
    }
    It 'reports not-assessed for an undefined group reference' {
        Test-AsaNetworkGroupIsAny -Model $script:M -Name 'does-not-exist' | Should -Be 'not-assessed'
    }
    It 'resolves a name symbol to its IP' {
        Resolve-AsaName -Model $script:M -Token 'inside-web-server' | Should -Be '10.10.20.10'
        Resolve-AsaName -Model $script:M -Token '10.10.20.10'       | Should -Be '10.10.20.10'
    }
}

Describe 'Defaults model: data/asa-defaults.psd1 (doc-cited audit)' {

    BeforeAll { $script:Defaults = Import-PowerShellDataFile -LiteralPath $script:DefaultsFile }

    It 'loads as data and has a schema version' {
        $script:Defaults.SchemaVersion | Should -Be 1
        $script:Defaults.Defaults.Count | Should -BeGreaterThan 0
    }
    It 'every default entry is doc-cited (citation + http url + rationale + authority)' {
        foreach ($d in $script:Defaults.Defaults) {
            $d.DocCitation | Should -Not -BeNullOrEmpty
            $d.DocUrl      | Should -Match '^https?://'
            $d.Rationale   | Should -Not -BeNullOrEmpty
            $d.Authority   | Should -Not -BeNullOrEmpty
            $d.FindingWhenAbsent | Should -BeOfType [bool]
        }
    }
    It 'covers exactly the MVP checks whose kind is absence or conditional-absence' {
        $absenceChecks = ($script:Expected.Checks |
            Where-Object { $_.Kind -in 'absence','conditional-absence' }).Id | Sort-Object
        $modeled = $script:Defaults.Defaults.CheckId | Sort-Object
        ($modeled -join ',') | Should -Be ($absenceChecks -join ',')
    }
}
