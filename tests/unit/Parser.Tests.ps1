#Requires -Version 5.1
#
# Parser.Tests.ps1 -- v0.1a-core parser unit tests (TR-03) + TR-07 real-config gate.
# Offline, no device, no network.
#
# Pester 5.x.

BeforeAll {
    $src = Join-Path $PSScriptRoot '..\..\src'
    . (Join-Path $src 'Read-AsaConfig.ps1')
    . (Join-Path $src 'ConvertTo-AsaModel.ps1')
    . (Join-Path $src 'Show-AsaModel.ps1')

    $script:FixtureDir = Join-Path $PSScriptRoot '..\fixtures'
    $script:Insecure   = Join-Path $script:FixtureDir 'asa-5515-insecure.txt'
    $script:Hardened   = Join-Path $script:FixtureDir 'asa-5515-hardened.txt'
    $script:RealDir    = Join-Path $script:FixtureDir 'real'

    # Preorder DFS of the tree; returns the LineNo sequence. For a correctly
    # built tree this MUST equal the file order 1..N (no lost/misassigned lines).
    function Get-PreorderLineNos {
        param($Model)
        $acc = [System.Collections.Generic.List[int]]::new()
        $walk = {
            param($node)
            $acc.Add($node.LineNo)
            foreach ($c in $node.Children) { & $walk $c }
        }
        foreach ($n in $Model.TopLevel) { & $walk $n }
        return $acc
    }

    # The structural integrity invariant that defines "clean parse" for TR-07.
    function Get-IntegrityProblems {
        param($Model)
        $problems = [System.Collections.Generic.List[string]]::new()

        $pre = Get-PreorderLineNos -Model $Model
        $expected = 1..$Model.LineCount
        if (($pre -join ',') -ne ($expected -join ',')) {
            $problems.Add("preorder line sequence != file order (lost or misassigned lines)")
        }

        foreach ($n in $Model.Lines) {
            if ($n.Kind -eq 'line' -and $null -ne $n.Parent) {
                if ($n.Indent -le $n.Parent.Indent) {
                    $problems.Add("line $($n.LineNo) indent $($n.Indent) <= parent indent $($n.Parent.Indent)")
                }
            }
        }
        return $problems
    }
}

Describe 'Parser: bounded reader (SR-07)' {

    It 'throws on a missing file' {
        { Read-AsaConfig -Path (Join-Path $script:FixtureDir 'does-not-exist.txt') } | Should -Throw
    }

    It 'throws on an empty file' {
        $tmp = New-TemporaryFile
        try { { Read-AsaConfig -Path $tmp.FullName } | Should -Throw }
        finally { Remove-Item $tmp -Force }
    }

    It 'throws when a line exceeds the max length' {
        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp.FullName -Value ('x' * 50) -NoNewline
            { Read-AsaConfig -Path $tmp.FullName -MaxLineLength 10 } | Should -Throw
        } finally { Remove-Item $tmp -Force }
    }

    It 'normalizes CRLF and preserves leading whitespace' {
        $tmp = New-TemporaryFile
        try {
            [System.IO.File]::WriteAllText($tmp.FullName, "interface G0/0`r`n nameif outside`r`n")
            $lines = Read-AsaConfig -Path $tmp.FullName
            $lines.Count | Should -Be 2
            $lines[1]    | Should -Be ' nameif outside'
        } finally { Remove-Item $tmp -Force }
    }

    It 'throws when nesting exceeds MaxDepth' {
        $deep = @('a', ' b', '  c', '   d')   # 4 deep
        { ConvertTo-AsaModel -Lines $deep -MaxDepth 2 } | Should -Throw
    }
}

Describe 'Parser: indentation tree' {

    BeforeAll { $script:M = ConvertTo-AsaModel -Path $script:Insecure }

    It 'places every line exactly once in file order (no lost/misassigned lines)' {
        (Get-IntegrityProblems -Model $script:M).Count | Should -Be 0
    }

    It 'LineCount equals the input line count' {
        $raw = Read-AsaConfig -Path $script:Insecure
        $script:M.LineCount | Should -Be $raw.Count
    }

    It 'interface children nest one level under their interface' {
        $if0 = $script:M.Interfaces | Where-Object { $_.Text -eq 'interface GigabitEthernet0/0' }
        $if0 | Should -Not -BeNullOrEmpty
        ($if0.Children | Where-Object { $_.Text -eq 'nameif outside' }) | Should -Not -BeNullOrEmpty
        ($if0.Children | Where-Object { $_.Text -eq 'security-level 0' }) | Should -Not -BeNullOrEmpty
    }

    It 'reaches 3-deep nesting (group-policy attributes -> webvpn -> anyconnect)' {
        $anyconnect = $script:M.Lines | Where-Object { $_.Text -eq 'anyconnect ssl dtls enable' }
        $anyconnect | Should -Not -BeNullOrEmpty
        $anyconnect.Depth | Should -Be 2
        $anyconnect.Parent.Text | Should -Be 'webvpn'
        $anyconnect.Parent.Parent.Text | Should -Be 'group-policy ra-vpn attributes'
    }

    It 'separators and metadata are non-structural top-level nodes' {
        ($script:M.Lines | Where-Object { $_.Kind -eq 'separator' }).Count | Should -BeGreaterThan 0
        ($script:M.Lines | Where-Object { $_.Kind -eq 'metadata' -and $_.Text -like ': *' }).Count | Should -BeGreaterThan 0
        # a '!' must never be a parent
        foreach ($n in ($script:M.Lines | Where-Object { $_.Kind -eq 'separator' })) {
            $n.Children.Count | Should -Be 0
        }
    }
}

Describe 'Parser: repeated-prefix families' {

    BeforeAll { $script:M = ConvertTo-AsaModel -Path $script:Insecure }

    It 'groups access-list entries by name in order' {
        $script:M.AccessLists.Keys | Should -Contain 'outside_in'
        $script:M.AccessLists['outside_in'].Count | Should -Be 3
        $script:M.AccessLists['inside_in'].Count  | Should -Be 2
        $script:M.AccessLists['unused_acl'].Count | Should -Be 1
    }

    It 'groups crypto map lines by name (incl. the seq-less interface line)' {
        $script:M.CryptoMaps.Keys | Should -Contain 'outside_map'
        $script:M.CryptoMaps['outside_map'].Count | Should -Be 4
    }

    It 'builds the name IP-to-symbol map' {
        $script:M.NamesEnabled | Should -BeTrue
        $script:M.Names.ByIp['10.10.20.10'] | Should -Be 'inside-web-server'
        $script:M.Names.BySymbol['dmz-mail'] | Should -Be '10.10.30.25'
    }

    It 'captures object and object-group symbol tables (incl. B6 legacy forms)' {
        $script:M.Objects.Keys      | Should -Contain 'dmz-host'
        $script:M.ObjectGroups.Keys | Should -Contain 'nested-admins'
        $script:M.ObjectGroups.Keys | Should -Contain 'legacy-ports'     # object-group service tcp (B6)
        $script:M.ObjectGroups.Keys | Should -Contain 'routing-protos'   # object-group protocol (B6)
    }

    It 'collects management lines (ssh/telnet/http)' {
        ($script:M.Management.Ssh    | Where-Object { $_.Text -eq 'ssh 0.0.0.0 0.0.0.0 outside' }) | Should -Not -BeNullOrEmpty
        ($script:M.Management.Telnet | Where-Object { $_.Text -like 'telnet 10.10.20.0*' })        | Should -Not -BeNullOrEmpty
        ($script:M.Management.Http   | Where-Object { $_.Text -eq 'http server enable' })          | Should -Not -BeNullOrEmpty
    }
}

Describe 'Parser: disambiguations (NAT and webvpn)' {

    BeforeAll { $script:M = ConvertTo-AsaModel -Path $script:Insecure }

    It 'distinguishes object-NAT (indented child) from twice-NAT (top-level)' {
        # twice-NAT: exactly the top-level "source" form
        $script:M.TwiceNat.Count | Should -Be 1
        $script:M.TwiceNat[0].Text | Should -Match '^nat \(inside,outside\) source '
        # object-NAT: a nat line that is a child of an object network block
        $objNat = $script:M.Lines | Where-Object { $_.Text -eq 'nat (inside,outside) dynamic interface' }
        $objNat | Should -Not -BeNullOrEmpty
        $objNat.Indent | Should -BeGreaterThan 0
        $objNat.Parent.Text | Should -Match '^object network '
    }

    It 'distinguishes the two webvpn contexts (global vs group-policy nested)' {
        $webvpns = $script:M.Lines | Where-Object { $_.Text -eq 'webvpn' }
        $global  = $webvpns | Where-Object { $_.Indent -eq 0 }
        $nested  = $webvpns | Where-Object { $_.Indent -gt 0 }
        $global | Should -Not -BeNullOrEmpty
        $nested | Should -Not -BeNullOrEmpty
        $nested.Parent.Text | Should -Be 'group-policy ra-vpn attributes'
    }
}

Describe 'Parser: multi-line banner reassembly' {

    BeforeAll { $script:H = ConvertTo-AsaModel -Path $script:Hardened }

    It 'reassembles consecutive banner login lines' {
        $script:H.Banners.Keys | Should -Contain 'login'
        $script:H.Banners['login'].Count | Should -Be 3
        ($script:H.Banners['login'] -join "`n") | Should -Match 'UNAUTHORIZED ACCESS'
        ($script:H.Banners['login'] -join "`n") | Should -Match 'logged and monitored'
    }

    It 'keeps banner types separate' {
        $script:H.Banners['motd'].Count | Should -Be 1
    }
}

Describe 'Parser: hardened fixture integrity' {

    It 'places every line in file order' {
        $h = ConvertTo-AsaModel -Path $script:Hardened
        (Get-IntegrityProblems -Model $h).Count | Should -Be 0
    }
}

Describe 'TR-07 gate: clean parse of real sanitized configs' {

    It 'parses every real config with zero integrity problems' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\fixtures\real'))) {
        $real = Get-ChildItem -LiteralPath $script:RealDir -Filter '*.txt' -ErrorAction SilentlyContinue
        $real.Count | Should -BeGreaterOrEqual 2
        foreach ($f in $real) {
            $model = ConvertTo-AsaModel -Path $f.FullName
            $model.LineCount | Should -BeGreaterThan 0
            $problems = Get-IntegrityProblems -Model $model
            if ($problems.Count -gt 0) {
                throw "[x] $($f.Name) parsed with problems: $($problems -join '; ')"
            }
        }
    }
}
