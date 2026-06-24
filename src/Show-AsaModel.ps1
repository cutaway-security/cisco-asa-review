#Requires -Version 5.1
<#
.SYNOPSIS
    Render a parsed ASA model for inspection (the v0.1a verbose dump, OR-04).
.DESCRIPTION
    Produces a human-readable view of the indentation tree and the
    repeated-prefix index, so a misparse can be diagnosed before any check is
    built on the model. Output is plain text (no emoji), suitable for the status
    stream.
.PARAMETER Model
    A model object from ConvertTo-AsaModel.
.PARAMETER TreeOnly
    Render only the indentation tree, not the index summary.
.OUTPUTS
    [string[]] the rendered lines.
.EXAMPLE
    ConvertTo-AsaModel -Path .\asa.txt | Show-AsaModel
#>
function Show-AsaModel {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [pscustomobject]$Model,

        [switch]$TreeOnly
    )

    process {
        $out = [System.Collections.Generic.List[string]]::new()
        $out.Add("[*] ASA model: $($Model.Source)")
        $out.Add("[*] lines=$($Model.LineCount) top-level=$($Model.TopLevel.Count) maxdepth=$($Model.MaxDepth)")
        $out.Add('')
        $out.Add('--- indentation tree ---')

        $render = {
            param($node)
            $prefix = '  ' * $node.Depth
            $tag = if ($node.Kind -ne 'line') { "($($node.Kind)) " } else { '' }
            $out.Add(("{0,5}: {1}{2}{3}" -f $node.LineNo, $prefix, $tag, $node.Text))
            foreach ($child in $node.Children) { & $render $child }
        }
        foreach ($n in $Model.TopLevel) { & $render $n }

        if (-not $TreeOnly) {
            $out.Add('')
            $out.Add('--- repeated-prefix index ---')
            $out.Add("names: enabled=$($Model.NamesEnabled) mappings=$($Model.Names.ByIp.Count)")
            $out.Add("access-lists: $($Model.AccessLists.Keys.Count) -> $((($Model.AccessLists.GetEnumerator() | ForEach-Object { '{0}({1})' -f $_.Key, $_.Value.Count }) -join ', '))")
            $out.Add("access-groups: $($Model.AccessGroups.Count)")
            $out.Add("crypto-maps: $($Model.CryptoMaps.Keys.Count)")
            $out.Add("banners: $((($Model.Banners.GetEnumerator() | ForEach-Object { '{0}({1} lines)' -f $_.Key, $_.Value.Count }) -join ', '))")
            $out.Add("tunnel-groups: $($Model.TunnelGroups.Keys.Count)")
            $out.Add("objects: $($Model.Objects.Keys.Count)  object-groups: $($Model.ObjectGroups.Keys.Count)")
            $out.Add("interfaces: $($Model.Interfaces.Count)")
            $out.Add("mgmt: ssh=$($Model.Management.Ssh.Count) telnet=$($Model.Management.Telnet.Count) http=$($Model.Management.Http.Count)")
            $out.Add("twice-nat: $($Model.TwiceNat.Count)")
        }

        return ,$out.ToArray()
    }
}
