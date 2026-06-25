# PLAN.md — cisco-asa-review

## Project Goal

Deliver an offline, read-only, pure-PowerShell tool that parses a Cisco ASA 9.x
`show running-config` dump and produces a prioritized, evidence-backed security
findings report (Markdown + CSV), mapped to CIS Cisco ASA + DISA Cisco ASA STIG,
with no network and no device access.

## Current Phase

**Phase**: Phase 6 — v0.2 coverage + GitHub issue #1
**Status**: **v0.2 infrastructure COMPLETE** (2026-06-24) — issue #1 + catalog
coverage (58 checks) + deep resolution + version/EoL (FR-15) + second fixture
(TR-05) + 20k perf benchmark & quadratic fix (NFR-04). Default suite **124 passed
/ 1 skipped** (opt-in perf). On `claude-dev`, not yet released. Phases 1–5c
released to `main` as v0.1c.
**Focus**: v0.2 done. Next: decide release of accumulated v0.2 work to main
(v0.1d); Windows PowerShell 5.1 verification (NFR-01).

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

### Phase 5: Segmentation & data-flow visualization

**Status**: Complete (2026-06-24). Package B (Mermaid topology + zone matrix),
separate output file, always produced. Research:
`20260624_segmentation-visualization_RESEARCH.md`.

- [x] `src/Get-AsaZoneModel.ps1` (FR-20/21/22): zones from interface-roles; ACE
      src/dst → zone via longest-prefix vs interface subnets (`any`/0.0.0.0/0 =
      all; unmapped = `external`; OR-03 not-assessed carried); inter-zone
      allowed-flow edges from access-group-bound permit ACEs.
- [x] `src/Write-AsaSegmentation.ps1` (FR-23/24/25/26): zone-level Mermaid topology
      (tiers, untrusted styling, red risk linkStyle) + zone-to-zone matrix +
      risk-flow list; ANY/ANY (literal AND object-group-expressed) highlighted and
      attributed to the offending ACL line; masking applied; boundary stated.
- [x] Wired into `Invoke-AsaReview.ps1`: separate timestamped file next to the
      config, produced on every run.
- [x] `tests/unit/Segmentation.Tests.ps1` (14 tests) + Guard write-boundary
      extended to the new writer.

**Acceptance gate**: PASSED — 89/89 tests green. Zones/edges derive correctly;
ANY/ANY highlighted on insecure (outside→inside red edge + matrix cell), absent on
hardened; Mermaid + matrix well-formed and deterministic; no online renderer (static
guard covers it); no secret leak (TSC-12 extended). End-to-end verified.

**Lessons (fixed during build)**: (1) `$bool -eq 'string'` coerces the string to
[bool] — hid an object-group-expressed any/any; fixed with a type test. (2)
Aggregated any/any edges initially cited the first line, not the any/any line;
fixed to select the any/any contributing line. Both now covered by tests.

#### Phase 5b: Consolidated HTML deliverable (Complete 2026-06-24)

Client has no Mermaid renderer, so Mermaid does not render for them. Added a
single self-contained HTML report.

- [x] `src/Write-AsaHtmlReport.ps1`: findings + inline-SVG topology + colored
      matrix in one HTML; embedded CSS, no JavaScript, no external references;
      masking applied; deterministic.
- [x] Wired into `Invoke-AsaReview.ps1` (always produced). Guard write-boundary
      extended.
- [x] `tests/unit/HtmlReport.Tests.ps1` (9 tests). Suite 98/98 green.
- [x] Rendering verified visually: rendered the HTML to an image (wkhtmltoimage/
      WebKit) and confirmed the SVG topology + matrix display realistically; PDF
      path confirmed (wkhtmltopdf). PDF for the analyst/client = browser Print ->
      Save as PDF.

**Acceptance gate**: PASSED — HTML is self-contained (no JS, no external refs),
SVG well-formed and visually verified to render, findings + matrix + topology
consolidated, ANY/ANY highlighted, no secret leak, deterministic.

#### Phase 5c: any-to-all-zones collapse (Complete 2026-06-24)

- [x] `Get-AsaZoneModel.ps1` computes `CollapsedSources` (sources whose any-any
      reaches every other zone, >=2 dests).
- [x] HTML SVG + Mermaid topology collapse those into a single "ANY/ANY to ALL
      ZONES" node badge by default; `-ExpandAnyAny` draws every flow. Matrix +
      risk list stay exhaustive. Threaded through `Invoke-AsaReview.ps1`.
- [x] Tests added (collapse default + expand differential). Suite 103/103 green.
      Default (collapsed) render visually verified — de-cluttered.
- [x] Robustness: entry point now creates a missing `-OutputDirectory`.

### Phase 6: v0.2 — Coverage + GitHub issue #1 (worked together)

**Status**: Not Started (planned 2026-06-24)

v0.2 coverage:
- [x] Remaining CIS/STIG catalog across all seven categories. **Commercial
      coverage complete (2026-06-24): 56 checks across 7 slices.**
      - Slice 1 (data-driven, 8): MGMT-SSH-OUTSIDE, AUTH-AAA-SERIAL, LOG-TIMESTAMP,
        LOG-TRAP, LOG-CONSOLE, AUTH-PW-LOCKOUT, IF-URPF, SNMP-V3-WEAK.
      - Slice 2 (numeric/conditional code, 4): MGMT-SSH-TIMEOUT, MGMT-HTTP-TIMEOUT,
        CRYPTO-PFS, CRYPTO-SA-LIFETIME.
      - Slice 3 (AAA depth, 8): AUTH-ENABLE-PW, AUTH-AAA-ENABLE, AUTH-AAA-HTTP,
        AUTH-CMD-AUTHZ, AUTH-CMD-ACCT, AUTH-PW-COMPLEXITY, AUTH-PW-LIFETIME,
        AUTH-BANNER-MOTD.
      - Slice 4 (crypto strength, 5): CRYPTO-IKE-INTEGRITY, CRYPTO-IPSEC-INTEGRITY,
        CRYPTO-DH-14, CRYPTO-AES128, CRYPTO-SSL-CIPHER.
      - Slice 5 (logging/monitoring, 4): LOG-BUFFER-SIZE, NTP-REDUNDANT,
        THREAT-DETECTION-BASIC, SNMP-V3-NOPRIV.
      - Slice 6 (access control, 3): ACL-IMPLICIT-DENY-LOG, ICMP-TO-DEVICE,
        SYSOPT-PERMIT-VPN.
      - Slice 7 (interface hardening, 4): IF-SCANNING-THREAT, IF-THREAT-STATS,
        IF-SAME-SECURITY, DNS-LOOKUP.
      Catalog now **56 checks** (15 MVP + 36 v0.2 + 5 hygiene). `Coverage.Tests.ps1`
      gates TP (insecure/coverage) + TN (hardened). Commercial catalog coverage
      complete. (DoD-profile checks — FIPS, exact DoD banner, split-tunnel,
      RSA modulus, etc. — remain an optional follow-on under the dod profile.)
- [x] Deep recursive resolution (FR-05b) — done (2026-06-24): `Resolve-AsaNetworkGroup`
      now fully recurses nested `group-object` with cycle detection (MaxGroupDepth 16);
      "not-assessed" reserved for cycles/undefined/backstop. Added REF-UNDEFINED check
      (dangling object/object-group references). Catalog now 57 checks.
- [x] Version/EoL lookup table (FR-15, `asa-eol.psd1`, DR-05) — done (2026-06-24):
      bundled offline reference (snapshot 2026-06-24), `Test-AsaVersionEol` +
      VERSION-EOL check (EoL->finding, supported->none, unlisted->not-assessed).
      The internet check is a SEPARATE opt-in tool, `Update-AsaEolData.ps1` (the
      only network script, outside the review path) — fetch-or-keep-reference; a
      Guard test asserts the review never invokes it. Catalog now 58 checks.
- [x] Second independently authored fixture (TR-05) — done (2026-06-24):
      `Robustness.Tests.ps1` runs the full pipeline on the two independent real
      sanitized configs and asserts well-formed findings (anti-overfit guard).
- [x] 20k-line non-blocking performance benchmark (NFR-04) — done (2026-06-24):
      `tests/perf/` generator + `Measure-AsaPerf.ps1` (parse + full pipeline at
      2.5k-20k; growth exponent + doubling-factor verdict). It surfaced a real
      quadratic in `Get-AsaReferenceIndex` (O(entities x lines)) — fixed with an
      inverted token index: 20k pipeline 24.5s -> 5.1s, doubling 4.28x -> 1.85x,
      parser linear (251ms / exponent 0.54). Opt-in `Performance.Tests.ps1`
      regression guard (env `ASA_RUN_PERF`). **v0.2 infrastructure complete.**

GitHub issue #1 (hygiene + tracking + output changes) -- **COMPLETE (2026-06-24)**:
- [x] `src/Get-AsaReferenceIndex.ps1` (FR-31): ACL/object/object-group ->
      referenced-anywhere (token scan, conservative). Crypto-only ACL not flagged.
- [x] Hygiene checks (Informational): unused ACL (FR-32), unused object/
      object-group (FR-33), inactive rules incl. expired time-range (FR-34),
      interface no-ip -> shutdown (FR-35, skips bridge-group members), BVI without
      bridge-group (FR-36). One finding per entity (engine now emits per detection).
- [x] **Informational** severity tier (SeverityRank=3; excluded from risk counts).
- [x] CSV (DR-02a): Informational rows + `RemediationState` (default Open) +
      `RemediationNotes` columns.
- [x] HTML (FR-37): full findings detail with ALL evidence lines after the
      summary/visuals; Informational styled; the HTML is the complete report.
- [x] Removed the segmentation Markdown output and `Write-AsaSegmentation.ps1`
      (FR-38); segmentation lives only in the HTML.
- [x] Added `tests/fixtures/asa-5515-hygiene.txt` (crypto-only ACL, unused ACL,
      used/unused object+group, inactive + expired-/active-time-range ACEs, no-ip
      / shutdown / bridge-member / IP-bearing interfaces, BVI with/without member)
      + `tests/unit/Hygiene.Tests.ps1`.

**Acceptance gate**: PASSED for issue #1 — 108/108 tests green; the five hygiene
checks hit exact seeded TP / zero FP (crypto-only ACL NOT flagged, TSC-15); CSV
has the new columns + Informational rows (TSC-16); HTML carries the full findings
detail and no segmentation `.md` is produced (TSC-17); HTML rendering re-verified.

**Phase 6 / v0.2 COMPLETE.** Issue #1, catalog coverage (58 checks), deep
resolution, version/EoL (FR-15), the second-fixture anti-overfit guard (TR-05),
and the 20k-line perf benchmark + quadratic fix (NFR-04) are all done.

### Phase 7: v0.3 — Depth

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
| 2026-06-24 | Add segmentation+data-flow visualization (Phase 5): Mermaid topology + zone matrix, separate always-on output | Conversation needs a topology, report needs a matrix; offline text emission, zero-install render; Nipper/CDO visualize nothing (research 20260624_segmentation-visualization) |
| 2026-06-24 | Visualization shows configured/allowed flows, NOT reachability | Avoid overclaiming; reachability modeling stays OOS-02 (routing/NAT/shadowing not modeled) |
| 2026-06-24 | GitHub issue #1 features folded into Phase 6 (worked with v0.2 coverage) | Maintainer direction; hygiene checks + deep resolution sequence together |
| 2026-06-24 | Add Informational severity tier for hygiene/cleanup findings | Track unused/inactive/tidiness items in CSV without inflating risk counts |
| 2026-06-24 | "Unused" = unreferenced at ANY site (reference index), not just access-group | Crypto map / NAT / nested-group references would otherwise cause false positives |
| 2026-06-24 | Artifact roles: HTML = full deliverable, MD = consolidation/AI review, CSV = tracking | CSV gains RemediationState + RemediationNotes + Informational rows; segmentation .md removed |

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
