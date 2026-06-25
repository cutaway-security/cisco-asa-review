# cisco-asa-review

Offline, read-only PowerShell tool that reviews a Cisco ASA firewall
configuration for security issues. Point it at a `show running-config` dump and
it returns a prioritized findings report — insecure management access, weak or
deprecated crypto, overly permissive access rules, missing logging and hardening,
and cleartext secrets — each finding backed by the exact config line and mapped
to the CIS Cisco ASA Benchmark and DISA Cisco ASA STIG.

It runs entirely on the analyst's machine. No internet, no device access, no data
leaves the host. The config is sensitive, and the tool treats it that way.

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

The full Markdown report is written to stdout. Three artifacts are also written
**into the same directory as the configuration file** (never overwriting it),
each with a timestamped name:

- a **Markdown** report (for consolidation with other reports / later review),
- a **CSV** findings file (machine-readable, with remediation-tracking columns),
- a self-contained **HTML** report (the client deliverable — see below).

Status messages go to the error/information stream so the stdout report stays
clean. Secret values are masked by default; `-RevealSecrets` opts out (and emits
a credential-bearing warning) only when you run it on a trusted host.

## Where it works

The tool analyzes a **Cisco ASA 9.x `show running-config`** text dump. What it
parses is the ASA *configuration syntax*, which is determined by the ASA software
version, not the appliance model — so the analysis is the same across the ASA
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

If your config is a single-context, routed-mode ASA 9.x device, the analysis is
the same regardless of which appliance produced it.

| Element | Requirement |
|---------|-------------|
| Shell | Windows PowerShell 5.1 (floor) or PowerShell 7+ |
| Modules | None — built-in cmdlets only |
| OS | Windows (analyst workstation) |
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
active-collection primitive.

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

**Version:** v0.2.
**Last updated:** 2026-06-24.

Implemented and gated (124 Pester tests green, plus an opt-in performance test):
the hierarchical parser, the support models (secret classifier, interface-role
model, recursive object-group resolution with cycle detection, doc-cited
defaults), a **58-check** catalog (CIS + DISA STIG) with commercial and DoD
profiles, Markdown + CSV output with default secret masking and remediation
tracking, and the single self-contained HTML deliverable (full findings +
inline-SVG topology + zone matrix, any-to-all-zones collapsed by default). The
parser is proven against two real sanitized configs (TR-07) and runs the full
pipeline on them as an anti-overfit guard; the checks produce exact true positives
and zero false positives on the synthesized fixtures; the HTML rendering is
visually verified; and a 20,000-line benchmark confirms sub-quadratic scaling.

**Validation bound:** no production ASA device or client configuration was
available during development. Validation relies on synthesized, syntactically
faithful ASA 9.x fixtures plus real sanitized configs from public sources. This
bound is stated in release notes until a real engagement config has been run
through the tool.

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
