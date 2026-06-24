# RESUME.md

## Current State

**Last Session**: 2026-06-24
**Branch**: claude-dev (git initialized; 6ae8d26 planning, b2ef872 Phase 1)
**Status**: Clean — Phase 2 (v0.1a-core parser) complete and gated

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

## In Progress

Nothing in progress. Phase 2 is complete and gated.

## Blockers

- **No real ASA device or client config** for end-to-end validation. Inherent
  constraint (OQ4); mitigated by the fixture + real-config strategy, stated as a
  release-note bound. (Real sanitized configs now obtained — TR-07 corpus ready.)

## Next Steps

1. Phase 3 (v0.1b-prep support models):
   - Minimal object/object-group resolution (FR-05a) with a stated nesting depth
     and OR-03 "not assessed" beyond it.
   - Password-hash classifier (FR-09): pbkdf2/encrypted/nt-encrypted/cleartext;
     gate `nt-encrypted` as "not-cleartext" (TSC-05). Use the insecure fixture's
     `Secrets` block as the oracle.
   - `data/asa-defaults.psd1` (FR-08b, DR-06): MVP-15 absence defaults, each with
     a Cisco doc citation.
   - `src/Get-AsaInterfaceRoles.ps1` (FR-08a): nameif + security-level per
     interface; uRPF rule = security-level 0 OR nameif outside.
2. Phase 4: check engine + the 15 MVP checks + Markdown/CSV + masking; gate on
   the expected-findings oracle (exact TP / zero FP) and TSC-12 no-leak.
3. Optional process items (PLAN "Open process items"): ADRs, traceability matrix.
4. Run on Windows PowerShell 5.1 to confirm NFR-01 (dev host is pwsh 7.6.2).

## Open Questions

- Which two real sanitized configs to standardize on for TR-07, and confirm they
  are redistribution-safe to store locally (RESEARCH refs are candidates).
- Concrete SR-07 thresholds (10 MB / 4 KB / 10 levels are starting points to
  validate against the real configs).
- Defaults-model scope: exactly which ASA 9.x defaults the MVP-15 absence checks
  need (OQ-1), each with a Cisco doc citation.

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
