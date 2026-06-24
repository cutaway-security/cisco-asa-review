# RESUME.md

## Current State

**Last Session**: 2026-06-24
**Branch**: claude-dev (6ae8d26 planning, b2ef872 Phase 1, d2ff8a9 Phase 2)
**Status**: Clean — Phase 3 (v0.1b-prep support models) complete and gated

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
  - `src/Get-AsaSecrets.ps1` (password classifier + secret scanner),
    `src/Get-AsaInterfaceRoles.ps1` (interface-role model),
    `src/Resolve-AsaReferences.ps1` (minimal name/object-group resolution),
    `data/asa-defaults.psd1` (8 doc-cited MVP absence defaults).
  - `tests/unit/SupportModels.Tests.ps1` — 20 tests. Full suite 56/56 green.

## In Progress

Nothing in progress. Phase 3 is complete and gated.

## Blockers

- **No real ASA device or client config** for end-to-end validation. Inherent
  constraint (OQ4); mitigated by the fixture + real-config strategy, stated as a
  release-note bound. (Real sanitized configs now obtained — TR-07 corpus ready.)

## Next Steps

1. Phase 4 (v0.1b check engine + output):
   - `data/check-catalog.psd1` (DR-04 schema) for the 15 MVP checks.
   - `src/Invoke-AsaChecks.ps1` — engine consuming catalog + model + defaults +
     interface-roles + secrets; presence and context-conditional absence.
   - `src/Write-AsaReport.ps1` — Markdown (stdout) + timestamped CSV; secret
     masking ON by default with conservative keyword fallback; status stream
     separated; deterministic ordering (NFR-06).
   - `Invoke-AsaReview.ps1` entry point (params, profile, exit codes, run summary).
   - Gate: exact seeded TP / zero FP on both fixtures (TSC-02/03); no verbatim
     secret in masked output (TSC-12); offline + read-only (TSC-11).
2. Optional process items (PLAN "Open process items"): ADRs, traceability matrix.
3. Run on Windows PowerShell 5.1 to confirm NFR-01 (dev host is pwsh 7.6.2).

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
