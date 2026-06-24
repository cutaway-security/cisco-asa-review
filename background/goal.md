# Goal — cisco-asa-review

## Stated goal (from engagement)

Build a PowerShell-based tool to analyze a Cisco ASA 5515 firewall
configuration dump (the `running-config` / firewall ruleset). The analyst has
been tasked with reviewing the firewall configuration for security issues and
needs a script to assist that analysis.

## Constraints

- **No online / web-based analysis tools.** The configuration is sensitive and
  must not leave the analyst's machine. All processing is local and offline.
- **PowerShell only.** The analyst's available runtime is PowerShell; the
  analysis must run there (no Python/Linux toolchain assumed on the analysis
  host).
- **Prior art first.** Existing open-source ASA config analysis scripts/tools
  must be researched as prior art before designing, to avoid reinventing solved
  parsing/checking and to align findings with established hardening guidance.

## Input

- A single Cisco ASA 5515 configuration dump (text), produced from
  `show running-config` (or equivalent saved config). Software family: ASA 9.x
  era hardware (5515-X).

## Deliverable

- A PowerShell tool that parses the ASA config offline and reports
  security-relevant findings (insecure management, weak access rules,
  permissive ANY rules, weak crypto, missing hardening, etc.) in a reviewable
  report format.
