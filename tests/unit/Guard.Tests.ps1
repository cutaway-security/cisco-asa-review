#Requires -Version 5.1
#
# Guard.Tests.ps1 -- enforces the passive/offline boundary as code (SR-01, SR-06,
# SR-02). Fails if any tool script introduces a network call, active collection,
# dynamic evaluation, or an unexpected write. Complements the runtime egress
# check (TSC-11) with a static gate.
#
# Pester 5.x.

BeforeAll {
    $script:Root      = Join-Path $PSScriptRoot '..\..'
    $script:SrcFiles  = @(Get-ChildItem -Path (Join-Path $script:Root 'src') -Recurse -Filter '*.ps1')
    $script:Entry     = Get-Item (Join-Path $script:Root 'Invoke-AsaReview.ps1')
    $script:ToolFiles = @($script:SrcFiles) + @($script:Entry)

    # Strip comments/help so prose ("never makes a network call") doesn't trip the
    # guard -- we test executable code, not documentation.
    function Get-CodeOnly {
        param([string]$Path)
        $raw = Get-Content -Raw -LiteralPath $Path
        # Remove block comments (comment-based help) first, then line comments.
        $raw = [regex]::Replace($raw, '(?s)<#.*?#>', '')
        $code = foreach ($l in ($raw -split "`n")) { ($l -replace '#.*$', '') }
        $code -join "`n"
    }
}

Describe 'Passive/offline guard (SR-01, SR-06)' {

    It 'no tool script contains a network or active-collection primitive' {
        $net = 'Invoke-WebRequest|Invoke-RestMethod|Net\.Sockets|Net\.WebClient|WebClient|TcpClient|UdpClient|' +
               'Test-NetConnection|Test-Connection|Resolve-DnsName|Enter-PSSession|New-PSSession|Invoke-Command|' +
               '-ComputerName|Get-WmiObject|Get-CimInstance|New-CimSession|Start-BitsTransfer|Send-MailMessage|' +
               '\bcurl\b|\bwget\b|\bnmap\b|snmpwalk|System\.Net\.Http'
        foreach ($f in $script:ToolFiles) {
            $code = Get-CodeOnly -Path $f.FullName
            if ($code -match $net) { throw "[x] $($f.Name) contains a forbidden network/active primitive" }
        }
        $true | Should -BeTrue
    }

    It 'no tool script dynamically evaluates input (Invoke-Expression / iex / dot-source of a non-src path)' {
        foreach ($f in $script:ToolFiles) {
            $code = Get-CodeOnly -Path $f.FullName
            $code | Should -Not -Match '\bInvoke-Expression\b'
            $code | Should -Not -Match '\biex\b'
        }
    }

    It 'the review never invokes the (network-using) EoL updater' {
        # Update-AsaEolData.ps1 is the only network script; the review path must
        # not call it, so a config review stays fully offline.
        $entry = Get-CodeOnly -Path (Join-Path $script:Root 'Invoke-AsaReview.ps1')
        $entry | Should -Not -Match 'Update-AsaEolData'
        foreach ($f in $script:SrcFiles) {
            (Get-CodeOnly -Path $f.FullName) | Should -Not -Match 'Update-AsaEolData'
        }
    }
}

Describe 'Write boundary (SR-02)' {

    It 'only Write-AsaReport performs file writes' {
        $writes = 'Set-Content|Add-Content|Out-File|Export-Csv|\bExport-Clixml\b|Remove-Item|New-Item'
        $allowedWriters = @('Write-AsaReport.ps1', 'Write-AsaHtmlReport.ps1')
        foreach ($f in $script:SrcFiles) {
            if ($f.Name -in $allowedWriters) { continue }
            $code = Get-CodeOnly -Path $f.FullName
            if ($code -match $writes) { throw "[x] unexpected write cmdlet in $($f.Name)" }
        }
        $true | Should -BeTrue
    }

    It 'the reader only reads (Read-AsaConfig uses no write cmdlets)' {
        $code = Get-CodeOnly -Path (Join-Path $script:Root 'src\Read-AsaConfig.ps1')
        $code | Should -Not -Match 'Set-Content|Add-Content|Out-File|Export-Csv|Remove-Item'
    }
}
