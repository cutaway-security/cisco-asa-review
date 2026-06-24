# cisco-asa-review Architecture and Project Assessment

- Author: mistral (mistral-medium-latest)
- Date: 2026-06-24 10:12
- Scope: claude-dev/ARCHITECTURE.md, background/goal.md, claude-dev/20260624_asa-config-analysis_RESEARCH.md, claude-dev/CHECK_CATALOG.md, claude-dev/DISCOVERY_NOTES.md, claude-dev/REQUIREMENTS.md, claude-dev/SUCCESS_CRITERIA.md, claude-dev/VISION.md
- Repository state: documentation-only, no code

---

## Executive Summary

The core idea is sound and worth building. The project addresses a real gap (no PowerShell-native, offline ASA config analyzer) with a proven approach (hierarchical parser + declarative checks). The first milestone (v0.1a) is correctly scoped to derisk the load-bearing parser before checks are built. The dominant risk is the parser's correctness: if it fails to model ASA's indentation/reference structure accurately, all downstream checks will produce false positives/negatives. The plan derisks this by isolating the parser (v0.1a) and gating its release on 100% unit test coverage plus clean parsing of two real sanitized configs (TR-07). The main issues to address are: (1) the absence of a concrete defaults model (critical for absence-based checks), (2) the need to explicitly define the boundary between declarative catalog data and structural engine code, and (3) the feasibility of the "context-conditional" absence checks without over-building the defaults model.

---

## What Validates Well

- **Core thesis**: The hierarchical parser + resolution layer is the right approach. This is validated by prior art (ciscoconfparse2, ASA-ACL-toolkit) and the project's own research (RESEARCH §5, CHECK_CATALOG B2). The decision to avoid flat regex is correct.
- **Scope discipline**: The v0.1a/v0.1b split explicitly derisks the parser before checks. This is the highest-value sequencing decision in the plan.
- **Security posture**: The offline/read-only/no-egress constraints (SR-01/02/03) are non-negotiable and correctly enforced by design. Default-on secret masking (SR-04) is the right call.
- **Threat model**: The trust boundary is clear (only the config file is untrusted input), and the mitigations (bounded input, no dynamic execution) are appropriate.
- **Efficacy focus**: The MVP-15 checks (CHECK_CATALOG A8) are high-signal and cover the most common ASA findings. The absence-based checks (FR-08) are correctly prioritized.
- **Determinism**: The requirement for sorted findings, InvariantCulture, and normalized line endings (NFR-06) is a strong hardening measure that makes repeatability (BSC-03) achievable.

---

## Scope and Sequencing

The proposed phased milestones are well-structured, but the following refinements are needed:

### Recommended Phased Tiers

| Milestone | Scope | Gate | Risk Mitigation |
|-----------|-------|------|------------------|
| **v0.1a** | Reader + parser (indentation tree + repeated-prefix index) + minimal resolution (`name` map, basic object expansion) + password hash classification + defaults model (scoped to MVP-15 absence checks) | 100% parser unit tests (TR-03) + clean parse of 2 real sanitized configs (TR-07) | Proves the load-bearing component in isolation. The defaults model MUST be included here, as absence checks in v0.1b depend on it. |
| **v0.1b** | MVP-15 checks (presence + context-conditional absence) + Markdown/CSV output + default secret masking + run summary | Exact seeded TP / zero FP on fixture + real configs | Checks are built on a proven parser. |
| **v0.2** | Full CIS/STIG catalog + deep object resolution + undefined-ref/unbound-ACL heuristics + second independent fixture | 100% TP/0 FP on expanded catalog | Expands coverage without changing the core. |
| **v0.3** | ACL shadowing/redundancy + version/EoL lookup + baseline/suppression + performance hardening | Performance gates (NFR-03/04) + large-config validation | Depth features that require the parser to be stable. |

### What to Cut from First Delivery
- **Defer the version/EoL lookup (FR-15) to v0.2**. The `ASA Version` header is often missing from `show running-config`, and the lookup table (DR-05) is not load-bearing for the MVP. This reduces scope and avoids over-building.
- **Defer the second independent fixture (TR-05) to v0.2**. One well-constructed fixture is sufficient for v0.1a/b, as the parser gate (TR-07) already requires real configs.
- **Defer the verbose mode (OR-04) to v0.2**. It is useful for debugging but not critical for the MVP.

### Critical Path
The parser (v0.1a) is the critical path. The following must be true before v0.1b:
1. The indentation tree + repeated-prefix index correctly models all constructs in CHECK_CATALOG B.
2. The `name` map and minimal object resolution work for the MVP-15 checks.
3. The defaults model is documented and scoped to the MVP-15 absence checks (OQ-1).
4. Password hash classification (CHECK_CATALOG B3) is 100% accurate on the fixture.

---
---
## Critical Path and Leverage

The parser is the single load-bearing component. If it fails, all checks fail. The plan correctly derisks it first (v0.1a), but the following leverage points must be addressed:

1. **Parser correctness**: The indentation stack + repeated-prefix index must handle all constructs in CHECK_CATALOG B, including the lower-confidence branches (B6: `object-group service`, `nt-encrypted`). The gate (TR-07) requires clean parsing of two real sanitized configs, which is the right leverage point.
2. **Defaults model**: Absence-based checks (FR-08) cannot work without a documented ASA 9.x defaults model. This must be built in v0.1a, not v0.1b, as it is a dependency for the MVP-15 checks. The model should be scoped to the MVP-15 checks first (OQ-1), then expanded.
3. **Resolution layer**: Minimal object resolution (FR-05a) must be proven to work for the MVP-15 checks. The dependency is explicit (each check declares whether it reads resolved or raw text), which is good.
4. **Test fixtures**: The synthesized fixture (TR-01/02) must cover all MVP-15 checks with known-good and known-bad instances. The real configs (TR-07) must parse cleanly. Without these, the gates (TSC-02/03) cannot be met.

---
---
## Critical Contradictions and Feasibility Problems

### CRITICAL
1. **Defaults model is undefined but required for v0.1b**
   - **Sources**: ARCHITECTURE §5 (defaults model is "documented ASA 9.x defaults model"), REQUIREMENTS FR-08 (absence checks are context-conditional), SUCCESS_CRITERIA TSC-04 (absence checks must pass).
   - **Conflict**: The defaults model is not defined in any document, but absence checks (e.g., `logging enable`, `ssh version 2`) are in the MVP-15 and cannot work without it.
   - **Feasibility**: Cannot work as written. The defaults model must be explicitly documented in v0.1a, scoped to the MVP-15 checks.
   - **Resolution**: Add a `data/asa-defaults.psd1` file in v0.1a that encodes the defaults for the MVP-15 absence checks. This is a P0 fix.

2. **Context-conditional absence checks are underspecified**
   - **Sources**: ARCHITECTURE §5 (context-conditional rule for uRPF), CHECK_CATALOG A1/A3/A6 (absence checks like `logging enable`, `ip verify reverse-path`).
   - **Conflict**: The "context-conditional" rule (FR-08) is described but not formalized. For example, uRPF absence is a finding on the outside interface but not on a management interface. How is "outside" determined? By `nameif` value? Security level? This is not defined.
   - **Feasibility**: The current specification is too vague to implement. Without a clear rule, the check will either over-flag (false positives) or under-flag (false negatives).
   - **Resolution**: Define the context rules explicitly in the defaults model or a separate context-rules document. For uRPF, the rule could be: "uRPF absence is a finding if the interface has `security-level 0` or `nameif outside`." This must be a P0 fix.

3. **Parser must handle repeated-prefix families AND indentation tree in one pass**
   - **Sources**: ARCHITECTURE §2 (two indices in one pass), CHECK_CATALOG B2 (repeated-prefix families: `access-list`, `crypto map`, `name`, `nat`, `banner`).
   - **Conflict**: The parser must build both the indentation tree and the repeated-prefix index simultaneously. The design claims this is possible, but the feasibility depends on the implementation. If the parser processes lines sequentially, it can track both structures, but edge cases (e.g., a repeated-prefix line that is also indented) could break the model.
   - **Feasibility**: The design is feasible, but the implementation must be careful. The gate (TR-07) will catch issues, but the risk is high if the parser is not tested thoroughly.
   - **Resolution**: Ensure the parser unit tests (TR-03) explicitly cover edge cases where repeated-prefix lines might appear indented or in unexpected contexts. This is a P0 test requirement.

### HIGH
4. **Authority ID drift (OQ-A) vs. evidence-based findings (SR-05)**
   - **Sources**: RESEARCH OQ-A (some CIS/STIG IDs are `[unverified]`), REQUIREMENTS SR-05 (findings must be defensible by config evidence alone).
   - **Conflict**: The CHECK_CATALOG includes `[unverified]` authority IDs, but SR-05 requires that findings stand on evidence, not IDs. This is not a contradiction, but it means the catalog must treat IDs as advisory metadata, not load-bearing.
   - **Feasibility**: The design accounts for this (CHECK_CATALOG header notes IDs are advisory), but the implementation must ensure no finding is gated on an `[unverified]` ID.
   - **Resolution**: Add a validation step in the check engine to ensure every finding includes config evidence, regardless of authority ID. This is a P1 requirement.

5. **Password hash classification for `nt-encrypted` (CHECK_CATALOG B3/B6)**
   - **Sources**: CHECK_CATALOG B3 (`nt-encrypted` = NT hash, `[lower confidence]`), SUCCESS_CRITERIA TSC-05 (100% correct classification, but for `nt-encrypted`, the gate is "classified as not-cleartext").
   - **Conflict**: The `nt-encrypted` branch is marked as lower confidence, but TSC-05 requires 100% correctness. The resolution is to relax the gate for `nt-encrypted` to "not cleartext," but this is not explicitly called out in the parser design.
   - **Feasibility**: The gate is achievable if the classifier treats `nt-encrypted` as a non-cleartext subtype, even if the exact hash type is uncertain.
   - **Resolution**: Document this explicitly in the parser's classification logic and tests. This is a P1 fix.

6. **Real config sourcing (TR-07) vs. licensing (OQ-3)**
   - **Sources**: SUCCESS_CRITERIA TR-07 (parser must cleanly parse two real sanitized configs), RESEARCH OQ-3 (real configs may have licensing issues for redistribution).
   - **Conflict**: TR-07 requires real configs, but OQ-3 notes that committing them may not be possible due to licensing.
   - **Feasibility**: The gate is still achievable if the configs are sourced at runtime (e.g., downloaded during testing) rather than committed to the repo. However, this introduces a dependency on external URLs, which violates SR-01 (no network).
   - **Resolution**: The real configs must be manually obtained and stored locally for testing, not committed to the repo. This is a P1 process requirement.

### MEDIUM
7. **Declarative vs. structural check boundary (DR-04, AR-04)**
   - **Sources**: REQUIREMENTS DR-04 (catalog schema for declarative checks), ARCHITECTURE §4 (boundary drawn now: presence/absence/pattern checks are data; structural checks are code).
   - **Conflict**: The boundary is described but not enforced. There is a risk that structural checks (e.g., undefined references) could drift into the catalog data, violating MR-01 (adding a simple check should not require engine changes).
   - **Feasibility**: The design is sound, but the implementation must enforce the boundary. For example, the catalog schema should not allow fields that imply structural logic (e.g., "resolve_objects: true").
   - **Resolution**: Add a schema validation step to reject catalog entries that require structural logic. This is a P2 requirement.

8. **Determinism across PowerShell 5.1 and 7+ (NFR-06, TSC-09)**
   - **Sources**: REQUIREMENTS NFR-06 (deterministic output), SUCCESS_CRITERIA TSC-09 (identical finding set across runtimes).
   - **Conflict**: PowerShell 5.1 and 7+ have different default culture settings and hash table iteration orders. The design mitigates this with `InvariantCulture` and sorted findings, but edge cases (e.g., string comparison in regex) could still cause differences.
   - **Feasibility**: The design is mostly sound, but the implementation must be careful to use `InvariantCulture` everywhere and avoid hash table iteration for output.
   - **Resolution**: Add explicit tests for cross-runtime determinism. This is a P2 requirement.

---
---
## Security Findings

### Trust Boundaries
- **Untrusted input**: The ASA config file (IR-01). All other inputs (check catalog, defaults model) are trusted.
- **Trust boundary**: The tool processes the config as inert text (SR-06). No dynamic execution (`Invoke-Expression`) is allowed.
- **Output**: The Markdown/CSV reports are written only to user-specified directories (SR-02/03). Secret masking is on by default (SR-04).

### Threat Model
1. **Malicious config file**:
   - **Attack**: A hostile config file could attempt to exploit the parser (e.g., via regex catastrophic backtracking, excessive nesting, or huge line lengths).
   - **Mitigations**: SR-07 (bounded input, compiled regex) addresses this. The parser must enforce:
     - Maximum file size (e.g., 10MB).
     - Maximum line length (e.g., 4KB).
     - Maximum nesting depth (e.g., 10 levels).
     - Bounded reads (streaming, not loading entire file into memory at once).
   - **Gap**: The exact bounds are not specified in the docs. This must be added to the reader module's requirements.

2. **Credential leakage via output**:
   - **Attack**: The tool's output (Markdown/CSV) could leak secrets if masking is disabled or bypassed.
   - **Mitigations**: SR-04 (default-on masking) and the `-RevealSecrets` opt-in flag address this. The masking must:
     - Replace secret values, not the entire line (so evidence remains legible).
     - Cover all secret types: passwords, SNMP communities, AAA keys, NTP keys, PSKs (CHECK_CATALOG B3).
   - **Gap**: The masking logic is not specified in detail. The implementation must ensure it cannot be bypassed (e.g., by malformed config lines).

3. **Side-channel leakage**:
   - **Attack**: The tool could leak config data via error messages, logs, or temporary files.
   - **Mitigations**: SR-03 (no external transmission/logging) addresses this. The tool must:
     - Avoid writing config data to stderr or logs.
     - Use in-memory processing where possible.
   - **Gap**: The error handling (FR-17) must not include config snippets in error messages.

### Security Requirements Validation
- **SR-01 (no network)**: Enforced by design (no network calls in the architecture).
- **SR-02 (read-only)**: Enforced by design (only reads input, writes to user-specified output).
- **SR-03 (no external transmission)**: Enforced by design, but the implementation must avoid logging config data to system logs or temp files.
- **SR-04 (secret masking)**: Default-on masking is correct, but the implementation must be robust.
- **SR-05 (evidence-based findings)**: Correctly prioritized.
- **SR-06 (no dynamic execution)**: Correctly enforced by design.
- **SR-07 (bounded input)**: Correctly identified, but the exact bounds must be specified.

---
---
## Efficacy

### Will the Approach Detect/Prevent What It Claims?
1. **Hierarchical parser**:
   - **Claim**: Enables detection of nested context, cross-references, and absences.
   - **Efficacy**: High. The prior art (ciscoconfparse2) validates this approach. The parser must correctly model the indentation tree and repeated-prefix families to avoid false positives/negatives.
   - **Risk**: If the parser misassigns parent/child relationships (e.g., for `group-policy attributes` → `webvpn` → `anyconnect`), structural checks (e.g., undefined references) will fail.

2. **Absence-based checks**:
   - **Claim**: Detects missing lines (e.g., `logging enable`, `ssh version 2`).
   - **Efficacy**: High, but dependent on the defaults model. Without a correct defaults model, absence checks will over- or under-flag.
   - **Risk**: The defaults model is not yet defined (CRITICAL contradiction #1). This must be addressed before v0.1b.

3. **Context-conditional checks**:
   - **Claim**: Avoids over-flagging by scoping checks to relevant contexts (e.g., uRPF on outside interfaces).
   - **Efficacy**: Medium. The concept is sound, but the context rules are underspecified (CRITICAL contradiction #2). Without explicit rules, the checks may not work as intended.

4. **Secret classification**:
   - **Claim**: Correctly classifies password hashes and flags cleartext/weak secrets.
   - **Efficacy**: High for well-defined types (`pbkdf2`, `encrypted`). Medium for `nt-encrypted` (lower confidence). The gate (TSC-05) is relaxed for `nt-encrypted`, which is acceptable.

5. **MVP-15 checks**:
   - **Claim**: Covers the highest-signal ASA findings.
   - **Efficacy**: High. The checks are well-chosen (RESEARCH §4), but their correctness depends on the parser and defaults model.

### Recommendations for Improved Efficacy
1. **Formalize the defaults model**: Define a `data/asa-defaults.psd1` file that encodes:
   - Which settings are off/permissive by default (e.g., `logging enable` = off, `ssh version` = v1 negotiable).
   - Context rules (e.g., uRPF absence is a finding only on interfaces with `security-level 0` or `nameif outside`).
2. **Explicit context rules**: Document the context-conditional logic for each absence check in the defaults model or a separate file.
3. **Parser validation**: Ensure the parser unit tests (TR-03) cover all edge cases in CHECK_CATALOG B5 (gotchas) and B6 (lower-confidence branches).

---
---
## Performance and Cost

### Performance Levers
- **Parser**: The indentation stack + repeated-prefix index is O(n) for a well-formed config. The risk is in regex performance (catastrophic backtracking) or excessive object creation.
  - **Mitigation**: Use compiled regex with simple anchors (CHECK_CATALOG B4). Avoid `+=` for array growth (NFR-07).
- **Resolution layer**: Minimal resolution (v0.1a) is O(n) for symbol table building. Deep resolution (v0.2) could be O(n^2) for nested `group-object` expansion.
  - **Mitigation**: Defer deep resolution to v0.2 and ensure it is bounded (e.g., max recursion depth).
- **Check engine**: Each check should be O(n) or better. Avoid nested loops over the parsed model.
  - **Mitigation**: Use the repeated-prefix index for ACL/access-group lookups to avoid O(n^2) scans.

### Cost
- **Development cost**: Concentrated in the parser (v0.1a) and the fixture (TR-01/02). The check catalog (v0.1b+) is lower cost due to the declarative design.
- **Runtime cost**: Negligible (offline, local). The only cost is CPU/memory for parsing and checking, which is bounded by NFR-03/04.

---
---
## Acceptance Criteria and Gates

### Strengths
- The gates are well-defined and measurable (TSC-01 to TSC-11).
- The parser gate (TR-07) is particularly strong: it requires clean parsing of real configs, not just the fixture.
- The check gate (TSC-02/03) requires exact TP/0 FP, which is the right standard.

### Weaknesses
1. **Defaults model gate**: There is no explicit gate for the defaults model. TSC-04 (absence checks) depends on it, but the model itself is not validated.
   - **Fix**: Add a gate for the defaults model: "The defaults model must be documented and pass a manual audit against ASA 9.x documentation for the MVP-15 absence checks."
2. **Context-conditional gate**: There is no gate for the context-conditional rules.
   - **Fix**: Add a gate: "The context-conditional rules must be explicitly documented and pass a manual audit for correctness."
3. **Cross-runtime determinism gate**: TSC-09 is softened to "identical finding set," but the implementation target is byte-identity (NFR-06). This is a good balance, but the gate should explicitly require byte-identical output for the same input across runtimes, modulo timestamp.
   - **Fix**: Clarify TSC-09 to require byte-identical output (excluding timestamp) across PowerShell 5.1 and 7+.

### Staged Gates
The staged gates (v0.1a parser gate, v0.1b check gate) are the right approach. The following additions are recommended:
- **v0.1a gate**: Add the defaults model documentation and context-conditional rules as part of the parser gate.
- **v0.1b gate**: Require that the tool passes the cross-runtime determinism test (TSC-09).

---
---
## Design Risks That Need Better Framing

1. **Fixture-as-oracle circularity (OQ-D)**:
   - **Risk**: The tool is validated against a synthesized fixture, which may not perfectly match real ASA configs. The real config gate (TR-07) mitigates this, but the risk remains that the fixture is not representative.
   - **Framing**: The fixture must be explicitly documented as "syntactically faithful" but not "semantically exhaustive." The real config gate (TR-07) is the primary validation for real-world correctness.

2. **Over-reliance on regex for parsing**:
   - **Risk**: The parser uses regex to identify constructs (CHECK_CATALOG B4). If the regex is incorrect or incomplete, the parser will misclassify lines.
   - **Framing**: The regex anchors must be validated against the ASA 9.x documentation and real configs. The parser unit tests (TR-03) must cover all regex patterns.

3. **Declarative catalog drift**:
   - **Risk**: The boundary between declarative checks and structural code could drift, leading to a maintenance burden.
   - **Framing**: The catalog schema (DR-04) must enforce the boundary. For example, structural checks should not be expressible in the catalog data.

---
---
## Recommendations by Priority

### P0 (Fix Before Coding)
1. **Define the defaults model (CRITICAL #1)**:
   - Create `data/asa-defaults.psd1` with ASA 9.x defaults for the MVP-15 absence checks.
   - Include context rules (e.g., uRPF absence is a finding only on `security-level 0` or `nameif outside` interfaces).
   - Gate: Manual audit against ASA 9.x documentation.

2. **Formalize context-conditional rules (CRITICAL #2)**:
   - Document the context rules for each absence check in the defaults model or a separate file.
   - Example: `uRPF absence is a finding if (interface.security-level == 0 OR interface.nameif == "outside")`.
   - Gate: Manual audit for correctness.

3. **Add parser edge-case tests (CRITICAL #3)**:
   - Ensure TR-03 explicitly covers:
     - Repeated-prefix lines that are also indented (if possible).
     - All lower-confidence branches (CHECK_CATALOG B6).
     - Multi-line banners, two NAT shapes, two webvpn contexts.

### P1 (Fix Before v0.1a)
4. **Resolve real config sourcing (HIGH #6)**:
   - Obtain two real sanitized ASA configs for TR-07 testing. Store them locally (not in the repo) to avoid licensing issues.
   - Gate: Parser cleanly parses both configs with no unparsed or misassigned lines.

5. **Validate authority ID usage (HIGH #4)**:
   - Add a validation step in the check engine to ensure every finding includes config evidence, regardless of authority ID.
   - Gate: Manual audit confirms no finding depends solely on an `[unverified]` ID.

6. **Document `nt-encrypted` classification (HIGH #5)**:
   - Explicitly document that `nt-encrypted` is classified as non-cleartext, even if the exact hash type is uncertain.
   - Gate: TSC-05 passes for `nt-encrypted` (classified as not-cleartext).

### P2 (Fix Before v0.1b)
7. **Enforce declarative/structural boundary (MEDIUM #7)**:
   - Add schema validation to reject catalog entries that require structural logic.
   - Gate: All catalog checks are either purely declarative or explicitly marked as structural.

8. **Add cross-runtime determinism tests (MEDIUM #8)**:
   - Add tests to ensure byte-identical output (excluding timestamp) across PowerShell 5.1 and 7+.
   - Gate: TSC-09 passes.

9. **Specify input bounds (MEDIUM)**:
   - Define exact bounds for SR-07 (max file size, line length, nesting depth).
   - Gate: Parser handles hostile inputs gracefully.

---
---
## Documentation and Process Improvements

1. **Single source of truth for defaults model**:
   - Create `data/asa-defaults.psd1` as the authoritative source for ASA 9.x defaults and context rules.
   - Reference this file in ARCHITECTURE §5 and REQUIREMENTS FR-08.

2. **Consistency matrix for context-conditional rules**:
   - Add a table in `ARCHITECTURE.md` or `REQUIREMENTS.md` that maps each absence check to its context rule (e.g., "uRPF absence: `security-level 0 OR nameif outside`").

3. **ADR for parser design**:
   - Document the decision to use an indentation stack + repeated-prefix index in an Architecture Decision Record (ADR). Include:
     - Why this approach was chosen (prior art, correctness).
     - Alternatives considered (flat regex, ciscoconfparse2 port).
     - Risks and mitigations (edge cases, performance).

4. **Naming consistency**:
   - Standardize the naming of check profiles. Use `commercial` and `dod` consistently (not `DoD/STIG` in some places and `dod` in others).
   - Example: `REQUIREMENTS.md` uses `commercial`/`dod`, while `VISION.md` uses `DoD/STIG`. Align on `commercial`/`dod`.

---
---
## Bottom Line

The core idea is worth building, and the first milestone (v0.1a) is the right shape. However, the project cannot proceed to coding without resolving the **defaults model** and **context-conditional rules**, as these are critical dependencies for the MVP-15 checks. The parser design is sound, but its correctness must be rigorously tested against edge cases and real configs. If the current material is used unchanged, the absence-based checks will fail due to the missing defaults model, and the context-conditional checks will be underspecified, leading to false positives/negatives. The consequence of starting from the current state is a high risk of rework when these gaps are discovered during implementation. Fix the P0 issues first, then proceed.