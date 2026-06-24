#Requires -Version 5.1
#
# Segmentation.Tests.ps1 -- zone model (Get-AsaZoneModel). The Mermaid .md output
# was removed in Phase 6 (issue #1); the segmentation visual lives in the HTML
# (see HtmlReport.Tests.ps1). Offline, no device, no network. Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    foreach ($f in 'Read-AsaConfig','ConvertTo-AsaModel','Get-AsaInterfaceRoles',
                   'Resolve-AsaReferences','Get-AsaZoneModel') {
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

    It 'marks sources whose any-any reaches every other zone as collapsed' {
        $script:InZ.CollapsedSources | Should -Contain 'outside'
        $script:InZ.CollapsedSources | Should -Contain 'inside'
    }

    It 'hardened config has no ANY/ANY inter-zone edges' {
        @($script:HzZ.Edges | Where-Object { $_.AnyAny }).Count | Should -Be 0
    }
}
