#Requires -Version 5.1
<#
.SYNOPSIS
    Parse Cisco ASA running-config text into a queryable hierarchical model.
.DESCRIPTION
    The v0.1a-core parser (ARCHITECTURE.md sections 2-3, CHECK_CATALOG.md Part B).
    Builds two indices in a single pass:

      1. An indentation tree of line nodes (parent/child by leading-space depth),
         assembled with an indent stack. Every line is placed; an unknown line is
         preserved as a generic node and never corrupts surrounding structure.
      2. A repeated-prefix family index for the flat constructs that are grouped
         by a repeated key rather than by indentation: access-list, crypto map,
         name, banner (multi-line reassembly), tunnel-group, http/ssh/telnet,
         twice-NAT.

    Plus symbol tables (objects, object-groups, interfaces) captured as nodes,
    and the name (IP <-> symbol) map. Reference RESOLUTION is deliberately out of
    scope here -- that is v0.1b minimal resolution (FR-05a).

    No reference resolution, no checks, no network. Config content is inert text:
    no Invoke-Expression, no dynamic evaluation (SR-06).
.PARAMETER Path
    Path to an ASA running-config file (read via Read-AsaConfig).
.PARAMETER Lines
    Pre-read config lines (string array), as returned by Read-AsaConfig.
.PARAMETER MaxDepth
    Maximum indentation nesting depth before the input is treated as malformed.
    Default 10 (real ASA configs nest at most ~3 deep).
.OUTPUTS
    [pscustomobject] the parsed model (see the in-line schema below).
.EXAMPLE
    $model = ConvertTo-AsaModel -Path .\asa.txt
.EXAMPLE
    $model = Read-AsaConfig -Path .\asa.txt | ConvertTo-AsaModel
#>
function ConvertTo-AsaModel {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Lines', ValueFromPipeline)]
        [AllowEmptyCollection()]
        [string[]]$Lines,

        [ValidateRange(1, 1000)]
        [int]$MaxDepth = 10
    )

    begin {
        # Compiled, simply-anchored patterns (SR-07: no catastrophic backtracking).
        $opt = [System.Text.RegularExpressions.RegexOptions]'Compiled, IgnoreCase'
        $rx = @{
            Name        = [regex]::new('^name\s+(\S+)\s+(\S+)', $opt)
            AccessList  = [regex]::new('^access-list\s+(\S+)\s+', $opt)
            AccessGroup = [regex]::new('^access-group\s+(\S+)\s+', $opt)
            CryptoMap   = [regex]::new('^crypto map\s+(\S+)\s+', $opt)
            Banner      = [regex]::new('^banner\s+(motd|login|exec|asdm)(?:\s(.*))?$', $opt)
            TunnelGroup = [regex]::new('^tunnel-group\s+(\S+)\s+(\S+)', $opt)
            Object      = [regex]::new('^object\s+(network|service)\s+(\S+)', $opt)
            ObjectGroup = [regex]::new('^object-group\s+(network|service|protocol)\s+(\S+)', $opt)
            Interface   = [regex]::new('^interface\s+(\S+)', $opt)
            Ssh         = [regex]::new('^ssh(\s|$)', $opt)
            Telnet      = [regex]::new('^telnet(\s|$)', $opt)
            Http        = [regex]::new('^http(\s|$)', $opt)
            TwiceNat    = [regex]::new('^nat\s+\(', $opt)
        }
        $allLines = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Lines' -and $null -ne $Lines) {
            foreach ($l in $Lines) { $allLines.Add($l) }
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $readScript = Join-Path $PSScriptRoot 'Read-AsaConfig.ps1'
            if (-not (Get-Command -Name Read-AsaConfig -ErrorAction SilentlyContinue)) {
                . $readScript
            }
            foreach ($l in (Read-AsaConfig -Path $Path)) { $allLines.Add($l) }
            $source = $Path
        }
        else {
            $source = '<lines>'
        }

        $nodes      = [System.Collections.Generic.List[object]]::new()
        $topLevel   = [System.Collections.Generic.List[object]]::new()
        $stack      = [System.Collections.Generic.List[object]]::new()
        $observedMaxDepth = 0

        # ---- Pass 1: nodes + indentation tree -------------------------------
        for ($i = 0; $i -lt $allLines.Count; $i++) {
            $raw  = $allLines[$i]
            $noLead = $raw.TrimStart(' ')
            $indent = $raw.Length - $noLead.Length
            $text = $raw.Trim()

            $kind =
                if ($text -eq '')        { 'blank' }
                elseif ($text -eq '!')   { 'separator' }
                elseif ($raw -match '^\s*:') { 'metadata' }
                else                     { 'line' }

            $node = [pscustomobject]@{
                LineNo   = $i + 1
                Raw      = $raw
                Indent   = $indent
                Text     = $text
                Kind     = $kind
                Parent   = $null
                Children = [System.Collections.Generic.List[object]]::new()
                Depth    = 0
            }
            $nodes.Add($node)

            if ($kind -ne 'line') {
                # Non-structural lines attach at top level and never parent or nest.
                $topLevel.Add($node)
                continue
            }

            # Dedent: pop siblings/ancestors at >= this indent.
            while ($stack.Count -gt 0 -and $stack[$stack.Count - 1].Indent -ge $indent) {
                $stack.RemoveAt($stack.Count - 1)
            }

            if ($stack.Count -eq 0) {
                $node.Depth = 0
                $topLevel.Add($node)
            }
            else {
                $parent = $stack[$stack.Count - 1]
                $node.Parent = $parent
                $node.Depth = $parent.Depth + 1
                [void]$parent.Children.Add($node)
            }

            if ($node.Depth + 1 -gt $MaxDepth) {
                throw ("[x] Nesting too deep at line {0} (depth {1} > {2}): possible malformed input" -f $node.LineNo, ($node.Depth + 1), $MaxDepth)
            }
            if ($node.Depth -gt $observedMaxDepth) { $observedMaxDepth = $node.Depth }

            $stack.Add($node)
        }

        # ---- Pass 2: repeated-prefix families + symbol tables ----------------
        $names        = @{ ByIp = @{}; BySymbol = @{} }
        $namesEnabled = $false
        $accessLists  = @{}
        $accessGroups = [System.Collections.Generic.List[object]]::new()
        $cryptoMaps   = @{}
        $banners      = @{}
        $tunnelGroups = @{}
        $objects      = @{}
        $objectGroups = @{}
        $interfaces   = [System.Collections.Generic.List[object]]::new()
        $mgmtSsh      = [System.Collections.Generic.List[object]]::new()
        $mgmtTelnet   = [System.Collections.Generic.List[object]]::new()
        $mgmtHttp     = [System.Collections.Generic.List[object]]::new()
        $twiceNat     = [System.Collections.Generic.List[object]]::new()

        foreach ($n in $nodes) {
            if ($n.Kind -ne 'line') { continue }
            $t = $n.Text

            if ($t -eq 'names') { $namesEnabled = $true; continue }

            # name maps must be built first; only indent-0 'name' lines.
            if ($n.Indent -eq 0) {
                $m = $rx.Name.Match($t)
                if ($m.Success -and $t -match '^name\s') {
                    $ip = $m.Groups[1].Value; $sym = $m.Groups[2].Value
                    $names.ByIp[$ip] = $sym
                    $names.BySymbol[$sym] = $ip
                    continue
                }
            }

            if ($n.Indent -ne 0) { continue }   # remaining families are top-level

            if (($m = $rx.AccessList.Match($t)).Success) {
                $name = $m.Groups[1].Value
                if (-not $accessLists.ContainsKey($name)) {
                    $accessLists[$name] = [System.Collections.Generic.List[object]]::new()
                }
                [void]$accessLists[$name].Add($n); continue
            }
            if (($m = $rx.AccessGroup.Match($t)).Success) { [void]$accessGroups.Add($n); continue }
            if (($m = $rx.CryptoMap.Match($t)).Success) {
                $name = $m.Groups[1].Value
                if (-not $cryptoMaps.ContainsKey($name)) {
                    $cryptoMaps[$name] = [System.Collections.Generic.List[object]]::new()
                }
                [void]$cryptoMaps[$name].Add($n); continue
            }
            if (($m = $rx.Banner.Match($t)).Success) {
                $type = $m.Groups[1].Value.ToLowerInvariant()
                $btext = $m.Groups[2].Value
                if (-not $banners.ContainsKey($type)) {
                    $banners[$type] = [System.Collections.Generic.List[string]]::new()
                }
                [void]$banners[$type].Add($btext); continue
            }
            if (($m = $rx.TunnelGroup.Match($t)).Success) {
                $name = $m.Groups[1].Value
                if (-not $tunnelGroups.ContainsKey($name)) {
                    $tunnelGroups[$name] = [System.Collections.Generic.List[object]]::new()
                }
                [void]$tunnelGroups[$name].Add($n); continue
            }
            if (($m = $rx.Object.Match($t)).Success)      { $objects[$m.Groups[2].Value] = $n; continue }
            if (($m = $rx.ObjectGroup.Match($t)).Success) { $objectGroups[$m.Groups[2].Value] = $n; continue }
            if (($m = $rx.Interface.Match($t)).Success)   { [void]$interfaces.Add($n); continue }
            if ($rx.TwiceNat.IsMatch($t) -and $t -match '\ssource\s') { [void]$twiceNat.Add($n); continue }
            if ($rx.Ssh.IsMatch($t))    { [void]$mgmtSsh.Add($n); continue }
            if ($rx.Telnet.IsMatch($t)) { [void]$mgmtTelnet.Add($n); continue }
            if ($rx.Http.IsMatch($t))   { [void]$mgmtHttp.Add($n); continue }
        }

        [pscustomobject]@{
            Source       = $source
            LineCount    = $nodes.Count
            Lines        = $nodes
            TopLevel     = $topLevel
            MaxDepth     = $observedMaxDepth
            Names        = $names
            NamesEnabled = $namesEnabled
            AccessLists  = $accessLists
            AccessGroups = $accessGroups
            CryptoMaps   = $cryptoMaps
            Banners      = $banners
            TunnelGroups = $tunnelGroups
            Objects      = $objects
            ObjectGroups = $objectGroups
            Interfaces   = $interfaces
            Management   = [pscustomobject]@{ Ssh = $mgmtSsh; Telnet = $mgmtTelnet; Http = $mgmtHttp }
            TwiceNat     = $twiceNat
        }
    }
}
