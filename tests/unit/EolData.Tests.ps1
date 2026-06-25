#Requires -Version 5.1
#
# EolData.Tests.ps1 -- version/EoL reference + check (FR-15) and the opt-in
# updater's offline-safe fallback. Offline, no device, no network. Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    foreach ($f in 'Read-AsaConfig','ConvertTo-AsaModel') { . (Join-Path $src "$f.ps1") }
    . (Join-Path $src 'checks\structural.ps1')
    $script:EolPath = Join-Path $PSScriptRoot '..\..\data\asa-eol.psd1'
    . (Join-Path $PSScriptRoot '..\..\Update-AsaEolData.ps1') -ErrorAction SilentlyContinue
}

Describe 'EoL reference (data/asa-eol.psd1)' {
    BeforeAll { $script:Eol = Import-PowerShellDataFile -LiteralPath $script:EolPath }

    It 'loads as data with a reference date and trains' {
        $script:Eol.SchemaVersion | Should -Be 1
        $script:Eol.ReferenceDate | Should -Match '^\d{4}-\d{2}-\d{2}$'
        $script:Eol.Trains.Count  | Should -BeGreaterThan 0
    }
    It 'every train entry has a known status' {
        foreach ($t in $script:Eol.Trains) { $t.Status | Should -BeIn @('EoL','Supported','Unknown') }
    }
}

Describe 'VERSION-EOL check (offline, uses the bundled reference)' {

    It 'flags an EoL train' {
        $m = ConvertTo-AsaModel -Lines @('ASA Version 9.8(4)')
        @(Test-AsaVersionEol -Model $m | Where-Object { $_.Fired -and $_.Status -eq 'finding' }).Count | Should -BeGreaterThan 0
    }
    It 'passes a supported train' {
        $m = ConvertTo-AsaModel -Lines @('ASA Version 9.20(2)')
        @(Test-AsaVersionEol -Model $m | Where-Object { $_.Fired }).Count | Should -Be 0
    }
    It 'reports not-assessed for an unlisted train' {
        $m = ConvertTo-AsaModel -Lines @('ASA Version 9.99(9)')
        @(Test-AsaVersionEol -Model $m | Where-Object { $_.Status -eq 'not-assessed' }).Count | Should -BeGreaterThan 0
    }
    It 'cannot assess when no version header is present' {
        $m = ConvertTo-AsaModel -Lines @('hostname x')
        @(Test-AsaVersionEol -Model $m).Count | Should -Be 0
    }
}

Describe 'Update-AsaEolData fallback (no network in the test)' {
    It 'returns null when no source URL is given (review keeps using the reference)' {
        Get-AsaEolFromWeb -Url '' -Timeout 1 | Should -BeNullOrEmpty
    }
}
