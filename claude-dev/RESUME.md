# RESUME.md

## Current State

**Last Session**: 2026-06-24
**Branch**: claude-dev (…, d2ff8a9 Phase 2, 9c3f3c8 Phase 3, Phase 4 pending commit)
**Status**: Clean — Phase 4 (v0.1b check engine) complete and gated; **v0.1b MVP reached**

## What Was Accomplished

- **Phase 0 (init):** full cutsec-init pipeline — discovery, research, vision,
  requirements, success criteria, two multi-AI passes, architecture, orientation
  files. Committed as 6ae8d26.
- **Phase 1 (test environment + fixtures), gate PASSED:**
  - Two synthesized fixtures: `tests/fixtures/asa-5515-insecure.txt`
    (construct-complete, triggers all 15 MVP findings) and `asa-5515-hardened.txt`
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
  - `tests/fixtures/asa-5515-hygiene.txt` + `tests/unit/Hygiene.Tests.ps1`. Suite
    108/108 green; end-to-end + HTML render re-verified; crypto-only ACL not flagged.

- **v0.2 catalog coverage Slices 1-4 (2026-06-24):** Slice 1 (+8 data-driven),
  Slice 2 (+4 numeric/conditional), Slice 3 (+8 AAA depth), Slice 4 (+5 crypto
  strength: IKE/IPsec SHA-1 integrity, DH-14, AES-128, weak SSL cipher). Catalog
  = **45 checks**. `Coverage.Tests.ps1` gates TP/TN. Suite 113/113.

## In Progress

v0.2 catalog coverage, slice by slice (data-driven checks first). Next slices:
more catalog checks; then deep resolution (FR-05b), version/EoL table, second
fixture, perf. On `claude-dev` (issue #1 + Slice 1 not yet released).

## Blockers

- **No real ASA device or client config** for end-to-end validation. Inherent
  constraint (OQ4); mitigated by the fixture + real-config strategy, stated as a
  release-note bound. (Real sanitized configs now obtained — TR-07 corpus ready.)

## Next Steps

1. Decide whether to release issue #1 to `main` (would be v0.1d) per
   RELEASE_TO_MAIN.md, or bundle it with the v0.2 catalog coverage first.
2. Continue Phase 6 v0.2 catalog coverage (remaining CIS/STIG checks, deep
   resolution, version/EoL, second fixture).
3. Windows PowerShell 5.1 verification (NFR-01).
2. Still pending for a full "shipped" claim: run on **Windows PowerShell 5.1**
   (TSC-09/NFR-01; PSv7 is now validated), a runtime egress-monitor check (TSC-11),
   and a findings-accuracy review against a real engagement config.
3. Phase 5 (v0.2 coverage): remaining CIS/STIG catalog; deep recursive resolution
   (FR-05b); undefined-reference + unbound-ACL heuristics (FR-13); version/EoL
   table (FR-15); second independent fixture (TR-05).
4. Optional process items (PLAN "Open process items"): ADRs, traceability matrix.

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
