# cisco-asa-review Architecture and Project Assessment

- Author: mistral (mistral-medium-latest)
- Date: 2026-06-24 09:58
- Scope: claude-dev/ARCHITECTURE.md, background/goal.md, claude-dev/20260624_asa-config-analysis_RESEARCH.md, claude-dev/CHECK_CATALOG.md, claude-dev/DISCOVERY_NOTES.md, claude-dev/REQUIREMENTS.md, claude-dev/SUCCESS_CRITERIA.md, claude-dev/VISION.md
- Repository state: documentation-only, no code

---

## Executive Summary

The core idea is sound: a pure-PowerShell, offline, read-only ASA config analyzer that builds a hierarchical parser to enable structural checks (including absence-based findings) is a defensible and valuable niche. The architecture correctly identifies the parser as the single load-bearing component and sequences v0.1a to derisk it in isolation before checks are built on it. The first milestone (v0.1a) is the right shape: parser + minimal resolution + defaults model + password classification, gated by 100% parser tests and clean parsing of two real configs. The primary risks are: (1) the parser's correctness on real ASA syntax (especially the repeated-prefix flat families vs indented blocks), (2) the accuracy of the ASA defaults model for absence checks, and (3) the feasibility of the "minimal resolution" boundary for MVP checks. If unaddressed, parser defects will corrupt all downstream findings, and an incorrect defaults model will produce systematic false positives/negatives on absence checks.

---

## What Validates Well

- **Concept and thesis**: The project addresses a real gap (no PowerShell-native ASA config analyzer) with a proven approach (hierarchical parser + declarative checks). The offline, read-only, no-network posture is correctly locked in from the start.
- **Critical path identification**: The architecture explicitly recognizes the parser as the single load-bearing component and sequences v0.1a to prove it before checks are added. This is the highest-leverage decision in the design.
- **Scope discipline**: The v0.1a/v0.1b split is well-judged. v0.1a focuses on the parser and its immediate dependencies (minimal resolution, defaults model), while v0.1b adds checks and output. The MVP-15 check list is a pragmatic, high-signal subset.
- **Security posture**: The trust boundary is clear (only the config file is untrusted), and the offline/read-only/no-egress constraints are consistently enforced. Default-on secret masking is the correct choice.
- **Efficacy framing**: The design explicitly handles absence-based checks (a major source of ASA findings) and context-conditional absence (e.g., uRPF only on outside interfaces). This is a key differentiator from naive grep-based approaches.
- **Test strategy**: The success criteria and test plan are explicit about the need for real-config validation (TR-07) and fixture-based true-positive/false-positive gates. The staged parser gate (v0.1a) and check gate (v0.1b) are well-structured.

---

## Scope and Sequencing

The current milestone plan is sound, but the following refinements are recommended:

### Proposed Phased Milestones

**v0.1a (Parser Foundation)**
- **Ship**: Reader, parser (indentation tree + repeated-prefix index), `name` map resolution, minimal object/object-group resolution (enough for MVP-15), password hash classification, ASA defaults model (scoped to MVP-15 absence checks).
- **Gate**: 100% parser unit tests (TR-03) + clean parse of two real sanitized ASA configs (TR-07) with no unparsed or misassigned lines.
- **Cut if needed**: Deep recursive resolution (FR-05b) and unused-object hygiene are explicitly deferred to v0.2. This is correct.

**v0.1b (MVP Checks + Output)**
- **Ship**: MVP-15 checks (presence + context-conditional absence), Markdown/CSV output, default secret masking, run summary, check profiles (commercial/DoD).
- **Gate**: Exact seeded true positives (TSC-02) + zero false positives (TSC-03) on the synthesized fixture. Cross-runtime equivalence (TSC-09) must pass.
- **Cut if needed**: None. The MVP-15 list is already minimal. If time pressure arises, defer the DoD profile to v0.2, but this is not recommended as it is a small, well-scoped addition.

**v0.2 (Coverage)**
- **Ship**: Full CIS/STIG catalog (FR-12), deep object resolution (FR-05b), undefined-reference/unbound-ACL detection (FR-13), second independent fixture (TR-05), version/EoL lookup (FR-15).
- **Gate**: Same check gate as v0.1b (exact expected findings, zero FP) on both fixtures.

**v0.3 (Depth)**
- **Ship**: ACL shadowing/redundancy (FR-14), performance hardening (NFR-04), baseline/suppression (FR-18).
- **Gate**: Performance tests (TSC-10) + shadowing accuracy on crafted fixtures.

### What to Cut First
If the v0.1a gate fails due to parser complexity, the first scope reduction should be to **drop the repeated-prefix index for non-critical families** (e.g., defer `banner` and `nat` grouping to v0.2) and focus on the indentation tree + `name` map + `access-list`/`crypto map` families. This reduces parser surface area while retaining the core value (ACL and crypto checks depend on these). However, this is a last resort: the current design already limits v0.1a to minimal resolution, which is appropriate.

---

## Critical Path and Leverage

The parser is the load-bearing component, and the plan correctly derisks it first in v0.1a. The next highest-leverage items are:
1. **ASA defaults model**: If this is incorrect, all absence checks will be systematically wrong. The design mitigates this by scoping the defaults model to the MVP-15 checks first (OQ-1), but this must be validated early.
2. **Minimal resolution boundary**: The MVP-15 checks must not require deep resolution (FR-05a). The design explicitly declares this dependency per check, which is the right approach. If any MVP check silently requires deep resolution, it will fail in v0.1b.
3. **Fixture fidelity**: The synthesized fixture must be syntactically faithful to real ASA 5515 configs, including edge cases (e.g., multi-line banners, nested object-groups). The test plan (TR-01/02) covers this, but the fixture's accuracy is a single point of failure.

The plan derisks the parser first, which is correct. The defaults model and fixture fidelity should be the next focus areas, as they are the most likely to cause systemic issues if flawed.

---

## Critical Contradictions and Feasibility Problems

### CRITICAL
1. **Parser feasibility for repeated-prefix families vs indented blocks**
   - **Sources**: ARCHITECTURE.md §2 (design decision) vs CHECK_CATALOG.md B1/B2 (parser syntax reference).
   - **Conflict**: The design requires the parser to handle both indented blocks (e.g., `interface` → `nameif`) and repeated-prefix flat families (e.g., `access-list NAME ...`) in a single pass. The CHECK_CATALOG explicitly lists constructs that are flat (e.g., `access-list`, `crypto map`, `name`, `nat`, `banner`) and must not be treated as indented children.
   - **Feasibility**: The proposed two-index approach (indentation tree + repeated-prefix index) is sound and matches prior art (ciscoconfparse2). However, the implementation complexity is high, and a defect here will corrupt all downstream checks. The mitigation (explicitly listing which constructs are flat vs indented) is correct, but the risk remains.
   - **Action**: The v0.1a gate (clean parse of two real configs) is the right check. If this fails, the parser design must be revisited.

2. **Minimal resolution sufficiency for MVP-15 checks**
   - **Sources**: ARCHITECTURE.md §3 (minimal resolution in v0.1a) vs CHECK_CATALOG.md A8 (MVP-15 list) vs REQUIREMENTS.md FR-05a (each check declares dependency).
   - **Conflict**: The MVP-15 includes checks like `permit ip any any`, which may be hidden behind object-groups (e.g., `permit ip object-group ANY object-group ANY`). The design claims minimal resolution is sufficient, but the CHECK_CATALOG does not explicitly confirm that all MVP-15 checks can be evaluated without deep resolution.
   - **Feasibility**: The design mitigates this by requiring each check to declare whether it operates on resolved or raw text (FR-05a). However, if any MVP-15 check implicitly requires deep resolution, v0.1b will fail.
   - **Action**: Audit the MVP-15 checks against the CHECK_CATALOG to confirm that minimal resolution is sufficient. For example:
     - `permit ip any any`: Requires resolving object-groups to confirm they expand to `any`. Minimal resolution must cover this.
     - `aaa authentication ssh console`: Does not require resolution (flat check).
     - `logging enable`: Absence check; no resolution needed.
   - **Recommendation**: Explicitly document which MVP-15 checks require resolution and confirm that minimal resolution covers them. If not, either:
     - Defer the check to v0.2, or
     - Expand minimal resolution to cover the gap.

### HIGH
3. **Defaults model accuracy for absence checks**
   - **Sources**: ARCHITECTURE.md §5 (defaults model) vs CHECK_CATALOG.md A1–A7 (absence checks) vs SUCCESS_CRITERIA.md TSC-04.
   - **Conflict**: The design relies on a documented ASA 9.x defaults model to drive absence checks (e.g., `logging enable` is off by default). If the defaults model is incorrect for any check, the absence detection will be systematically wrong.
   - **Feasibility**: The design mitigates this by scoping the defaults model to the MVP-15 checks first (OQ-1). However, the CHECK_CATALOG includes many absence checks (e.g., `console timeout 0` is a finding because the default is no timeout), and the defaults model must be accurate for all of them.
   - **Action**: The defaults model must be a separately tested component (as stated in ARCHITECTURE.md §5). Prioritize validating the defaults for the MVP-15 absence checks (e.g., `logging enable`, `ssh version 2`, `console timeout`, `uRPF`, `threat-detection`).

4. **Fixture fidelity for real ASA syntax**
   - **Sources**: DISCOVERY_NOTES.md OQ-4 (no real config available) vs SUCCESS_CRITERIA.md §4 (fixture-based validation) vs REQUIREMENTS.md TR-07 (real-config gate).
   - **Conflict**: The project has no access to a real ASA 5515 config or device for testing. Validation relies on a synthesized fixture and two real sanitized configs from GitHub. If the fixture or real configs do not cover edge cases (e.g., nested object-groups, multi-line banners, `nt-encrypted` passwords), the parser or checks may fail on real engagement configs.
   - **Feasibility**: The design mitigates this by:
     - Using prior art (ciscoconfparse2, ASA-ACL-toolkit) to inform the parser.
     - Requiring TR-07 (clean parse of two real configs) as a v0.1a gate.
     - Explicitly flagging lower-confidence parser branches (CHECK_CATALOG B6).
   - **Action**: The synthesized fixture must include examples of all lower-confidence constructs (B6) and all MVP-15 check scenarios. The two real configs must be audited to confirm they exercise the parser's critical paths (e.g., nested blocks, repeated-prefix families).

5. **Password hash classification for `nt-encrypted`**
   - **Sources**: CHECK_CATALOG.md B3 (classification rules) vs SUCCESS_CRITERIA.md TSC-05 (gate relaxed for `nt-encrypted`).
   - **Conflict**: The `nt-encrypted` branch is marked as `[lower confidence]` in CHECK_CATALOG B6, and the gate for TSC-05 is relaxed to "classified as not-cleartext" (not exact subtype) until a confirmed example is obtained.
   - **Feasibility**: This is a known gap. The design correctly relaxes the gate, but the classification logic must still handle `nt-encrypted` lines without misclassifying them as cleartext (which would be a high-severity miss).
   - **Action**: Ensure the classifier treats `nt-encrypted` as a distinct non-cleartext type, even if the exact format is uncertain. The gate for v0.1a/v0.1b should accept "not cleartext" as sufficient for `nt-encrypted`.

### MEDIUM
6. **Context-conditional absence checks**
   - **Sources**: ARCHITECTURE.md §5 (context-conditional absence) vs CHECK_CATALOG.md (e.g., uRPF only on outside interface).
   - **Conflict**: The design requires absence checks to be context-conditional (e.g., uRPF absence is a finding only on untrusted interfaces). Implementing this requires the parser to correctly identify interface contexts (e.g., `interface GigabitEthernet0/0` with `nameif outside`).
   - **Feasibility**: The parser's indentation tree should enable this, but the logic for determining "untrusted" (e.g., `security-level 0`) must be accurate. If the parser misassigns interface blocks, context-conditional checks will fail.
   - **Action**: Include test cases in the fixture for context-conditional checks (e.g., uRPF absent on outside interface = finding; uRPF absent on inside interface = no finding).

7. **Check catalog schema drift**
   - **Sources**: REQUIREMENTS.md DR-04 (catalog schema) vs ARCHITECTURE.md §4 (data/code boundary).
   - **Conflict**: The catalog schema is fixed in DR-04, but the boundary between data (catalog) and code (structural checks) could drift if structural checks are accidentally added to the catalog.
   - **Feasibility**: The design mitigates this by requiring structural checks to live in a named module (ARCHITECTURE.md §4). However, the risk of drift remains if the boundary is not enforced.
   - **Action**: Add a test that asserts all catalog entries are evaluable without engine changes (as stated in ARCHITECTURE.md §4). This test should fail if a structural check is added to the catalog.

---

## Security Findings

### Trust Boundaries
- The only untrusted input is the config file (IR-01). The tool correctly treats it as inert text (SR-06) and bounds its handling (SR-07).
- The trust boundary is the analyst's machine. The tool's output (Markdown/CSV) is sensitive and must be protected by the analyst (stated in ARCHITECTURE.md §8).

### Threat Model
- **Attacker**: Malicious or malformed config file (only input).
- **Attack vectors**:
  1. **Resource exhaustion**: Oversized or hostile config file (e.g., deeply nested blocks, extremely long lines) could exhaust memory or CPU.
     - **Mitigation**: SR-07 requires max file-size guard, bounded reads, and regex anchors to avoid catastrophic backtracking. This is sound.
  2. **Injection**: Config file contains malicious PowerShell code (e.g., via `Invoke-Expression`).
     - **Mitigation**: SR-06 explicitly prohibits dynamic evaluation of config content. The tool processes config as inert text only. This is sound.
  3. **Credential leakage**: Output files (Markdown/CSV) contain secret values (passwords, keys, PSKs).
     - **Mitigation**: SR-04 requires default-on secret masking in all output. The `-RevealSecrets` flag is opt-in. This is sound.
  4. **Denial of service**: Config file causes parser to hang or crash (e.g., via regex backtracking).
     - **Mitigation**: SR-07 requires compiled, simply-anchored regex. This is sound but must be verified in implementation.

### Controls Effectiveness
- The offline/read-only/no-egress posture (SR-01/02/03) is effective against network-based exfiltration.
- The inert-text processing (SR-06) and input bounding (SR-07) are effective against injection and resource exhaustion, assuming correct implementation.
- Default-on masking (SR-04) is effective against credential leakage in output, but the analyst must still protect the output files (stated in ARCHITECTURE.md §8).

### Gaps
- **No explicit handling of encoding attacks**: The config file could use unusual encodings (e.g., UTF-16, UTF-8 with BOM) to bypass input validation. The design does not address this.
  - **Recommendation**: The reader (Read-AsaConfig.ps1) must explicitly handle encoding (e.g., detect and reject non-UTF-8 or force UTF-8) and strip BOMs. This should be added to SR-07.
- **No explicit handling of path traversal**: The `-OutputDirectory` parameter could be manipulated to write files outside the intended directory.
  - **Recommendation**: Validate that `-OutputDirectory` is a child of the current working directory or an absolute path under the analyst's control. This should be added to SR-02.

---

## Efficacy

### Will the Approach Achieve Its Goals?
- **Yes for the core value proposition**: The hierarchical parser + absence checks + declarative catalog will surface findings that flat grep cannot (e.g., undefined references, context-conditional absences). This is a clear improvement over ad-hoc scripting.
- **Yes for repeatability**: The deterministic output requirements (NFR-06) and staged gates (TSC-02/03) ensure repeatable results.
- **Partial for completeness**: The MVP-15 checks cover the highest-signal findings, but the full CIS/STIG catalog (v0.2) is needed for comprehensive coverage. This is acceptable for an MVP.

### Likely Evasion/Degradation
- **Object-group nesting**: If the parser's minimal resolution does not handle nested object-groups (e.g., `object-group A` contains `group-object B`, which contains `group-object C`), checks like `permit ip any any` may miss cases where the expansion is hidden behind multiple layers.
  - **Mitigation**: The design explicitly defers deep resolution to v0.2 (FR-05b). For v0.1b, the MVP-15 checks must not rely on deep nesting. Audit the MVP-15 to confirm this.
- **Context misclassification**: If the parser misassigns interface contexts (e.g., fails to associate `nameif outside` with its `interface`), context-conditional checks (e.g., uRPF) will produce false positives/negatives.
  - **Mitigation**: The fixture must include test cases for context-conditional checks, and the parser tests (TR-03) must cover interface block parsing.
- **Token drift**: ASA syntax varies across versions (e.g., IKEv1 `hash` vs IKEv2 `integrity`). If the parser's regex anchors are not version-agnostic, some checks may fail on configs from different ASA trains.
  - **Mitigation**: The CHECK_CATALOG B4 includes regex anchors for both IKEv1 and IKEv2. The parser must use these anchors and handle both syntaxes.

### Recommended Design Changes
1. **Explicitly scope the defaults model to MVP-15 absence checks first** (OQ-1). This is already stated but should be a hard requirement for v0.1a.
2. **Add a test to verify that all MVP-15 checks are evaluable with minimal resolution**. This ensures FR-05a is satisfied.
3. **Add a test to verify that context-conditional checks (e.g., uRPF) are scoped to the correct interfaces**. This ensures the parser's context tracking is accurate.

---

## Performance and Cost

### Levers That Matter
- **Parser efficiency**: The indentation-stack approach is O(n) for well-formed configs. The repeated-prefix index is also O(n) if built in a single pass. This is sound.
- **Regex efficiency**: Compiled, simply-anchored regex (SR-07) avoids catastrophic backtracking. This is sound.
- **Resolution cost**: Minimal resolution (v0.1a) is O(n) for symbol table construction. Deep resolution (v0.2) could be O(n^2) for nested object-groups, but this is deferred.
- **Check evaluation**: Each check is O(n) or O(1) against the parsed model. With ~80 checks, this is acceptable for configs up to 20,000 lines (NFR-04).

### Risks
- **PowerShell performance**: PowerShell is slower than compiled languages for text processing. A 20,000-line config may push the 10-second limit (NFR-03) on a slow machine.
  - **Mitigation**: The design includes performance as a v0.3 focus (NFR-04). For v0.1a/v0.1b, the 5,000-line limit (NFR-03) is achievable.
- **Memory usage**: The parsed model (indentation tree + repeated-prefix index) could consume significant memory for large configs.
  - **Mitigation**: The design does not address this explicitly. For v0.1a/v0.1b, this is acceptable, but v0.2 should include memory profiling.

---

## Acceptance Criteria and Gates

### Strengths
- The success criteria are well-formed and measurable (TSC-01 to TSC-11, BSC-01 to BSC-05).
- The gates are explicit and staged (v0.1a parser gate, v0.1b check gate).
- The test plan (§3) ties each criterion to a test, data source, and threshold.

### Weaknesses
- **TSC-09 (cross-runtime equivalence)**: The gate is "identical finding set with identical evidence," but the implementation target is byte-identity (NFR-06). This is a minor inconsistency but acceptable.
- **TSC-05 (secret classification)**: The gate for `nt-encrypted` is relaxed to "not cleartext," but the criterion does not explicitly state this. This should be clarified in SUCCESS_CRITERIA.md.
- **TR-07 (real-config gate)**: The gate requires clean parsing of two real sanitized configs, but the success criteria do not explicitly state that these configs must cover all MVP-15 check scenarios. This should be added.

### Recommendations
1. **Clarify TSC-05**: Explicitly state that `nt-encrypted` lines must be classified as non-cleartext (not necessarily exact subtype) for v0.1a/v0.1b.
2. **Strengthen TR-07**: Require that the two real configs include examples of all MVP-15 check scenarios (e.g., `permit ip any any`, `ssh version 1`, etc.).
3. **Add a gate for the defaults model**: Require that the defaults model passes a test suite covering all MVP-15 absence checks.

---
## Design Risks That Need Better Framing

1. **Over-reliance on regex for parsing**: The parser uses regex anchors (CHECK_CATALOG B4) to identify constructs. While this is acceptable for a line-oriented config format, regex can be brittle for nested structures (e.g., object-groups). The design mitigates this by using the indentation tree for hierarchy, but the regex anchors must be robust.
   - **Recommendation**: Document the regex patterns in a single source of truth (e.g., a `regex.ps1` module) and test them independently of the parser.

2. **Fixture-as-oracle circularity**: The synthesized fixture is the primary validation source, but it is created by the team. The design mitigates this by requiring TR-07 (real-config parsing), but the fixture's accuracy is still a risk.
   - **Recommendation**: Explicitly state in the docs that the fixture is not a substitute for real-config validation and that the tool's accuracy on real engagement configs is the ultimate test.

3. **Authority ID drift**: Some CIS/STIG IDs are `[unverified]` (RESEARCH OQ-A). The design mitigates this by treating authority IDs as advisory and requiring evidence-per-finding (SR-05). However, the CHECK_CATALOG still includes these IDs.
   - **Recommendation**: Add a `verified` flag to the catalog schema (DR-04) and filter out `[unverified]` IDs from the default output (or mark them clearly in the report).

---
## Recommendations by Priority

### P0 (Fix Before Coding)
1. **Confirm minimal resolution sufficiency for MVP-15 checks**
   - Audit the MVP-15 checks (CHECK_CATALOG A8) against the parser's minimal resolution (FR-05a). Ensure that all checks that require resolution (e.g., `permit ip any any` behind object-groups) are covered by minimal resolution. If not, either:
     - Defer the check to v0.2, or
     - Expand minimal resolution to cover the gap.
   - **Evidence**: CHECK_CATALOG A8, ARCHITECTURE.md §3, REQUIREMENTS.md FR-05a.

2. **Validate the ASA defaults model for MVP-15 absence checks**
   - Create a test suite for the defaults model covering all MVP-15 absence checks (e.g., `logging enable`, `ssh version 2`, `console timeout`, `uRPF`). Ensure the model's defaults match ASA 9.x documentation.
   - **Evidence**: ARCHITECTURE.md §5, CHECK_CATALOG A1–A7, SUCCESS_CRITERIA.md TSC-04.

3. **Add explicit handling for encoding and path traversal**
   - Update SR-07 to require the reader to handle encoding (e.g., detect and reject non-UTF-8 or strip BOMs).
   - Update SR-02 to require validation of `-OutputDirectory` to prevent path traversal.
   - **Evidence**: Security Findings section.

### P1 (Address Before v0.1a)
4. **Ensure the synthesized fixture covers all MVP-15 scenarios and lower-confidence parser branches**
   - The fixture must include:
     - All MVP-15 check scenarios (true positives and true negatives).
     - All lower-confidence parser branches (CHECK_CATALOG B6: `object-group service`, `nt-encrypted`, etc.).
     - Context-conditional checks (e.g., uRPF on outside interface).
   - **Evidence**: REQUIREMENTS.md TR-01/02, CHECK_CATALOG B6.

5. **Add a test to verify the data/code boundary**
   - Add a test that asserts all catalog entries are evaluable without engine changes. This ensures the boundary drawn in ARCHITECTURE.md §4 does not drift.
   - **Evidence**: ARCHITECTURE.md §4, REQUIREMENTS.md DR-04.

6. **Clarify TSC-05 for `nt-encrypted`**
   - Explicitly state in SUCCESS_CRITERIA.md that `nt-encrypted` lines must be classified as non-cleartext (not exact subtype) for v0.1a/v0.1b.
   - **Evidence**: SUCCESS_CRITERIA.md TSC-05, CHECK_CATALOG B6.

### P2 (Address Before v0.1b)
7. **Strengthen TR-07 to require coverage of MVP-15 scenarios**
   - Require that the two real sanitized configs include examples of all MVP-15 check scenarios.
   - **Evidence**: REQUIREMENTS.md TR-07, SUCCESS_CRITERIA.md §4.

8. **Add a gate for the defaults model**
   - Require that the defaults model passes a test suite covering all MVP-15 absence checks.
   - **Evidence**: ARCHITECTURE.md §5, SUCCESS_CRITERIA.md TSC-04.

---
## Documentation and Process Improvements

1. **Single source of truth for regex patterns**
   - Consolidate all regex anchors (CHECK_CATALOG B4) into a single module (e.g., `src/RegexPatterns.ps1`) to avoid drift and enable independent testing.
   - **Evidence**: CHECK_CATALOG.md B4, ARCHITECTURE.md §2.

2. **Consistency matrix for checks vs parser capabilities**
   - Create a matrix mapping each MVP-15 check to:
     - Whether it requires resolution (and if so, minimal or deep).
     - Whether it is presence-based or absence-based.
     - Whether it is context-conditional.
   - This will help validate FR-05a and ensure the parser's capabilities match the checks' requirements.
   - **Evidence**: CHECK_CATALOG.md A8, REQUIREMENTS.md FR-05a.

3. **Explicitly document the fixture's limitations**
   - State in the docs that the fixture is syntactically faithful but may not cover all real-world edge cases. Emphasize that TR-07 (real-config parsing) is the ultimate validation.
   - **Evidence**: DISCOVERY_NOTES.md OQ-4, SUCCESS_CRITERIA.md §4.

4. **Add a `verified` flag to the catalog schema**
   - Extend DR-04 to include a `verified` flag for authority IDs. Filter out `[unverified]` IDs from the default output or mark them clearly in the report.
   - **Evidence**: RESEARCH.md OQ-A, REQUIREMENTS.md DR-04.

---
## Bottom Line

The core idea is worth building: an offline, PowerShell-native ASA config analyzer with a hierarchical parser and absence-based checks fills a real gap and enables findings that ad-hoc scripting cannot. The first milestone (v0.1a) is the right shape, focusing on the parser and its immediate dependencies. However, the parser's correctness on real ASA syntax and the accuracy of the defaults model are the load-bearing risks. If unaddressed, parser defects will corrupt all downstream findings, and an incorrect defaults model will produce systematic errors in absence checks. Before coding begins, the team must confirm that minimal resolution is sufficient for the MVP-15 checks and validate the defaults model against ASA 9.x documentation. The consequence of starting from the current material unchanged is a high risk of rework if the parser or defaults model prove inadequate for the MVP checks.