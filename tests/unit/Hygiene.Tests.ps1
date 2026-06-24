#Requires -Version 5.1
#
# Hygiene.Tests.ps1 -- Phase 6 / issue #1 hygiene checks (Informational).
# Offline, no device, no network. Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    foreach ($f in 'Read-AsaConfig','ConvertTo-AsaModel','Get-AsaInterfaceRoles','Resolve-AsaReferences',
                   'Get-AsaReferenceIndex','Invoke-AsaChecks') {
        . (Join-Path $src "$f.ps1")
    }
    . (Join-Path $src 'checks\structural.ps1')

    $script:Hyg = Join-Path $PSScriptRoot '..\fixtures\asa-5515-hygiene.txt'
    $script:M   = ConvertTo-AsaModel -Path $script:Hyg
    $script:F   = @(Invoke-AsaChecks -Model $script:M -Profile commercial)

    function script:Evid([string]$id) {
        @($script:F | Where-Object { $_.CheckId -eq $id } | ForEach-Object { $_.Evidence }) -join "`n"
    }
}

Describe 'Hygiene: all hygiene findings are Informational' {
    It 'tags hygiene checks Informational' {
        $hyg = @($script:F | Where-Object { $_.CheckId -like 'HYGIENE-*' })
        $hyg.Count | Should -BeGreaterThan 0
        ($hyg | ForEach-Object { $_.Severity } | Sort-Object -Unique) | Should -Be 'Informational'
    }
}

Describe 'Hygiene: unused ACL (FR-32)' {
    It 'flags an ACL that is referenced nowhere' {
        (script:Evid 'HYGIENE-UNUSED-ACL') | Should -Match 'DEAD_ACL'
    }
    It 'does NOT flag an ACL used only by a crypto map (the key guard)' {
        (script:Evid 'HYGIENE-UNUSED-ACL') | Should -Not -Match 'CRYPTO_ACL'
    }
    It 'does NOT flag an access-group-bound ACL' {
        (script:Evid 'HYGIENE-UNUSED-ACL') | Should -Not -Match 'HYG_IN'
    }
}

Describe 'Hygiene: unused object / object-group (FR-33)' {
    It 'flags an unused object and an unused object-group' {
        (script:Evid 'HYGIENE-UNUSED-OBJECT') | Should -Match 'dead-host'
        (script:Evid 'HYGIENE-UNUSED-OBJECT') | Should -Match 'dead-grp'
    }
    It 'does NOT flag a referenced object or object-group' {
        (script:Evid 'HYGIENE-UNUSED-OBJECT') | Should -Not -Match 'used-host'
        (script:Evid 'HYGIENE-UNUSED-OBJECT') | Should -Not -Match 'used-grp'
    }
}

Describe 'Hygiene: inactive / expired rules (FR-34)' {
    It 'flags an inactive ACE and an expired-time-range ACE' {
        (script:Evid 'HYGIENE-INACTIVE-RULE') | Should -Match 'inactive'
        (script:Evid 'HYGIENE-INACTIVE-RULE') | Should -Match 'EXPIRED-TR'
    }
    It 'does NOT flag an active-time-range ACE' {
        (script:Evid 'HYGIENE-INACTIVE-RULE') | Should -Not -Match 'ACTIVE-TR'
    }
}

Describe 'Hygiene: interface no-ip not shutdown (FR-35)' {
    It 'flags an interface with no IP that is not shut down' {
        (script:Evid 'HYGIENE-IF-NOIP') | Should -Match 'GigabitEthernet0/1'
    }
    It 'does NOT flag a shutdown, IP-bearing, or bridge-member interface' {
        $e = script:Evid 'HYGIENE-IF-NOIP'
        $e | Should -Not -Match 'GigabitEthernet0/2'   # shutdown
        $e | Should -Not -Match 'GigabitEthernet0/0'   # has IP
        $e | Should -Not -Match 'GigabitEthernet0/3'   # bridge-group member
    }
}

Describe 'Hygiene: BVI without bridge-group (FR-36)' {
    It 'flags a BVI with no matching bridge-group member' {
        (script:Evid 'HYGIENE-BVI-UNUSED') | Should -Match 'interface BVI2'
    }
    It 'does NOT flag a BVI that has a bridge-group member' {
        (script:Evid 'HYGIENE-BVI-UNUSED') | Should -Not -Match 'interface BVI1'
    }
}
