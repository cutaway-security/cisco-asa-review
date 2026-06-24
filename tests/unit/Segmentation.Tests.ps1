#Requires -Version 5.1
#
# Segmentation.Tests.ps1 -- Phase 5 zone model + segmentation visualization.
# Offline, no device, no network. Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    foreach ($f in 'Read-AsaConfig','ConvertTo-AsaModel','Get-AsaInterfaceRoles',
                   'Resolve-AsaReferences','Get-AsaSecrets','Protect-AsaSecret',
                   'Get-AsaZoneModel','Write-AsaSegmentation') {
        . (Join-Path $src "$f.ps1")
    }
    $script:FixtureDir = Join-Path $PSScriptRoot '..\fixtures'
    $script:Insecure   = Join-Path $script:FixtureDir 'asa-5515-insecure.txt'
    $script:Hardened   = Join-Path $script:FixtureDir 'asa-5515-hardened.txt'

    $script:InsecureModel = ConvertTo-AsaModel -Path $script:Insecure
    $script:HardenedModel = ConvertTo-AsaModel -Path $script:Hardened
    $script:InZ = Get-AsaZoneModel -Model $script:InsecureModel
    $script:HzZ = Get-AsaZoneModel -Model $script:HardenedModel
}

Describe 'Zone model: derivation' {

    It 'derives the in-service zones and excludes the shutdown interface' {
        $names = @($script:InZ.Zones.Name | Sort-Object)
        $names | Should -Be @('dmz','inside','mgmt','outside')   # G0/3 is shutdown -> excluded
    }

    It 'assigns trust tiers from security-level' {
        ($script:InZ.Zones | Where-Object { $_.Name -eq 'outside' }).Tier | Should -Be 'Untrusted'
        ($script:InZ.Zones | Where-Object { $_.Name -eq 'inside' }).Tier  | Should -Be 'Trusted'
        ($script:InZ.Zones | Where-Object { $_.Name -eq 'dmz' }).Tier     | Should -Be 'DMZ'
    }

    It 'captures interface subnets for address mapping' {
        ($script:InZ.Zones | Where-Object { $_.Name -eq 'inside' }).Subnets.Cidr | Should -Contain '10.10.20.0/24'
    }
}

Describe 'Zone model: inter-zone flow edges' {

    It 'produces an outside -> inside ANY/ANY edge from outside_in permit ip any any' {
        $e = $script:InZ.Edges | Where-Object { $_.From -eq 'outside' -and $_.To -eq 'inside' -and $_.AnyAny }
        $e | Should -Not -BeNullOrEmpty
        ($e | Select-Object -First 1).Acl | Should -Be 'outside_in'
    }

    It 'flags any-any edges as High severity tied to an ACL line' {
        $any = @($script:InZ.Edges | Where-Object { $_.AnyAny })
        $any.Count | Should -BeGreaterThan 0
        ($any | ForEach-Object { $_.Severity } | Sort-Object -Unique) | Should -Be 'High'
        ($any | Where-Object { $_.LineNo -gt 0 }).Count | Should -Be $any.Count
    }

    It 'flags the object-group-expressed any-any (inside_in) as a risk edge' {
        # guards the -eq type-coercion bug that hid object-group any/any
        @($script:InZ.Edges | Where-Object { $_.From -eq 'inside' -and $_.AnyAny }).Count | Should -BeGreaterThan 0
    }

    It 'hardened config has no ANY/ANY inter-zone edges' {
        @($script:HzZ.Edges | Where-Object { $_.AnyAny }).Count | Should -Be 0
    }
}

Describe 'Segmentation output: Mermaid + matrix' {

    BeforeAll {
        $script:OutDir = Join-Path ([System.IO.Path]::GetTempPath()) ("asaseg_" + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null
        $script:R = Write-AsaSegmentation -ZoneModel $script:InZ -ConfigPath $script:Insecure `
            -OutputDirectory $script:OutDir -Timestamp '20260624_130000'
        $script:Text = Get-Content -Raw -LiteralPath $script:R.MarkdownPath
    }
    AfterAll { if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force } }

    It 'writes a timestamped segmentation file next to the output dir' {
        $script:R.MarkdownPath | Should -Exist
        $script:R.MarkdownPath | Should -Match '_asa-segmentation_20260624_130000\.md$'
        [System.IO.Path]::GetFullPath($script:R.MarkdownPath) | Should -Not -Be ([System.IO.Path]::GetFullPath($script:Insecure))
    }

    It 'emits a well-formed Mermaid flowchart with zones and a risk linkStyle' {
        $script:Text | Should -Match '(?m)^flowchart '
        $script:Text | Should -Match 'subgraph TIER_Untrusted'
        $script:Text | Should -Match 'Z_outside'
        $script:Text | Should -Match 'linkStyle \d+ stroke:#b00000'
        $script:Text | Should -Match 'ANY-ANY outside_in'
    }

    It 'matrix marks the outside->inside cell as ANY-ANY' {
        # the outside row should contain the ANY-ANY marker
        $row = ($script:Text -split "`n" | Where-Object { $_ -match '^\| \*\*outside\*\* \|' })
        $row | Should -Match 'ANY-ANY \(!\)'
    }

    It 'states the configured-flows-not-reachability boundary' {
        $script:Text | Should -Match 'not end-to-end reachability'
    }

    It 'lists highlighted risk flows with the ACL line' {
        $script:Text | Should -Match 'ANY/ANY  outside -> inside  \(ACL outside_in'
    }

    It 'attributes every risk flow to an actual permit ip any any rule (not a scoped rule)' {
        # guards the line-attribution bug where an aggregated edge cited the first line
        # any-any may be literal (permit ip any any) or object-group-expressed
        # (permit ip object-group ANY object-group ANY); both are proto ip. The
        # bug cited a scoped "permit tcp" line, which this rejects.
        $riskLines = @($script:Text -split "`n" | Where-Object { $_ -match '^- ANY/ANY' })
        $riskLines.Count | Should -BeGreaterThan 0
        foreach ($l in $riskLines) { $l | Should -Match 'permit ip ' }
    }

    It 'is deterministic across runs' {
        $r2 = Write-AsaSegmentation -ZoneModel (Get-AsaZoneModel -Model $script:InsecureModel) `
            -ConfigPath $script:Insecure -OutputDirectory $script:OutDir -Timestamp '20260624_130000'
        (Get-Content -Raw -LiteralPath $r2.MarkdownPath) | Should -Be $script:Text
    }

    It 'leaks no seeded secret value into the segmentation output (TSC-12)' {
        $secrets = @(Get-AsaSecrets -Model $script:InsecureModel)
        foreach ($s in $secrets) {
            if ($s.Value.Length -ge 6) { $script:Text.Contains($s.Value) | Should -BeFalse -Because "leaked: $($s.Value)" }
        }
    }
}

Describe 'Segmentation output: hardened fixture' {

    It 'reports no ANY/ANY risk flows for the hardened config' {
        $outDir = Join-Path ([System.IO.Path]::GetTempPath()) ("asaseg_h_" + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        try {
            $r = Write-AsaSegmentation -ZoneModel $script:HzZ -ConfigPath $script:Hardened -OutputDirectory $outDir -Timestamp '20260624_130100'
            $r.RiskEdgeCount | Should -Be 0
            (Get-Content -Raw -LiteralPath $r.MarkdownPath) | Should -Match 'No permit ip any any inter-zone flows'
        } finally { Remove-Item $outDir -Recurse -Force }
    }
}
