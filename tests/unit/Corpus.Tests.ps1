#Requires -Version 5.1
#
# Corpus.Tests.ps1
#
# Phase 1 acceptance-gate tests: the test corpus is in place and well-formed.
# No parser or checks exist yet (Phases 2-4); these tests validate the fixtures,
# the expected-findings oracle, and the real-config corpus that later phases
# depend on. Runs fully offline (no device, no network), per TR-04.
#
# Pester 5.x.

BeforeAll {
    $script:FixtureDir = Join-Path $PSScriptRoot '..\fixtures'
    $script:RealDir    = Join-Path $script:FixtureDir 'real'
    $script:Insecure   = Join-Path $script:FixtureDir 'asa-5515-insecure.txt'
    $script:Hardened   = Join-Path $script:FixtureDir 'asa-5515-hardened.txt'
    $script:Manifest   = Join-Path $script:FixtureDir 'expected-findings.psd1'
}

Describe 'Phase 1 corpus: synthesized fixtures' {

    It 'has a non-empty insecure fixture' {
        $script:Insecure | Should -Exist
        (Get-Item $script:Insecure).Length | Should -BeGreaterThan 0
    }

    It 'has a non-empty hardened fixture' {
        $script:Hardened | Should -Exist
        (Get-Item $script:Hardened).Length | Should -BeGreaterThan 0
    }

    It 'both fixtures look like ASA running-config (ASA Version header + interface block)' {
        foreach ($f in @($script:Insecure, $script:Hardened)) {
            $text = Get-Content -Raw -LiteralPath $f
            $text | Should -Match 'ASA Version 9\.'
            $text | Should -Match '(?m)^interface '
            $text | Should -Match '(?m)^ nameif '
        }
    }
}

Describe 'Phase 1 corpus: expected-findings oracle' {

    BeforeAll {
        # Exercises the SR-08 safe-load path: data-only, no code execution.
        $script:Expected = Import-PowerShellDataFile -LiteralPath $script:Manifest
    }

    It 'loads as data via Import-PowerShellDataFile' {
        $script:Expected | Should -Not -BeNullOrEmpty
        $script:Expected.SchemaVersion | Should -Be 1
    }

    It 'defines exactly the 15 MVP checks' {
        $script:Expected.Checks.Count | Should -Be 15
    }

    It 'every check has Id, Category, Severity, Kind, Authority' {
        foreach ($c in $script:Expected.Checks) {
            $c.Id        | Should -Not -BeNullOrEmpty
            $c.Category  | Should -BeIn @('management','logging','crypto','auth','access')
            $c.Severity  | Should -BeIn @('High','Medium','Low')
            $c.Kind      | Should -BeIn @('presence','absence','conditional-absence')
            $c.Authority | Should -Not -BeNullOrEmpty
        }
    }

    It 'check Ids are unique' {
        $ids = $script:Expected.Checks.Id
        ($ids | Sort-Object -Unique).Count | Should -Be $ids.Count
    }

    It 'insecure fixture MustFire covers all 15 checks with valid Ids' {
        $checkIds = $script:Expected.Checks.Id
        $fire = $script:Expected.Fixtures['asa-5515-insecure.txt'].MustFire
        $fire.Count | Should -Be 15
        foreach ($entry in $fire) { $entry.Id | Should -BeIn $checkIds }
        ($fire.Id | Sort-Object -Unique).Count | Should -Be 15
    }

    It 'hardened fixture MustNotFire lists all 15 checks' {
        $checkIds = $script:Expected.Checks.Id
        $clean = $script:Expected.Fixtures['asa-5515-hardened.txt'].MustNotFire
        $clean.Count | Should -Be 15
        foreach ($id in $clean) { $id | Should -BeIn $checkIds }
    }

    It 'every MustFire Id is also in MustNotFire (true-pos/true-neg symmetry)' {
        $fireIds  = $script:Expected.Fixtures['asa-5515-insecure.txt'].MustFire.Id | Sort-Object
        $cleanIds = $script:Expected.Fixtures['asa-5515-hardened.txt'].MustNotFire | Sort-Object
        ($fireIds -join ',') | Should -Be ($cleanIds -join ',')
    }
}

Describe 'Phase 1 corpus: seeded findings actually present in fixture text' {

    BeforeAll {
        $script:Expected = Import-PowerShellDataFile -LiteralPath $script:Manifest
        $script:InsecureText = Get-Content -Raw -LiteralPath $script:Insecure
    }

    It 'each presence-based seeded finding has its evidence line in the insecure fixture' {
        foreach ($entry in $script:Expected.Fixtures['asa-5515-insecure.txt'].MustFire) {
            if ($entry.EvidenceKind -eq 'presence') {
                $script:InsecureText | Should -Match ([regex]::Escape($entry.EvidenceMatch))
            }
        }
    }

    It 'absence-based seeded findings are genuinely absent from the insecure fixture' {
        # The bad config must NOT contain the hardened lines these checks look for.
        $script:InsecureText | Should -Not -Match '(?m)^ssh version 2'
        $script:InsecureText | Should -Not -Match '(?m)^logging enable'
        $script:InsecureText | Should -Not -Match '(?m)^logging host '
        $script:InsecureText | Should -Not -Match '(?m)^no service password-recovery'
        $script:InsecureText | Should -Not -Match '(?m)^password-policy '
        $script:InsecureText | Should -Not -Match '(?m)^ntp authenticate'
        $script:InsecureText | Should -Not -Match '(?m)^aaa authentication ssh console'
        $script:InsecureText | Should -Not -Match '(?m)^banner login'
    }

    It 'hardened fixture genuinely contains the good-state lines' {
        $h = Get-Content -Raw -LiteralPath $script:Hardened
        $h | Should -Match '(?m)^ssh version 2'
        $h | Should -Match '(?m)^logging enable'
        $h | Should -Match '(?m)^logging host '
        $h | Should -Match '(?m)^no service password-recovery'
        $h | Should -Match '(?m)^password-policy minimum-length'
        $h | Should -Match '(?m)^ntp authenticate'
        $h | Should -Match '(?m)^aaa authentication ssh console'
        $h | Should -Match '(?m)^banner login'
        $h | Should -Not -Match '(?m)^telnet '
        $h | Should -Not -Match 'permit ip any any'
    }
}

Describe 'Phase 1 corpus: real sanitized configs (TR-07)' {

    It 'at least two real sanitized configs are present locally' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\fixtures\real'))) {
        $real = Get-ChildItem -LiteralPath $script:RealDir -Filter '*.txt' -ErrorAction SilentlyContinue
        $real.Count | Should -BeGreaterOrEqual 2
    }

    It 'each real config looks like an ASA running-config' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\fixtures\real'))) {
        $real = Get-ChildItem -LiteralPath $script:RealDir -Filter '*.txt' -ErrorAction SilentlyContinue
        foreach ($f in $real) {
            (Get-Content -Raw -LiteralPath $f.FullName) | Should -Match 'ASA Version|: Saved|access-list|nameif'
        }
    }
}
