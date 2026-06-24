# PLAN.md — cisco-asa-review

## Project Goal

Deliver an offline, read-only, pure-PowerShell tool that parses a Cisco ASA 9.x
`show running-config` dump and produces a prioritized, evidence-backed security
findings report (Markdown + CSV), mapped to CIS Cisco ASA + DISA Cisco ASA STIG,
with no network and no device access.

## Current Phase

**Phase**: Phase 1 — Test environment + fixtures
**Status**: Complete (2026-06-24) — gate passed: 15/15 Pester tests green,
fixtures + real configs present locally
**Focus**: Next is Phase 2 — build and gate the v0.1a-core parser.

## Phases

Each phase produces real, tested code and carries an objective acceptance gate.
The v0.1a / v0.1b split derisks the load-bearing parser before checks consume it.

### Phase 1: Test environment + fixtures

**Status**: Complete (2026-06-24)

- [x] Author the synthesized ASA 5515 fixtures: `asa-5515-insecure.txt`
      (construct-complete incl. B6 legacy object-group forms, nt-encrypted,
      3-deep group-policy nesting, both NAT shapes; triggers all 15 MVP findings)
      and `asa-5515-hardened.txt` (true-negative oracle; multi-line banner for
      parser reassembly).
- [x] `tests/fixtures/expected-findings.psd1` — the validation oracle; fixes the
      15 MVP check IDs and the MustFire / MustNotFire / Secrets / ConstructsPresent
      assertions.
- [x] Obtain two real sanitized ASA configs (HQ-FW2 9.18, ASABuzzNick) into
      `tests/fixtures/real/` (gitignored), one-time local fetch — not fetched by
      the test harness.
- [x] Pester 5.7.1 harness (`tests/Invoke-Tests.ps1` + `tests/unit/Corpus.Tests.ps1`),
      runs offline, no device, no network.

**Acceptance gate**: PASSED — 15/15 Pester tests green; both synthesized fixtures
and the manifest validate; both real configs present locally; no network calls in
test code.

### Phase 2: v0.1a-core — Parser foundation (load-bearing)

**Status**: Not Started

- [ ] `Read-AsaConfig.ps1`: bounded, encoding-safe load with SR-07 thresholds
      (~10 MB file, ~4 KB line, ~10 nesting).
- [ ] `ConvertTo-AsaModel.ps1`: indentation tree (indent stack) + repeated-prefix
      family index, line-number + raw-text retained per node.
- [ ] `name` map extraction; verbose model dump (OR-04).
- [ ] Parser unit tests (TR-03): nesting 2-3 deep, repeated-prefix grouping,
      name resolution, multi-line banner reassembly, two-NAT / two-webvpn
      disambiguation.

**Acceptance gate (staged guard, parser tier)**: 100% TR-03 parser tests pass AND
the parser cleanly parses both real sanitized configs (TR-07 operational
definition) with no misassigned lines.

### Phase 3: v0.1b-prep — Support models

**Status**: Not Started

- [ ] Minimal object/object-group resolution (FR-05a), stated nesting depth,
      "not assessed" (OR-03) beyond it.
- [ ] Password-hash classifier (FR-09): pbkdf2/encrypted/nt-encrypted/cleartext;
      `nt-encrypted` gated as "not-cleartext" (TSC-05).
- [ ] `asa-defaults.psd1` (FR-08b, DR-06): MVP-15 absence defaults, each with a
      Cisco ASA 9.x doc citation.
- [ ] `Get-AsaInterfaceRoles.ps1` (FR-08a): nameif + security-level per interface,
      encodes security-level default; uRPF rule = sec-level 0 OR nameif outside.

**Acceptance gate**: each model passes its own unit tests; defaults model passes a
doc-cited audit; classifier 100% on seeded credential lines (nt-encrypted as
not-cleartext).

### Phase 4: v0.1b — MVP checks + output

**Status**: Not Started

- [ ] Check engine (`Invoke-AsaChecks.ps1`) consuming `check-catalog.psd1`
      (DR-04 schema: id, category, severity, profile, authority+verified,
      pass/fail, default_if_absent, confidence, dependency, rationale, remediation).
- [ ] The 15 MVP checks (presence + context-conditional absence), commercial
      profile default, dod profile opt-in.
- [ ] `Write-AsaReport.ps1`: Markdown (stdout) + timestamped CSV, secret masking
      on by default with conservative keyword fallback; status stream separated.
- [ ] Determinism (NFR-06): sorted findings, InvariantCulture, normalized EOL.
- [ ] `Invoke-AsaReview.ps1` entry point: params, exit codes, run summary.

**Acceptance gate (staged guard, check tier)**: exact seeded true positives, zero
false positives on good instances (TSC-02/03); no verbatim secret in masked
output (TSC-12); identical finding set across PS 5.1 and 7+ (TSC-09); offline +
read-only verified (TSC-11).

### Phase 5: v0.2 — Coverage

**Status**: Not Started

- [ ] Remaining CIS/STIG catalog across all seven categories.
- [ ] Deep recursive resolution (FR-05b); undefined-reference + unbound-ACL
      heuristics (FR-13).
- [ ] Version/EoL lookup table (FR-15, `asa-eol.psd1`, DR-05).
- [ ] Second independently authored fixture (TR-05).
- [ ] 20k-line non-blocking performance benchmark (NFR-04).

**Acceptance gate**: expanded catalog TP/FP gates pass; full absence set gated.

### Phase 6: v0.3 — Depth

**Status**: Not Started

- [ ] ACL redundancy/shadowing (FR-14, ASA-ACL-toolkit approach).
- [ ] Performance hardening on large configs.
- [ ] Baseline/suppression file (FR-18).

**Acceptance gate**: shadowing TP/FP on fixture; performance target met.

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-06-24 | Hierarchical parent/child parser + repeated-prefix index, pure PowerShell | Proven model (ciscoconfparse2); flat regex misreads nested ASA blocks; no PS-native equivalent exists (RESEARCH §2, §5) |
| 2026-06-24 | Offline, read-only, no-egress; PS 5.1 floor + 7+ | Sensitive client config; analyst host constraint (R3/R4/R5) |
| 2026-06-24 | Findings map to CIS ASA + DISA ASA STIG; IDs advisory, evidence load-bearing | Enterprise context; some IDs `[unverified]` (R1, OQ-A, SR-05) |
| 2026-06-24 | Markdown + CSV output; secret masking on by default | Cutaway convention + deliverable is credential-bearing (R2, SR-04) |
| 2026-06-24 | v0.1a-core parser isolated before checks (v0.1b) | Parser is load-bearing; defects must surface as parser-test failures (multi-AI pass 1+2) |
| 2026-06-24 | Defaults model + interface-role model are doc-cited data, built in v0.1b prep | External source of truth avoids second oracle-circularity (multi-AI pass 2) |
| 2026-06-24 | TR-07 real configs stored locally, never dev-time fetch | Dev-time fetch contradicts air-gapped posture (multi-AI pass 2) |
| 2026-06-24 | Commercial profile default, DoD/STIG opt-in | Enterprise target; DoD-specific checks are noise on commercial ASA (multi-AI pass 1) |

## Open process items (from multi-AI pass 2, P2)

- [ ] Add ADRs for irreversible decisions: parser model, data/code boundary,
      masking default-on, v0.1a/v0.1b split.
- [ ] Make one document the canonical milestone source of truth (this PLAN);
      have VISION/ARCHITECTURE/SUCCESS_CRITERIA reference it to avoid drift.
- [ ] Add a requirements -> architecture -> test-gate traceability matrix.
- [ ] Mark superseded DISCOVERY_NOTES assumptions (single-stream output ->
      separated streams).
- [ ] Confirm in code review that no CHAPS doc content or stale convention leaked.

## Out of Scope (phase-level; project-level scope in REQUIREMENTS §11, VISION §6)

- Live device interrogation / SSH / hitcount-based rule-usage analysis.
- Dataplane / reachability modeling (Batfish territory).
- Non-ASA-9.x or multi-vendor parsing.
- Remediation / config-change generation.
- Any online, SaaS, or telemetry capability.
