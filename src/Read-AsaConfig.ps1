#Requires -Version 5.1
<#
.SYNOPSIS
    Read an ASA running-config text file into a normalized line array, with
    bounded, encoding-safe handling of malformed or hostile input.
.DESCRIPTION
    Implements the input-bounding requirements (REQUIREMENTS SR-07): a maximum
    file size, a maximum single-line length, and graceful failure rather than
    memory exhaustion. Normalizes CRLF/LF to LF and returns the lines verbatim
    (no trimming -- the parser needs leading whitespace for indentation).

    Read-only: the input file is never modified (SR-02). No network access.
.PARAMETER Path
    Path to the ASA running-config text file.
.PARAMETER MaxBytes
    Maximum allowed file size in bytes. Default 10 MB.
.PARAMETER MaxLineLength
    Maximum allowed single-line length in characters. Default 4096.
.OUTPUTS
    [string[]] the config lines (LF-normalized, untrimmed).
.EXAMPLE
    $lines = Read-AsaConfig -Path .\asa-running-config.txt
#>
function Read-AsaConfig {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [ValidateRange(1, 1073741824)]
        [int]$MaxBytes = 10485760,

        [ValidateRange(1, 1048576)]
        [int]$MaxLineLength = 4096
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "[x] Input file not found: $Path"
    }

    $info = Get-Item -LiteralPath $Path
    if ($info.Length -eq 0) {
        throw "[x] Input file is empty: $Path"
    }
    if ($info.Length -gt $MaxBytes) {
        throw ("[x] Input file too large ({0} bytes > {1} byte limit): {2}" -f $info.Length, $MaxBytes, $Path)
    }

    # Encoding-safe whole-file read (file size already bounded above).
    $raw = [System.IO.File]::ReadAllText($info.FullName)

    # Normalize line endings (CRLF / CR -> LF) then split.
    $raw = $raw -replace "`r`n", "`n" -replace "`r", "`n"
    $lines = $raw -split "`n"

    # Drop a single trailing empty element produced by a terminal newline.
    if ($lines.Count -gt 0 -and $lines[-1] -eq '') {
        $lines = $lines[0..($lines.Count - 2)]
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Length -gt $MaxLineLength) {
            throw ("[x] Line {0} exceeds maximum length ({1} > {2}): possible malformed input" -f ($i + 1), $lines[$i].Length, $MaxLineLength)
        }
    }

    Write-Verbose ("[*] Read {0}: {1} bytes, {2} lines" -f $Path, $info.Length, $lines.Count)
    return ,([string[]]$lines)
}
