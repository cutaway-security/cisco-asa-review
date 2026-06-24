# cisco-asa-review

Offline, read-only PowerShell tool that reviews a Cisco ASA firewall
configuration for security issues. Point it at a `show running-config` dump and
it returns a prioritized findings report — insecure management access, weak or
deprecated crypto, overly permissive access rules, missing logging and hardening,
and cleartext secrets — each finding backed by the exact config line and mapped
to the CIS Cisco ASA Benchmark and DISA Cisco ASA STIG.

It runs entirely on the analyst's machine. No internet, no device access, no data
leaves the host. The config is sensitive, and the tool treats it that way.

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
        +--> run summary (status stream)
```

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

## Quick start (development)

```powershell
# one-time, per process
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# run a review (commercial profile is default)
.\Invoke-AsaReview.ps1 -ConfigPath .\asa-running-config.txt -OutputDirectory .\out > report.md

# DoD/STIG profile, reveal secrets on a trusted host
.\Invoke-AsaReview.ps1 -ConfigPath .\cfg.txt -Profile dod -RevealSecrets

# run the tests (Pester)
Invoke-Pester .\tests
```

## Status

**Version:** pre-implementation (planning complete; no code yet).
**Last updated:** 2026-06-24.

The discovery, research, requirements, success criteria, and architecture are
complete and have passed two rounds of multi-AI review. Implementation has not
started. The first milestone (v0.1a-core) is the hierarchical parser, proven in
isolation against parser unit tests and two real sanitized configs before any
check is built on it.

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
