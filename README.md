# Cisco ASA Firewall Review

Offline, read-only PowerShell tool that reviews a Cisco ASA firewall
configuration for security issues. Point it at a `show running-config` dump and
it returns a prioritized findings report — insecure management access, weak or
deprecated crypto, overly permissive access rules, missing logging and hardening,
and cleartext secrets — each finding backed by the exact config line (or an
explicit "absent" marker for a missing setting). Most findings map to the CIS
Cisco ASA Benchmark and DISA Cisco ASA STIG; a few are tool heuristics.

It runs entirely on the analyst's machine. No internet, no device access, no data
leaves the host. The config is sensitive, and the tool treats it that way.

> **Where this fits — and where it doesn't.** This is a stopgap, not the mature
> method. A proper firewall review correlates a device's configuration with the
> surrounding routers, switches, and firewalls to reason about end-to-end access
> paths and segmentation, and applies deep, device-specific checks across many
> product families. Commercial tools built for exactly that —
> [Network Perception NP-View](https://www.network-perception.com/) (cross-device
> access-path and segmentation analysis; NERC CIP-003/005) and
> [Titania Nipper](https://www.titania.com/products/nipper) (pentester-grade
> per-device audits with pass/fail compliance evidence across 180+ device types) —
> are what a team doing this work seriously should adopt.
>
> This project is for the gap before that: find real issues *now* on a single ASA
> config, offline, with nothing to install and no data leaving the host — and use
> what it surfaces to help justify acquiring those tools. The issues it flags map
> directly to the
> [SANS Five ICS Cybersecurity Critical Controls](https://www.sans.org/white-papers/five-ics-cybersecurity-critical-controls)
> (Tim Conway and Robert M. Lee): **Control 2, Defensible Architecture** — the
> zone/segmentation view and over-permissive access rules — and **Control 4,
> Secure Remote Access** — insecure management access and weak VPN crypto.

## Quick start

```powershell
# one-time, per process
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# run a review (commercial profile is default)
.\Invoke-AsaReview.ps1 -ConfigPath .\asa-running-config.txt

# DoD/STIG profile; reveal secrets only on a trusted host
.\Invoke-AsaReview.ps1 -ConfigPath .\cfg.txt -Profile dod -RevealSecrets
```

The full Markdown report is written to stdout. Three artifacts are also written
**into the same directory as the configuration file** (never overwriting it),
each with a timestamped name:

- a **Markdown** report (for consolidation with other reports / later review),
- a **CSV** findings file (machine-readable, with remediation-tracking columns),
- a self-contained **HTML** report (the client deliverable — see below).

Status messages go to stderr so the stdout report stays clean. Secret values are
masked by default; `-RevealSecrets` opts out (and emits a credential-bearing
warning) only when you run it on a trusted host. To run the test suite (a
development-only Pester 5.x dependency): `pwsh -File .\tests\Invoke-Tests.ps1`.

## At a glance

| | |
|---|---|
| Language | PowerShell (5.1 floor, 7+ compatible) |
| Dependencies | None at runtime (built-in cmdlets only); Pester 5.x for tests |
| Input | One Cisco ASA 9.x `show running-config` text file |
| Scope | Single-context, routed-mode ASA 9.x (best-effort otherwise) |
| Outputs | Markdown (stdout + file), CSV, self-contained HTML |
| Checks | 58 (CIS + DISA STIG; a few tool heuristics), commercial + DoD profiles |
| Network | None in the review path (one opt-in maintenance script uses the network) |
| License | GPL-3.0 |

## Example output

The snippets below come from running the tool against a synthesized test fixture
(`tests/fixtures/asa-9x-insecure.txt`), **not a live device** — no production or
client configuration is analyzed here. The fixture is deliberately insecure, so it
triggers a broad set of findings.

On a run, the status stream reports where the artifacts were written:

```text
[*] Parsed 147 lines from asa-9x-insecure.txt
[*] Profile: commercial | Checks evaluated: 58
[$] Report: ...\asa-9x-insecure_asa-review_20260625_083941.md
[$] CSV:    ...\asa-9x-insecure_asa-review_20260625_083941.csv
[$] HTML deliverable: ...\asa-9x-insecure_asa-report_20260625_083941.html
```

The Markdown report opens with a summary, then one block per finding:

```markdown
## Summary

- Findings: 39 (High: 11, Medium: 16, Low: 12)
- Informational (hygiene/cleanup): 5
- Not assessed: 0
- Checks evaluated: 58
- Config lines parsed: 147

## Findings

### [HIGH] ACL-ANY-ANY

- Category: access | Severity: High | Confidence: heuristic
- Authority: Cisco hardening guide (verified: False)
- Evidence (line 80): `access-list outside_in extended permit ip any any`
- Additional evidence lines: 1
  - line 81: `access-list inside_in extended permit ip object-group any-net object-group any-net`
- Rationale: A permit ip any any rule allows unrestricted traffic; it may be overly broad.
- Remediation: Review each permit ip any any rule and scope it to required sources, destinations, and services.
```

The CSV carries the same findings as rows, with remediation-tracking columns to
fill in later (`RemediationState` defaults to `Open`):

```text
"CheckId","Category","Severity","Status","Authority","Verified","Confidence","EvidenceLineNo","Evidence","Remediation","RemediationState","RemediationNotes"
"ACL-ANY-ANY","access","High","finding","Cisco hardening guide","False","heuristic","80","access-list outside_in extended permit ip any any","Review each permit ip any any rule and scope it to required sources, destinations, and services.","Open",""
"HYGIENE-UNUSED-ACL","hygiene","Informational","finding","tool heuristic","False","heuristic","84","access-list unused_acl extended permit udp any any eq domain","Review and remove the unused access-list if it is genuinely not needed.","Open",""
```

The self-contained HTML report carries the full findings detail plus the
inline-SVG zone topology and matrix; open it in a browser and use Print -> Save as
PDF for a PDF.

## How to read the report

Findings are sorted by severity, then by config line. Each carries the check id,
the authority (a CIS/STIG reference or "tool heuristic"), a `Confidence` value, and
either the exact config line as evidence or an explicit `absent` marker for a
missing setting.

| Tier | Meaning | In the risk count? |
|------|---------|--------------------|
| High / Medium / Low | Security findings, ordered by severity | Yes |
| Informational | Hygiene/cleanup (unused ACLs, inactive rules, no-IP interfaces) | No — tracked but excluded from the risk count |

A finding can also be **`not-assessed`**: the tool found the construct but could
not resolve it safely (an undefined reference, or a circular / too-deeply-nested
object-group). It is neither a pass nor a finding — review it by hand (see the
manual review checklist). "No findings" is not proof of a secure config; it means
the tool's checks did not fire.

## Troubleshooting

- **Execution policy.** `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
  applies to the current session only; rerun it per process.
- **PowerShell version.** 5.1 is the floor; the tool also runs on PowerShell 7+
  (`pwsh`).
- **Status vs report.** The Markdown report goes to stdout and status lines go to
  stderr, so `.\Invoke-AsaReview.ps1 -ConfigPath cfg.txt > review.md` captures only
  the report.
- **Empty result.** "No findings" means the checks did not fire, not that the
  config is secure — see the manual review checklist.

## Where it works

The tool analyzes a **Cisco ASA 9.x `show running-config`** text dump. What it
parses is the ASA *configuration syntax*, which is determined by the ASA software
version, not the appliance model — so the *parsing* is the same across the ASA
family running ASA 9.x:

- the ASA 5500-X series (5506-X, 5508-X, 5512-X, 5515-X, 5516-X, 5525-X, 5545-X,
  5555-X, 5585-X),
- Firepower appliances running the ASA image (Firepower 1000 / 2100 / 4100 / 9300
  in ASA mode),
- ASAv (virtual ASA).

The checks map to the CIS Cisco ASA Benchmark and the DISA Cisco ASA STIG, which
are written against the software, so they are not specific to any one model.

**Scope and assumptions:**

- **Single-context, routed mode** is what the tool is tuned for. Transparent
  (Layer 2) mode parses, but a few interface checks assume routed Layer 3
  interfaces. **Multiple-context** configurations (a system context plus
  sub-contexts in one dump) are not specifically modeled.
- **Routed-interface platforms.** The older switchport-based platforms (ASA 5505,
  and the integrated-switch 5506-X) express interfaces as VLANs/switchports; those
  still parse, but the interface-level checks (uRPF, unused-interface, BVI) are
  written for routed interfaces.
- **ASA 9.x.** Pre-9.0 (8.x and earlier) configs may parse but are not a target;
  the end-of-life reference and several checks assume the 9.x command set.

If your config is a single-context, routed-mode ASA 9.x device, the *parsing* is
the same regardless of which appliance produced it. A few checks are
version-conditional (e.g. SSH-version pinning is not applicable on 9.16+, and
end-of-life status depends on the train), so findings can differ across releases.

| Element | Requirement |
|---------|-------------|
| Shell | Windows PowerShell 5.1 (floor) or PowerShell 7+ |
| Modules | None — built-in cmdlets only |
| OS | Windows analyst workstation (PowerShell 7+ also runs on Linux/macOS) |
| Network | None — fully offline |
| Input | One Cisco ASA 9.x `show running-config` text file |

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
active-collection primitive. The repository does contain one opt-in maintenance
script, `Update-AsaEolData.ps1`, which refreshes the end-of-life reference over the
network; it is never part of a review, and the same guard test asserts the review
never calls it.

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
  [ Resolver ]  name map, object/object-group expansion (recursive)
        |
        v
  [ Check Engine ]  catalog (data) + structural checks (code)
        |            + ASA defaults model + interface-role model
        v
  Findings (id, severity, evidence, authority, remediation)
        |
        +--> Markdown report (stdout + timestamped file)  [secrets masked by default]
        +--> CSV findings (timestamped file)              [remediation-tracking columns]
        +--> HTML report (client deliverable)             [findings + inline-SVG topology + matrix]
        +--> run summary (status stream)
```

The design insight is that most real ASA findings are either buried in nested,
reference-laden structure (object-groups inside object-groups, ACLs referencing
objects) or are *absences* (no `logging enable`, no `ssh version 2`, no uRPF) —
neither of which flat `grep` can find. So the tool parses the config into a
queryable hierarchical model and reasons over what is present *and* what is
missing.

For a **client deliverable**, the tool writes a single self-contained **HTML
report** (`*_asa-report_*.html`) that consolidates the full findings detail and a
segmentation view. It opens in any web browser with nothing installed and no
internet: embedded CSS, a zone topology rendered as **inline SVG**, a zone-to-zone
connectivity matrix as a colored table, and **no JavaScript or external
references** (so it survives strict mail / secure-transfer gateways). For a PDF,
open it in a browser and choose **Print -> Save as PDF** — no tools required.

The segmentation view derives zones from interface `nameif` + `security-level`
and inter-zone flows from `access-group`-bound ACLs; `permit ip any any` exposures
(literal or object-group-expressed) are highlighted and tied to the offending ACL
line. A zone whose `permit ip any any` reaches every other zone is collapsed by
default into a single **ANY/ANY to ALL ZONES** badge (so the diagram stays
readable); the matrix and risk list remain exhaustive, and `-ExpandAnyAny` draws
every individual flow. This is a **best-effort, offline view** (not a commercial
segmentation tool): it shows *configured/allowed* flows, not end-to-end
reachability (NAT/routing/shadowing are not modeled).

## Manual review checklist

The tool is a fast first pass. The list below is where human judgment and
live-device checks add what static analysis can't — review these by hand when
accuracy matters or to catch unusual conditions.

**Risk the tool does not evaluate — check by hand**

1. **NAT exposure** — static NATs / port-forwards that publish internal hosts to
   less-trusted zones; effective reachability is ACL + NAT + routing together,
   which the tool does not combine.
2. **ACL shadowing & dead rules** — a broad earlier rule masking a later one, or
   rules that never match; confirm with `show access-list` hit counts on the live
   device.
3. **Over-permissive but not any/any** — wide subnets, "any" service/port, or
   object-groups whose *contents* are broad (e.g. a group named TRUSTED holding
   public ranges). Only literal/expanded any/any is auto-flagged.
4. **VPN posture** — tunnel-groups / group-policies: split-tunneling, weak or
   shared pre-shared keys, PSK vs certificate, group-policy permissions, default
   tunnel-group. The tool checks crypto *strength*, not VPN *policy*.
5. **Object / object-group contents** — eyeball the actual members of groups used
   in permit rules.

**Sanity-check the tool's own findings**

6. **`not-assessed` items** — follow up each (undefined references, circular or
   over-deep object-groups); the tool flagged that it couldn't resolve them.
7. **"Unused" / hygiene findings** — conservative by design (it under-flags);
   confirm before deleting, and note it may also miss some dead config.
8. **Secret completeness** — confirm every credential line was masked *and* that
   all were detected (VPN PSKs, RADIUS/TACACS keys, SNMPv3 keys, local users);
   masking falls back to keywords for unusual constructs.
9. **Absence findings** — an "absent" result means the parser didn't see the
   line; verify the feature isn't configured in a form it didn't recognize and
   that the secure-default assumption holds.

**Outside the config snapshot**

10. **Patch level / CVEs** — EoL *trains* are flagged, but not specific CVEs for a
    supported-but-vulnerable build; check the exact `X.Y(z)` against Cisco
    advisories.
11. **Certificate / trustpoint expiry** — present in config, but expiry isn't
    visible; verify on the device.
12. **Operational truth** — logging actually reaching a monitored SIEM, NTP
    actually synced, running-vs-startup drift, management plane truly isolated.

## Software version / end-of-life

The review flags the running ASA software train against an end-of-life status,
reading a **bundled offline reference** (`data/asa-eol.psd1`, a dated snapshot) —
the review itself never goes online. To refresh that reference, run the separate,
opt-in `Update-AsaEolData.ps1` on a connected machine with your own EoL feed URL;
it is the only script that uses the network and is never invoked by a review.
Always verify EoL status against Cisco's official lifecycle pages before relying
on it.

## Status

**Version:** v0.2a.
**Last updated:** 2026-06-25.

Implemented and gated (the full unit suite passes — 124 tests — plus an opt-in
performance test): the hierarchical parser, the support models (secret classifier,
interface-role model, recursive object-group resolution with cycle detection,
doc-cited defaults), a **58-check** catalog (CIS + DISA STIG, with a few tool
heuristics) across commercial and DoD profiles, Markdown + CSV output with default
secret masking and remediation tracking, and the single self-contained HTML
deliverable (full findings + inline-SVG topology + zone matrix, any-to-all-zones
collapsed by default). The parser is proven against two real sanitized configs
(TR-07) and runs the full pipeline on them as an anti-overfit guard; the checks
produce the expected true positives and zero false positives **on the synthesized
fixtures** (many checks are heuristic — see `Confidence` in the catalog — and may
over- or under-flag on real configs); the HTML rendering is visually verified; and
a standalone 20,000-line benchmark confirms sub-quadratic scaling. ("58 checks" is
the current catalog; "MVP-15" in the code and tests is the original core set.)

**Validation bound:** no production ASA device or client configuration was
available during development. Validation relies on synthesized, syntactically
faithful ASA 9.x fixtures plus real sanitized configs from public sources. This
bound is stated in release notes until a real engagement config has been run
through the tool.

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
