#Requires -Version 5.1
#
# HtmlReport.Tests.ps1 -- Phase 5b consolidated self-contained HTML deliverable.
# Offline, no device, no network. Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    foreach ($f in 'Read-AsaConfig','ConvertTo-AsaModel','Get-AsaInterfaceRoles','Resolve-AsaReferences',
                   'Get-AsaSecrets','Invoke-AsaChecks','Protect-AsaSecret','Get-AsaZoneModel','Write-AsaHtmlReport') {
        . (Join-Path $src "$f.ps1")
    }
    . (Join-Path $src 'checks\structural.ps1')

    $script:FixtureDir = Join-Path $PSScriptRoot '..\fixtures'
    $script:Insecure   = Join-Path $script:FixtureDir 'asa-5515-insecure.txt'
    $script:Hardened   = Join-Path $script:FixtureDir 'asa-5515-hardened.txt'

    $script:InModel  = ConvertTo-AsaModel -Path $script:Insecure
    $script:InFind   = @(Invoke-AsaChecks -Model $script:InModel -Profile commercial)
    $script:InZone   = Get-AsaZoneModel -Model $script:InModel

    $script:OutDir = Join-Path ([System.IO.Path]::GetTempPath()) ("asahtml_" + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null
    $script:R = Write-AsaHtmlReport -Findings $script:InFind -ZoneModel $script:InZone -Model $script:InModel `
        -ConfigPath $script:Insecure -OutputDirectory $script:OutDir -Profile commercial `
        -Timestamp '20260624_150000' -ChecksEvaluated 15
    $script:Html = Get-Content -Raw -LiteralPath $script:R.HtmlPath
}
AfterAll { if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force } }

Describe 'HTML deliverable: structure' {

    It 'writes a timestamped .html next to the output, not the config' {
        $script:R.HtmlPath | Should -Exist
        $script:R.HtmlPath | Should -Match '_asa-report_20260624_150000\.html$'
        [System.IO.Path]::GetFullPath($script:R.HtmlPath) | Should -Not -Be ([System.IO.Path]::GetFullPath($script:Insecure))
    }

    It 'consolidates findings + segmentation in one document' {
        $script:Html | Should -Match '<h2>Findings</h2>'
        $script:Html | Should -Match 'Network segmentation and data flow'
        $script:Html | Should -Match 'Zone-to-zone connectivity matrix'
        $script:Html | Should -Match 'ACL-ANY-ANY'         # a finding
    }

    It 'renders the full findings detail with ALL evidence lines (FR-37)' {
        $script:Html | Should -Match '<h2>Findings detail</h2>'
        # ACL-ANY-ANY has two evidence lines (literal + object-group); both shown in detail
        # skip block 0 (everything before the first detail div, incl. the summary table)
        $blocks = $script:Html -split "<div class='detail'>" | Select-Object -Skip 1
        $aclBlock = $blocks | Where-Object { $_ -match 'ACL-ANY-ANY' } | Select-Object -First 1
        $aclBlock | Should -Not -BeNullOrEmpty
        ([regex]::Matches($aclBlock, '<li>line ')).Count | Should -BeGreaterOrEqual 2
    }

    It 'includes Informational hygiene findings in the report' {
        $script:Html | Should -Match 'HYGIENE-'
        $script:Html | Should -Match 'Informational'
    }

    It 'the segmentation Markdown writer is removed (FR-38)' {
        Test-Path (Join-Path $src 'Write-AsaSegmentation.ps1') | Should -BeFalse
        (Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '..\..\Invoke-AsaReview.ps1')) | Should -Not -Match 'Write-AsaSegmentation'
    }

    It 'contains a well-formed inline SVG topology' {
        $m = [regex]::Match($script:Html, '<svg.*?</svg>', 'Singleline')
        $m.Success | Should -BeTrue
        { [xml]$m.Value } | Should -Not -Throw       # parses as XML -> well-formed
        $m.Value | Should -Match 'Untrusted'
        $m.Value | Should -Match '#b00000'           # risk-edge / untrusted styling colour
    }

    It 'marks the outside->inside matrix cell as an ANY-ANY risk cell' {
        $script:Html | Should -Match "cell-risk'>ANY-ANY"
    }

    It 'collapses any-to-all-zones in the SVG by default (badge) but keeps the matrix exhaustive' {
        $script:Html | Should -Match 'ANY/ANY to ALL ZONES'      # node badge
        $script:Html | Should -Match "cell-risk'>ANY-ANY"        # matrix still complete
    }

    It 'draws individual any-any SVG edges only with -ExpandAnyAny' {
        $exp = Write-AsaHtmlReport -Findings $script:InFind -ZoneModel $script:InZone -Model $script:InModel `
            -ConfigPath $script:Insecure -OutputDirectory $script:OutDir -Profile commercial `
            -Timestamp '20260624_150200' -ChecksEvaluated 15 -ExpandAnyAny
        $expHtml = Get-Content -Raw -LiteralPath $exp.HtmlPath
        $redLine = "<line[^>]*stroke='#b00000'"
        $expRed = ([regex]::Matches($expHtml, $redLine)).Count
        $defRed = ([regex]::Matches($script:Html, $redLine)).Count
        $expRed | Should -BeGreaterThan $defRed       # expanded draws the red arrows
        $expHtml | Should -Not -Match 'ANY/ANY to ALL ZONES'   # no collapse badge when expanded
    }
}

Describe 'HTML deliverable: portability and safety' {

    It 'contains no JavaScript (mail-gateway safe)' {
        $script:Html | Should -Not -Match '(?i)<script'
        $script:Html | Should -Not -Match '(?i)on(click|load|error)='
    }

    It 'references no external resources (no src/href/@import to a URL)' {
        $script:Html | Should -Not -Match '(?i)src\s*='
        $script:Html | Should -Not -Match '(?i)href\s*='
        $script:Html | Should -Not -Match '(?i)@import'
        # the only URL present is the SVG xmlns namespace, which is not fetched
    }

    It 'leaks no seeded secret value (TSC-12)' {
        $secrets = @(Get-AsaSecrets -Model $script:InModel)
        foreach ($s in $secrets) {
            if ($s.Value.Length -ge 6) { $script:Html.Contains($s.Value) | Should -BeFalse -Because "leaked: $($s.Value)" }
        }
    }

    It 'is deterministic across runs' {
        $r2 = Write-AsaHtmlReport -Findings $script:InFind -ZoneModel (Get-AsaZoneModel -Model $script:InModel) -Model $script:InModel `
            -ConfigPath $script:Insecure -OutputDirectory $script:OutDir -Profile commercial -Timestamp '20260624_150000' -ChecksEvaluated 15
        (Get-Content -Raw -LiteralPath $r2.HtmlPath) | Should -Be $script:Html
    }
}

Describe 'HTML deliverable: hardened fixture' {

    It 'shows no ANY-ANY risk cells for the hardened config' {
        $hm = ConvertTo-AsaModel -Path $script:Hardened
        $hf = @(Invoke-AsaChecks -Model $hm -Profile commercial)
        $hz = Get-AsaZoneModel -Model $hm
        $r = Write-AsaHtmlReport -Findings $hf -ZoneModel $hz -Model $hm -ConfigPath $script:Hardened `
            -OutputDirectory $script:OutDir -Timestamp '20260624_150100' -ChecksEvaluated 15
        $h = Get-Content -Raw -LiteralPath $r.HtmlPath
        $h | Should -Not -Match "cell-risk'>ANY-ANY"
        $h | Should -Match 'No permit ip any any inter-zone flows'
    }
}
