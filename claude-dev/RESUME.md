# RESUME.md

## Current State

**Last Session**: 2026-06-24
**Branch**: claude-dev
**Status**: **v0.2a released to `main`** (latest). 58-check catalog, deep
resolution, version/EoL, perf-verified, generalized to the ASA 9.x family
(model-agnostic), plus a README Manual review checklist. Default suite 124 passed
/ 1 skipped (opt-in perf).

## What Was Accomplished

- **Phase 0 (init):** full cutsec-init pipeline — discovery, research, vision,
  requirements, success criteria, two multi-AI passes, architecture, orientation
  files. Committed as 6ae8d26.
- **Phase 1 (test environment + fixtures), gate PASSED:**
  - Two synthesized fixtures: `tests/fixtures/asa-9x-insecure.txt`
    (construct-complete, triggers all 15 MVP findings) and `asa-9x-hardened.txt`
    (true-negative oracle, multi-line banner).
  - `tests/fixtures/expected-findings.psd1` — the oracle fixing the 15 MVP check
    IDs and per-fixture MustFire/MustNotFire/Secrets/ConstructsPresent.
  - Two real sanitized configs (HQ-FW2 9.18, ASABuzzNick) in
    `tests/fixtures/real/` (gitignored, one-time local fetch).
  - Pester 5.7.1 installed (dev dependency); harness `tests/Invoke-Tests.ps1` +
    `tests/unit/Corpus.Tests.ps1`. Result: 15/15 green, exit 0, no network.

- **Phase 2 (v0.1a-core parser), gate PASSED:**
  - `src/Read-AsaConfig.ps1` (bounded reader, SR-07), `src/ConvertTo-AsaModel.ps1`
    (indentation tree + repeated-prefix index + symbol tables + name map),
    `src/Show-AsaModel.ps1` (verbose dump, OR-04).
  - `tests/unit/Parser.Tests.ps1` — 21 parser tests incl. the TR-07 real-config
    gate and a preorder-line-number integrity invariant.
  - Full suite: 36/36 green, exit 0. Both real configs parse with zero integrity
    problems; dump cross-validates expected construct counts.
- **Phase 3 (v0.1b-prep support models), gate PASSED:**
  - `src/Get-AsaSecrets.ps1`, `src/Get-AsaInterfaceRoles.ps1`,
    `src/Resolve-AsaReferences.ps1`, `data/asa-defaults.psd1` (8 doc-cited).
  - `tests/unit/SupportModels.Tests.ps1` — 20 tests. Suite 56/56 green.
- **Phase 4 (v0.1b check engine + output), gate PASSED — v0.1b MVP reached:**
  - `data/check-catalog.psd1` (15 MVP checks), `src/Invoke-AsaChecks.ps1`,
    `src/checks/structural.ps1` (4 code detectors), `src/Protect-AsaSecret.ps1`
    (masking), `src/Write-AsaReport.ps1` (MD+CSV next to config), and the
    `Invoke-AsaReview.ps1` entry point.
  - `tests/unit/Checks.Tests.ps1` + `tests/unit/Guard.Tests.ps1`. Suite 73/73 green.
  - End-to-end CLI verified on a config copy: 15 findings, secrets masked
    (`community [REDACTED]`), no leaks, input unmodified, outputs next to config.

- **Published + branch model (2026-06-24):** pushed to private repo
  `cutaway-security/cisco-asa-review`. `main` = release-only (no Claude files,
  orphan history); `claude-dev` = development. Tag `v0.1b` on the main release
  commit. Procedure in `claude-dev/RELEASE_TO_MAIN.md`.
- **Real-host validation (2026-06-24, user-reported):** cloned the repo and ran
  the tool under **PowerShell 7** — executed end to end and generated both the
  Markdown and CSV reports correctly. Reports look good.

- **Phase 5 (segmentation visualization), gate PASSED (2026-06-24):**
  `Get-AsaZoneModel.ps1` + `Write-AsaSegmentation.ps1` (Mermaid topology + zone
  matrix + risk-flow list); `Segmentation.Tests.ps1` (14 tests).
- **Phase 5b (consolidated HTML deliverable), gate PASSED (2026-06-24):**
  - `src/Write-AsaHtmlReport.ps1`: single self-contained HTML = findings +
    inline-SVG topology + colored matrix; embedded CSS, no JS, no external refs;
    masking; deterministic. Browser Print->Save-as-PDF for PDF.
  - Wired into entry point (always produced). `HtmlReport.Tests.ps1` (9 tests).
  - Suite 98/98 green. **Rendering visually verified** via wkhtmltoimage (WebKit)
    and the PDF path via wkhtmltopdf — the inline SVG renders realistically
    (addressed the "SVG may not display as coded" concern with evidence).
- **Phase 5c (any-to-all-zones collapse), gate PASSED (2026-06-24):**
  - Zone model computes `CollapsedSources`; HTML SVG + Mermaid collapse a source's
    "any-any to all zones" into a single badge **by default**, with `-ExpandAnyAny`
    to draw every flow. Matrix + risk list stay exhaustive. Suite 103/103 green;
    collapsed render visually verified as de-cluttered. Entry point now creates a
    missing `-OutputDirectory`.

- **Phase 6 / GitHub issue #1 COMPLETE (2026-06-24), gate PASSED:**
  - `src/Get-AsaReferenceIndex.ps1`; five hygiene detectors in `checks/structural.ps1`
    (unused ACL/object/object-group, inactive/expired rules, no-ip interface, BVI);
    engine emits one finding per detection; Informational severity tier.
  - CSV: RemediationState/RemediationNotes + Informational rows. HTML: full
    findings detail (all evidence). Removed `Write-AsaSegmentation.ps1` + the
    segmentation `.md` output.
  - `tests/fixtures/asa-9x-hygiene.txt` + `tests/unit/Hygiene.Tests.ps1`. Suite
    108/108 green; end-to-end + HTML render re-verified; crypto-only ACL not flagged.

- **v0.2 catalog coverage COMPLETE — Slices 1-7 (2026-06-24):** S1 (+8 data),
  S2 (+4 numeric/conditional), S3 (+8 AAA depth), S4 (+5 crypto strength), S5 (+4
  logging/monitoring), S6 (+3 access control), S7 (+4 interface hardening:
  IF-SCANNING-THREAT, IF-THREAT-STATS, IF-SAME-SECURITY, DNS-LOOKUP). Catalog =
  **56 checks** (15 MVP + 36 v0.2 + 5 hygiene). Suite 113/113. Commercial catalog
  coverage done; DoD-profile checks optional follow-on.

- **v0.2 deep resolution (FR-05b) + undefined-ref (2026-06-24):**
  `Resolve-AsaNetworkGroup` now fully recurses nested group-object with cycle
  detection (MaxGroupDepth 16; not-assessed only on cycle/undefined/backstop);
  ACL-ANY-ANY now catches deeply-nested any-any. Added REF-UNDEFINED (dangling
  references). Catalog = **57 checks**. Suite 115/115.

- **v0.2 version/EoL (FR-15) + second fixture / anti-overfit (TR-05) (2026-06-24):**
  - `data/asa-eol.psd1` — bundled EoL reference, snapshot dated 2026-06-24 (the
    review reads this, never the network). Trains 9.1-9.14 = EoL, 9.16-9.22 =
    Supported; ASA5515 hardware end-of-support. Disclaimer to verify against Cisco.
  - `Test-AsaVersionEol` + VERSION-EOL catalog entry (Medium): EoL train -> finding,
    supported -> none, unlisted -> not-assessed.
  - **Offline preserved:** the internet check lives in a SEPARATE opt-in tool,
    `Update-AsaEolData.ps1` (the only network script; not in the review path). It
    fetches an EoL feed and rewrites the reference, else keeps the bundled one
    ("check the internet, else use the reference"). Guard test asserts neither the
    entry point nor any `src/` file invokes the updater.
  - **TR-05 anti-overfit:** `tests/unit/Robustness.Tests.ps1` runs the full
    pipeline (model + zones + reference index + checks) on the two independent real
    sanitized configs; asserts clean run and well-formed findings. Skips if absent.
  - Hardened fixture bumped to `ASA Version 9.20(2)` (VERSION-EOL TN). New tests:
    `EolData.Tests.ps1`. Catalog = **58 checks**. Suite **124/124** green.

- **v0.2 20k-line perf benchmark (NFR-04) + quadratic fix (2026-06-24):**
  - `tests/perf/New-AsaLargeConfig.ps1` (deterministic large-config generator) +
    `tests/perf/Measure-AsaPerf.ps1` (times parse + full pipeline at 2.5k/5k/10k/20k,
    fits a growth exponent and a top-two doubling factor; PASS = sub-quadratic).
  - **Benchmark surfaced a real quadratic:** `Get-AsaReferenceIndex` scanned every
    line for every entity (O(entities x lines)); 20k pipeline was **24.5s**,
    doubling factor 4.28x. Fixed with an inverted token index (token -> nodes,
    one pass): now **5.1s**, doubling factor **1.85x**, parser 251ms (exponent
    0.54). Behavior unchanged (hygiene/unused tests still green).
  - `tests/unit/Performance.Tests.ps1` — opt-in (env `ASA_RUN_PERF`) scaling
    regression guard; skipped in the default suite to avoid timing flakiness.
  - Default suite **124 passed / 1 skipped**; perf test passes when opted in.

- **Generalized to ASA 9.x family + v0.2 release (2026-06-24):**
  - Repositioned the tool from "ASA 5515" to the **ASA 9.x family** (analysis is
    set by ASA *software* syntax, not the appliance model). Renamed fixtures
    `asa-5515-*.txt` -> `asa-9x-*.txt` (git mv; content untouched, so insecure
    line-number assertions hold) and updated all test references; suite green.
  - **README rewrite:** moved Quick Start to the top (after the description),
    added a "Where it works" section (ASA 5500-X / Firepower-in-ASA-mode / ASAv;
    single-context routed-mode assumption; switchport-platform and pre-9.0
    caveats), fixed the stale segmentation `.md` description (topology is now
    inline-SVG in the HTML only), refreshed Status to 58 checks / 124 tests, and
    dropped the 5515-origin references. Generalized scope wording in VISION /
    REQUIREMENTS / TEST_ENVIRONMENT / SUCCESS_CRITERIA (history in DISCOVERY /
    RESEARCH / goal.md left intact).
  - **Released to `main` as v0.2** per RELEASE_TO_MAIN.md (orphan rebuild, no
    Claude files), tag `v0.2`.

- **Manual review checklist + v0.2a release (2026-06-24):**
  - Added a README **Manual review checklist** (12 items, 3 buckets: risk the tool
    does not evaluate — NAT exposure, ACL shadowing, over-permissive non-any/any,
    VPN policy, object-group contents; sanity-checks on its own findings —
    not-assessed, unused/hygiene, secret completeness, absence findings; and items
    outside the config snapshot — CVEs beyond EoL train, cert expiry, operational
    truth). Docs-only; no code change.
  - **Released to `main` as v0.2a**, tag `v0.2a`. The documented `checkout -f`
    caveat in RELEASE_TO_MAIN.md made the orphan rebuild clean (no abort).

## In Progress

**v0.2a released to `main`** (docs-only over v0.2). Nothing open in v0.2.

## Blockers

- **No real ASA device or client config** for end-to-end validation. Inherent
  constraint (OQ4); mitigated by the fixture + real-config strategy, stated as a
  release-note bound. (Real sanitized configs now obtained — TR-07 corpus ready.)

## Next Steps

1. Still pending for a full "shipped" claim: run on **Windows PowerShell 5.1**
   (TSC-09/NFR-01; PSv7 is now validated), a runtime egress-monitor check (TSC-11),
   and a findings-accuracy review against a real engagement config.
2. Optional next milestone (v0.3): ACL shadowing/redundancy; DoD-profile-specific
   checks; process items (ADRs, traceability matrix). Wire the dormant hardware-EoL
   data into a check if per-model hardware EoL findings are wanted.

## Open Questions

- (RESOLVED) TR-07 real configs: HQ-FW2 (9.18) + ASABuzzNick obtained, stored
  locally and gitignored.
- (RESOLVED) Defaults-model scope (OQ-1): the 8 MVP absence/conditional checks,
  doc-cited in `data/asa-defaults.psd1`.
- SR-07 thresholds (10 MB / 4 KB / 10 levels) held up on both real configs;
  revisit only if a real engagement config exceeds them.
- Phase 4: confirm the conservative masking keyword set catches the SNMP host
  inline community (`snmp-server host ... community X`), which the classifier
  currently captures only on the standalone `snmp-server community` line.

## Files Modified This Session

| File | Change |
|------|--------|
| background/goal.md | Created — engagement goal + constraints |
| claude-dev/DISCOVERY_NOTES.md | Created — discovery, R1-R5, OQ4 |
| claude-dev/20260624_asa-config-analysis_RESEARCH.md | Created — prior-art survey |
| claude-dev/CHECK_CATALOG.md | Created — checks + parser grammar |
| claude-dev/VISION.md | Created + 2 review passes applied |
| claude-dev/REQUIREMENTS.md | Created + 2 review passes applied |
| claude-dev/SUCCESS_CRITERIA.md | Created + 2 review passes applied |
| claude-dev/ARCHITECTURE.md | Created + review pass 2 applied |
| claude-dev/PLAN.md | Created |
| claude-dev/RESUME.md | Created (this file) |
| claude-dev/TEST_ENVIRONMENT.md | Created |
| claude-dev/VIBE_HISTORY.md | Created — first entry |
| claude-dev/code-standards/powershell.md | Copied for self-containment |
| CLAUDE.md, README.md, LICENSE, .gitignore | Created |
| .ai-reviews/20260624-094932/, .ai-reviews/20260624-101250/ | Review outputs + syntheses |
