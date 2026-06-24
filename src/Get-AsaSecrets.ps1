#Requires -Version 5.1
<#
.SYNOPSIS
    Classify ASA password/secret material and locate secret-bearing config lines.
.DESCRIPTION
    v0.1b-prep credential support (REQUIREMENTS FR-09/FR-10, CHECK_CATALOG B3).
    A misclassified hash is the highest-severity miss this tool can make, so the
    classifier is small, isolated, and tested first.

    Get-AsaPasswordClass classifies a single value+tag by storage mechanism:
        pbkdf2      strong  (tag 'pbkdf2' or a $sha512$... value)
        encrypted   weak legacy reversible/obfuscated
        nt-encrypted NT/MD4 hash  (lower-confidence value layout, CHECK_CATALOG B6)
        cleartext   no tag and not a recognized hash  (a finding)
        redacted    a sanitized '*****' value
    Per TSC-05 the security-relevant property is IsCleartext; the exact subtype
    of nt-encrypted is not gated.

    Get-AsaSecrets scans a parsed model for every secret-bearing construct
    (passwords, SNMP communities, AAA keys, NTP keys, tunnel-group PSKs) and
    returns a finding per secret with its class and IsCleartext flag. This is the
    surface the default-on masking (SR-04) must cover.
.EXAMPLE
    Get-AsaPasswordClass -Value '$sha512$5000$a==$b==' -Tag 'pbkdf2'   # -> pbkdf2
.EXAMPLE
    ConvertTo-AsaModel -Path .\asa.txt | ForEach-Object { Get-AsaSecrets -Model $_ }
#>

function Get-AsaPasswordClass {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [string]$Tag
    )
    if ($Value -eq '*****' -or $Value -match '^\*+$') { return 'redacted' }
    if ($Tag -eq 'pbkdf2' -or $Value -match '^\$sha512\$\d+\$[^$]+\$[^$]+$') { return 'pbkdf2' }
    if ($Tag -eq 'encrypted')    { return 'encrypted' }
    if ($Tag -eq 'nt-encrypted') { return 'nt-encrypted' }
    return 'cleartext'
}

function Get-AsaSecrets {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [pscustomobject]$Model
    )

    begin {
        $opt = [System.Text.RegularExpressions.RegexOptions]'Compiled, IgnoreCase'
        $rxEnable = [regex]::new('^enable password\s+(\S+)(?:\s+level\s+\d+)?(?:\s+(pbkdf2|encrypted))?\s*$', $opt)
        $rxPasswd = [regex]::new('^passwd\s+(\S+)(?:\s+(encrypted|pbkdf2))?\s*$', $opt)
        $rxUser   = [regex]::new('^username\s+\S+\s+password\s+(\S+)(?:\s+(pbkdf2|encrypted|nt-encrypted))?', $opt)
        $rxComm   = [regex]::new('^snmp-server community\s+(\S+)', $opt)
        $rxNtpKey = [regex]::new('^ntp authentication-key\s+\d+\s+\S+\s+(\S+)', $opt)
        $rxKey    = [regex]::new('^key\s+(\S+)', $opt)
        $rxPsk    = [regex]::new('^(?:ikev1 pre-shared-key|ikev2 (?:local|remote)-authentication pre-shared-key)\s+(\S+)', $opt)
        $rxAaaHost = [regex]::new('^aaa-server\b.*\bhost\b', $opt)
    }

    process {
        $found = [System.Collections.Generic.List[object]]::new()

        $emit = {
            param($node, $kind, $value, $class)
            $found.Add([pscustomobject]@{
                LineNo      = $node.LineNo
                Kind        = $kind
                Value       = $value
                Class       = $class
                IsCleartext = ($class -eq 'cleartext')
                Node        = $node
            })
        }

        foreach ($n in $Model.Lines) {
            if ($n.Kind -ne 'line') { continue }
            $t = $n.Text

            $m = $rxEnable.Match($t)
            if ($m.Success) { & $emit $n 'enable-password' $m.Groups[1].Value (Get-AsaPasswordClass -Value $m.Groups[1].Value -Tag $m.Groups[2].Value); continue }

            $m = $rxPasswd.Match($t)
            if ($m.Success) { & $emit $n 'passwd' $m.Groups[1].Value (Get-AsaPasswordClass -Value $m.Groups[1].Value -Tag $m.Groups[2].Value); continue }

            $m = $rxUser.Match($t)
            if ($m.Success) { & $emit $n 'username-password' $m.Groups[1].Value (Get-AsaPasswordClass -Value $m.Groups[1].Value -Tag $m.Groups[2].Value); continue }

            $m = $rxComm.Match($t)
            if ($m.Success) { & $emit $n 'snmp-community' $m.Groups[1].Value (Get-AsaPasswordClass -Value $m.Groups[1].Value -Tag $null); continue }

            $m = $rxNtpKey.Match($t)
            if ($m.Success) { & $emit $n 'ntp-key' $m.Groups[1].Value (Get-AsaPasswordClass -Value $m.Groups[1].Value -Tag $null); continue }

            # context-dependent secrets (children of specific blocks)
            $m = $rxKey.Match($t)
            if ($m.Success -and $null -ne $n.Parent -and $rxAaaHost.IsMatch($n.Parent.Text)) {
                & $emit $n 'aaa-key' $m.Groups[1].Value (Get-AsaPasswordClass -Value $m.Groups[1].Value -Tag $null); continue
            }

            $m = $rxPsk.Match($t)
            if ($m.Success) { & $emit $n 'tunnel-group-psk' $m.Groups[1].Value (Get-AsaPasswordClass -Value $m.Groups[1].Value -Tag $null); continue }
        }

        return ,$found.ToArray()
    }
}
