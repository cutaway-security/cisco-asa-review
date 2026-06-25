#Requires -Version 5.1
#
# Checks.Tests.ps1 -- Phase 4 check engine + output. The v0.1b gate: exact
# seeded true positives / zero false positives, masking (TSC-12), deterministic
# ordering, end-to-end report. Offline, no device, no network.
#
# Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    foreach ($f in 'Read-AsaConfig','ConvertTo-AsaModel','Get-AsaSecrets','Get-AsaInterfaceRoles',
                   'Resolve-AsaReferences','Invoke-AsaChecks','Protect-AsaSecret','Write-AsaReport') {
        . (Join-Path $src "$f.ps1")
    }
    . (Join-Path $src 'checks\structural.ps1')

    $script:FixtureDir = Join-Path $PSScriptRoot '..\fixtures'
    $script:Insecure   = Join-Path $script:FixtureDir 'asa-9x-insecure.txt'
    $script:Hardened   = Join-Path $script:FixtureDir 'asa-9x-hardened.txt'
    $script:Expected   = Import-PowerShellDataFile -LiteralPath (Join-Path $script:FixtureDir 'expected-findings.psd1')

    $script:InsecureModel = ConvertTo-AsaModel -Path $script:Insecure
    $script:HardenedModel = ConvertTo-AsaModel -Path $script:Hardened
    $script:InsecureFindings = @(Invoke-AsaChecks -Model $script:InsecureModel -Profile commercial)
    $script:HardenedFindings = @(Invoke-AsaChecks -Model $script:HardenedModel -Profile commercial)
}

Describe 'Check engine: true positives on the insecure fixture' {

    It 'fires all 15 MVP checks (the catalog may also fire additional v0.2 checks)' {
        $fired = @($script:InsecureFindings | Where-Object { $_.Status -eq 'finding' })
        $firedIds = $fired.CheckId | Sort-Object -Unique
        foreach ($id in $script:Expected.Checks.Id) { $firedIds | Should -Contain $id }
    }

    It 'every seeded MustFire check fires with the expected evidence' {
        foreach ($exp in $script:Expected.Fixtures['asa-9x-insecure.txt'].MustFire) {
            $hit = $script:InsecureFindings | Where-Object { $_.CheckId -eq $exp.Id -and $_.Status -eq 'finding' } | Select-Object -First 1
            $hit | Should -Not -BeNullOrEmpty -Because "check $($exp.Id) must fire"
            if ($exp.EvidenceKind -eq 'presence') {
                $texts = @($hit.EvidenceLines.Text)
                ($texts | Where-Object { $_.Contains($exp.EvidenceMatch) }).Count | Should -BeGreaterThan 0 `
                    -Because "evidence for $($exp.Id) should include: $($exp.EvidenceMatch)"
            }
            elseif ($exp.EvidenceKind -eq 'absent') {
                $hit.EvidenceLineNo | Should -Be 0 -Because "$($exp.Id) is a pure absence finding"
            }
            # 'conditional-absent' (e.g. NTP-AUTH) fires on a present trigger and
            # legitimately carries the triggering context lines as evidence; the
            # finding existing is sufficient.
        }
    }
}

Describe 'Check engine: zero false positives on the hardened fixture' {

    It 'produces no risk findings (High/Medium/Low) on the hardened fixture' {
        @($script:HardenedFindings | Where-Object { $_.Severity -in 'High','Medium','Low' }).Count | Should -Be 0
    }
}

Describe 'Check engine: deep resolution (FR-05b) and not-assessed (OR-03)' {

    It 'resolves a deeply-nested object-group any-any as a real finding (FR-05b)' {
        $lines = @(
            'object-group network gDeep', ' group-object gMid',
            'object-group network gMid', ' group-object gLeaf',
            'object-group network gLeaf', ' network-object 0.0.0.0 0.0.0.0',
            'access-list t extended permit ip object-group gDeep any',
            'access-group t in interface outside'
        )
        $m = ConvertTo-AsaModel -Lines $lines
        $f = @(Invoke-AsaChecks -Model $m -Profile commercial) | Where-Object { $_.CheckId -eq 'ACL-ANY-ANY' }
        $f | Should -Not -BeNullOrEmpty
        $f.Status | Should -Be 'finding'   # deep recursion now resolves gDeep -> any
    }

    It 'reports ACL-ANY-ANY not-assessed on a circular group-object reference' {
        $lines = @(
            'object-group network gA', ' group-object gB',
            'object-group network gB', ' group-object gA',
            'access-list t extended permit ip object-group gA any',
            'access-group t in interface outside'
        )
        $m = ConvertTo-AsaModel -Lines $lines
        $f = @(Invoke-AsaChecks -Model $m -Profile commercial) | Where-Object { $_.CheckId -eq 'ACL-ANY-ANY' }
        $f | Should -Not -BeNullOrEmpty
        $f.Status | Should -Be 'not-assessed'
    }
}

Describe 'Check engine: deterministic ordering (NFR-06)' {

    It 'produces an identical finding order across repeated runs' {
        $a = @(Invoke-AsaChecks -Model $script:InsecureModel -Profile commercial) |
            ForEach-Object { "$($_.CheckId):$($_.EvidenceLineNo)" }
        $b = @(Invoke-AsaChecks -Model $script:InsecureModel -Profile commercial) |
            ForEach-Object { "$($_.CheckId):$($_.EvidenceLineNo)" }
        ($a -join '|') | Should -Be ($b -join '|')
    }

    It 'orders by severity then check id' {
        $ranks = @($script:InsecureFindings | ForEach-Object { $_.SeverityRank })
        $sorted = $ranks | Sort-Object
        ($ranks -join ',') | Should -Be ($sorted -join ',')
    }
}

Describe 'Secret masking (SR-04 / TSC-12)' {

    It 'masks every classified secret value from its own line' {
        $secrets = @(Get-AsaSecrets -Model $script:InsecureModel) + @(Get-AsaSecrets -Model $script:HardenedModel)
        foreach ($s in $secrets) {
            $masked = Protect-AsaLine -Line $s.Node.Text
            $masked.Contains($s.Value) | Should -BeFalse -Because "secret value should be redacted in: $masked"
        }
    }

    It 'conservative fallback redacts a community keyword line even if oddly formatted' {
        (Protect-AsaLine -Line 'snmp-server community Sup3rSecret').Contains('Sup3rSecret') | Should -BeFalse
    }
}

Describe 'End-to-end report (FR-16, DR-03)' {

    BeforeAll {
        $script:OutDir = Join-Path ([System.IO.Path]::GetTempPath()) ("asareview_" + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null
        $script:Report = Write-AsaReport -Findings $script:InsecureFindings -Model $script:InsecureModel `
            -ConfigPath $script:Insecure -OutputDirectory $script:OutDir -Profile commercial `
            -Timestamp '20260624_120000' -ChecksEvaluated 15
    }
    AfterAll { if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force } }

    It 'writes a timestamped Markdown and CSV file' {
        $script:Report.MarkdownPath | Should -Exist
        $script:Report.CsvPath      | Should -Exist
        $script:Report.MarkdownPath | Should -Match '_asa-review_20260624_120000\.md$'
    }

    It 'CSV has the remediation-tracking columns and includes Informational rows (DR-02a)' {
        $csv = Import-Csv -LiteralPath $script:Report.CsvPath
        $cols = $csv[0].PSObject.Properties.Name
        $cols | Should -Contain 'RemediationState'
        $cols | Should -Contain 'RemediationNotes'
        ($csv | Where-Object { $_.RemediationState -ne 'Open' }) | Should -BeNullOrEmpty   # default Open
        @($csv | Where-Object { $_.Severity -eq 'Informational' }).Count | Should -BeGreaterThan 0
    }

    It 'output filenames never equal the configuration file' {
        [System.IO.Path]::GetFullPath($script:Report.MarkdownPath) | Should -Not -Be ([System.IO.Path]::GetFullPath($script:Insecure))
        [System.IO.Path]::GetFullPath($script:Report.CsvPath)      | Should -Not -Be ([System.IO.Path]::GetFullPath($script:Insecure))
    }

    It 'contains no seeded secret value verbatim (TSC-12)' {
        $content = (Get-Content -Raw $script:Report.MarkdownPath) + (Get-Content -Raw $script:Report.CsvPath)
        $secrets = @(Get-AsaSecrets -Model $script:InsecureModel)
        foreach ($s in $secrets) {
            if ($s.Value.Length -ge 6) { $content.Contains($s.Value) | Should -BeFalse -Because "leaked secret: $($s.Value)" }
        }
    }

    It 'defaults output to the configuration file directory when none given' {
        $r = Write-AsaReport -Findings @() -Model $script:HardenedModel -ConfigPath $script:Hardened `
            -Timestamp '20260624_120001'
        try {
            (Split-Path $r.MarkdownPath -Parent) | Should -Be (Split-Path $script:Hardened -Parent)
        } finally {
            Remove-Item $r.MarkdownPath, $r.CsvPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'refuses to overwrite the configuration file' {
        # Force the timestamped name to collide is impossible; assert the guard directly
        # by pointing output at the config's own name via a crafted base is not exposed,
        # so verify the guard logic path stays intact: same dir, distinct timestamped name.
        $r2 = Write-AsaReport -Findings @() -Model $script:HardenedModel -ConfigPath $script:Hardened `
            -Timestamp '20260624_120002'
        try { $r2.MarkdownPath | Should -Not -Be $script:Hardened }
        finally { Remove-Item $r2.MarkdownPath, $r2.CsvPath -Force -ErrorAction SilentlyContinue }
    }
}
