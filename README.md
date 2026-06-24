# cisco-asa-review

Offline, read-only PowerShell tool that reviews a Cisco ASA firewall
configuration for security issues. Point it at a `show running-config` dump and
it returns a prioritized findings report — insecure management access, weak or
deprecated crypto, overly permissive access rules, missing logging and hardening,
and cleartext secrets — each finding backed by the exact config line and mapped
to the CIS Cisco ASA Benchmark and DISA Cisco ASA STIG.

It runs entirely on the analyst's machine. No internet, no device access, no data
leaves the host. The config is sensitive, and the tool treats it that way.

## Passive and offline by design

This is a static text analyzer. It is the opposite of a scanner. Concretely, the
tool:

- **Never connects to an ASA** or any device. It performs no scanning, no SSH, no
  SNMP, no probing of any kind.
- **Makes no network calls at all** — no downloads, no DNS lookups, no telemetry,
  no update checks. The reference URLs in its findings are inert text, never
  fetched.
- **Only reads** the configuration file you give it, and **never modifies** it.
- Treats the config as inert data — it is parsed, never executed.

The analyst exports the `show running-config` out-of-band through their own
authorized means and hands the tool a text file; the tool does not perform that
collection step. A static guard test (`tests/unit/Guard.Tests.ps1`) enforces this
boundary in code — it fails the build if any tool script introduces a network or
active-collection primitive. Secret values discovered in the config are masked in
the output by default.

## How it works

```
ASA running-config (text)
        |
        v
  [ Reader ]  bounded, encoding-safe load
        |
        v
  [ Parser ]  indentation tree + repeated-prefix index   <- the core
        |
        v
  [ Resolver ]  name map, object/object-group expansion
        |
        v
  [ Check Engine ]  catalog (data) + structural checks (code)
        |            + ASA defaults model + interface-role model
        v
  Findings (id, severity, evidence, authority, remediation)
        |
        +--> Markdown report (stdout)         [secrets masked by default]
        +--> CSV findings (timestamped file)
        +--> Segmentation + data-flow map     [Mermaid topology + zone matrix]
        +--> HTML report (client deliverable) [findings + inline-SVG topology + matrix]
        +--> run summary (status stream)
```

For a **client deliverable**, the tool also writes a single self-contained
**HTML report** (`*_asa-report_*.html`) that consolidates the findings and the
segmentation map. It opens in any web browser with nothing installed and no
internet: embedded CSS, the topology as inline SVG, the matrix as a colored
table, and **no JavaScript or external references** (so it survives strict mail/
secure-transfer gateways). For a PDF, open it in a browser and choose
**Print -> Save as PDF** — no tools required. The Markdown and CSV remain as
working/machine-readable artifacts; the Mermaid `.md` is for renderer-equipped
contexts (VS Code / GitLab / GitHub).

Alongside the findings, the tool also writes a **segmentation + data-flow map**
(a separate timestamped Markdown file): a zone-level Mermaid topology plus a
zone-to-zone connectivity matrix, deriving zones from interface `nameif` +
`security-level` and inter-zone flows from `access-group`-bound ACLs.
`permit ip any any` exposures (literal or object-group-expressed) are highlighted
and tied to the offending ACL line. This is a **best-effort, offline stop-gap**
(not a commercial segmentation tool): it shows *configured/allowed* flows, not
end-to-end reachability (NAT/routing/shadowing are not modeled). The Mermaid is
plain text — it renders locally in VS Code / GitLab / GitHub with no online tool.

The design insight is that most real ASA findings are either buried in nested,
reference-laden structure (object-groups inside object-groups, ACLs referencing
objects) or are *absences* (no `logging enable`, no `ssh version 2`, no uRPF) —
neither of which flat `grep` can find. So the tool parses the config into a
queryable hierarchical model and reasons over what is present *and* what is
missing.

## Runtime

| Element | Requirement |
|---------|-------------|
| Shell | Windows PowerShell 5.1 (floor) or PowerShell 7+ |
| Modules | None — built-in cmdlets only |
| OS | Windows (analyst workstation) |
| Network | None — fully offline |
| Input | One Cisco ASA 9.x `show running-config` text file |

## Quick start

```powershell
# one-time, per process
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# run a review (commercial profile is default)
.\Invoke-AsaReview.ps1 -ConfigPath .\asa-running-config.txt

# DoD/STIG profile; reveal secrets only on a trusted host
.\Invoke-AsaReview.ps1 -ConfigPath .\cfg.txt -Profile dod -RevealSecrets

# run the tests (Pester 5.x; development-only dependency)
pwsh -File .\tests\Invoke-Tests.ps1
```

The Markdown report is written to stdout. A timestamped Markdown report and CSV
findings file are also written **into the same directory as the configuration
file** (never overwriting the config). Status messages go to the error/information
stream so the stdout report stays clean. Secret values are masked by default.

## Status

**Version:** v0.1b (MVP checks) complete.
**Last updated:** 2026-06-24.

Implemented and gated (73/73 Pester tests green): the hierarchical parser
(v0.1a-core), the v0.1b-prep support models (secret classifier, interface-role
model, minimal object-group resolution, doc-cited defaults), and the v0.1b check
engine running the 15 high-signal MVP checks with Markdown + CSV output and
default secret masking. The parser is proven against two real sanitized configs
(TR-07); the checks produce exact true positives and zero false positives on the
synthesized fixtures.

**Validation bound:** no production ASA 5515 device or client config is available
for development. Validation relies on a synthesized, syntactically faithful ASA
5515 fixture plus real sanitized configs from public sources. This bound is
stated in release notes until a real engagement config has been run through the
tool.

## Companion docs

Planning and design live in [`claude-dev/`](claude-dev/):

- [VISION.md](claude-dev/VISION.md) — strategic direction and scope
- [REQUIREMENTS.md](claude-dev/REQUIREMENTS.md) — structured requirements
- [SUCCESS_CRITERIA.md](claude-dev/SUCCESS_CRITERIA.md) — measurable gates
- [ARCHITECTURE.md](claude-dev/ARCHITECTURE.md) — design and rationale
- [CHECK_CATALOG.md](claude-dev/CHECK_CATALOG.md) — security checks + parser grammar
- [20260624_asa-config-analysis_RESEARCH.md](claude-dev/20260624_asa-config-analysis_RESEARCH.md) — prior-art survey
- [PLAN.md](claude-dev/PLAN.md) — roadmap and phases

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
