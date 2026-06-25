#Requires -Version 5.1
<#
.SYNOPSIS
    Mask secret values in an ASA config line for safe inclusion in output.
.DESCRIPTION
    Default-on masking (REQUIREMENTS SR-04). Replaces the value token of every
    recognized secret-bearing construct with [REDACTED], keeping the surrounding
    evidence legible. Includes a conservative fallback: any line containing a
    secret keyword (password/passwd/community/key/pre-shared-key) has its trailing
    value redacted even if the specific construct is not otherwise recognized, so
    a parser gap cannot leak a secret (ARCHITECTURE section 6).

    Masking replaces the value, not the whole line. Hashes are treated as secret
    (they are crackable) and masked too.
.PARAMETER Line
    A config line (raw or trimmed text).
.OUTPUTS
    [string] the line with secret values redacted.
.EXAMPLE
    Protect-AsaLine -Line 'snmp-server community publicstring'   # -> '... community [REDACTED]'
#>
function Protect-AsaLine {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Line
    )
    process {
        $s = $Line
        $opt = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        $R = '[REDACTED]'

        # Ordered, specific rules first.
        $rules = @(
            '(\bpre-shared-key\s+)(\S+)',                              # IKE PSK
            '(\bauthentication-key\s+\d+\s+\S+\s+)(\S+)',              # ntp authentication-key <id> <alg> <key>
            '(\bauth\s+(?:sha|md5)\s+)(\S+)',                         # snmp v3 auth
            '(\bpriv\s+(?:aes|3des|des)\s+(?:\d+\s+)?)(\S+)',         # snmp v3 priv
            '(\bcommunity\s+)(\S+)',                                   # snmp community
            '((?:enable\s+)?\bpassword\s+)(\S+)',                      # enable/username/group password
            '(^\s*passwd\s+)(\S+)',                                    # line password
            '(^\s*key\s+)(\S+)'                                        # aaa-server key child (also config-key)
        )
        foreach ($rx in $rules) {
            $s = [regex]::Replace($s, $rx, "`$1$R", $opt)
        }
        return $s
    }
}
