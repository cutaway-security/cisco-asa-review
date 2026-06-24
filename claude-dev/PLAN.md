# PLAN.md — cisco-asa-review

## Project Goal

Deliver an offline, read-only, pure-PowerShell tool that parses a Cisco ASA 9.x
`show running-config` dump and produces a prioritized, evidence-backed security
findings report (Markdown + CSV), mapped to CIS Cisco ASA + DISA Cisco ASA STIG,
with no network and no device access.

## Current Phase

**Phase**: Phase 4 — v0.1b check engine + output
**Status**: Complete (2026-06-24) — gate passed: 73/73 Pester tests green;
end-to-end CLI verified. **v0.1b (MVP) milestone reached.**
**Focus**: v0.1b complete. Next candidates: Windows PowerShell 5.1 verification
(NFR-01), then Phase 5 (v0.2 coverage) — full CIS/STIG catalog, deep resolution,
undefined-ref/unbound-ACL heuristics, version/EoL table, second fixture.

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

**Status**: Complete (2026-06-24)

- [x] `src/Read-AsaConfig.ps1`: bounded, encoding-safe load with SR-07 thresholds
      (10 MB file, 4 KB line) + CRLF/LF normalization.
- [x] `src/ConvertTo-AsaModel.ps1`: indentation tree (indent stack, MaxDepth guard)
      + repeated-prefix family index (access-list, crypto map, name, banner,
      tunnel-group, http/ssh/telnet, twice-NAT) + object/object-group/interface
      symbol tables; line-number + raw text retained per node.
- [x] `name` IP/symbol map; verbose model dump `src/Show-AsaModel.ps1` (OR-04).
- [x] Parser unit tests (TR-03): bounded-reader failure modes, 3-deep nesting,
      repeated-prefix grouping, name map, B6 legacy object-group capture,
      multi-line banner reassembly, object-NAT vs twice-NAT, global vs nested
      webvpn, and a preorder-line-number integrity invariant.

**Acceptance gate (staged guard, parser tier)**: PASSED — 36/36 Pester tests
green; both real sanitized configs parse with zero integrity problems (TR-07);
dump cross-validates expected construct counts.

### Phase 3: v0.1b-prep — Support models

**Status**: Complete (2026-06-24)

- [x] `src/Resolve-AsaReferences.ps1` (FR-05a): name resolution +
      `Resolve-AsaNetworkGroup` / `Test-AsaNetworkGroupIsAny` with one level of
      group-object expansion; "not assessed" (OR-03) beyond depth and on undefined
      references.
- [x] `src/Get-AsaSecrets.ps1` (FR-09/FR-10): `Get-AsaPasswordClass`
      (pbkdf2/encrypted/nt-encrypted/cleartext/redacted) + `Get-AsaSecrets`
      scanner (passwords, SNMP community, AAA key, NTP key, tunnel-group PSK);
      `nt-encrypted` gated as not-cleartext (TSC-05).
- [x] `data/asa-defaults.psd1` (FR-08b, DR-06): the 8 MVP absence/conditional
      defaults, each with a Cisco ASA 9.x doc citation (SSH-version entry notes
      the 9.16 `ssh version` removal).
- [x] `src/Get-AsaInterfaceRoles.ps1` (FR-08a): nameif + security-level per
      interface, encodes the security-level default (inside=100, other=0); uRPF
      rule = security-level 0 OR nameif outside.

**Acceptance gate**: PASSED — 56/56 Pester tests green; classifier 100% on seeded
credentials (nt-encrypted not-cleartext); defaults model doc-cited and covers
exactly the MVP absence/conditional checks; resolution reports not-assessed beyond
one level.

### Phase 4: v0.1b — MVP checks + output

**Status**: Complete (2026-06-24)

- [x] `data/check-catalog.psd1` (DR-04 schema incl. profile, confidence,
      dependency) for the 15 MVP checks; detector types present/absent/code.
- [x] `src/Invoke-AsaChecks.ps1` engine + `src/checks/structural.ps1` (the 4 code
      detectors: console-timeout, snmp-community, ntp-auth, acl-any-any).
- [x] `src/Protect-AsaSecret.ps1` (masking, default-on, keyword fallback) +
      `src/Write-AsaReport.ps1` (Markdown stdout + timestamped MD/CSV next to the
      config, never overwriting it; status stream separated).
- [x] Determinism (NFR-06): severity then ordinal check id then line number.
- [x] `Invoke-AsaReview.ps1` entry point: params, profile, exit codes, run summary.
- [x] `tests/unit/Guard.Tests.ps1`: static no-network / write-boundary guard.

**Acceptance gate (staged guard, check tier)**: PASSED — 73/73 Pester tests
green. Exact 15 seeded true positives, zero false positives (TSC-02/03); no
verbatim secret in masked output (TSC-12, verified in a real run); deterministic
ordering (NFR-06); offline + read-only enforced by the static guard. End-to-end
CLI verified: report + CSV written next to the config, input unmodified.

**Outstanding for a full "shipped" claim**: TSC-09 (run on Windows PowerShell 5.1
and confirm identical finding set; dev host is pwsh 7.6.2) and TSC-11 (runtime
process-monitor egress check). The static guard covers the SR-01/SR-06 boundary in
code in the interim.

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
