# cisco-asa-review Architecture and Project Assessment

- Author: mistral (mistral-medium-latest)
- Date: 2026-06-24 09:49
- Scope: background/goal.md, claude-dev/20260624_asa-config-analysis_RESEARCH.md, claude-dev/CHECK_CATALOG.md, claude-dev/DISCOVERY_NOTES.md, claude-dev/REQUIREMENTS.md, claude-dev/SUCCESS_CRITERIA.md, claude-dev/VISION.md
- Repository state: documentation-only, no code

---

## Executive Summary

The core idea is sound: a PowerShell-based, offline, static analyzer for Cisco ASA 5515 `running-config` files fills a real gap (no existing PowerShell-native tool) and addresses a concrete analyst need (repeatable, evidence-backed security reviews). The research is thorough, the check catalog is well-sourced, and the architectural bets (offline static analysis, PowerShell substrate, declarative checks) are defensible. However, the **first milestone (v0.1) is over-scoped**. The MVP must be cut to a true minimum: the hierarchical parser (indentation tree + repeated-prefix index) and **only the 3–5 highest-signal absence/presence checks** (e.g., `telnet` present, `ssh version` missing/v1, `permit ip any any`, cleartext secrets). The current v0.1 includes 15 checks, name/object resolution, and full evidence citation—this is a v0.2 wearing a v0.1 label. The load-bearing risk is **parser correctness**: if the indentation-stack model or repeated-prefix grouping fails on real ASA syntax, all downstream checks are invalid. This must be derisked first with a **synthesized fixture** that covers the gotchas in CHECK_CATALOG B5, and the success criteria must gate v0.1 on parser validation, not check coverage. The project will sink if it ships a parser that cannot reliably distinguish indented blocks from repeated-prefix families, or if it treats absence-based checks as an afterthought.

---

## What Validates Well

- **Concept and thesis**: The problem is real (no PowerShell-native ASA analyzer), the constraints are clear (offline, PowerShell-only, no egress), and the approach (static parsing + declarative checks) is proven by prior art (ciscoconfparse2, nipper-ng). The decision to anchor checks in CIS + DISA STIG is sound and aligns with enterprise expectations.
- **Research depth**: The prior-art survey (`20260624_asa-config-analysis_RESEARCH.md`) is exceptional. It identifies the right parsing model (hierarchical indentation tree + repeated-prefix index), the right check catalog sources (CIS ASA 9.x, DISA ASA STIG), and the right high-signal checks. The CHECK_CATALOG.md is a usable specification for the check engine.
- **Security posture**: The non-functional requirements (NFR-01/02, SR-01/02/03) correctly enforce offline, read-only, no-egress behavior. The threat model is implicit but sound: the tool’s output is the attack surface, and the constraints prevent data leakage.
- **Architectural separation**: AR-01 (parse layer vs. check layer), AR-02 (indentation-stack parser), AR-03 (independent check units), and AR-04 (output formatting separation) are all correct and will age well.
- **Success criteria**: TSC-01 (parser correctness) and TSC-02/03 (true positives/false positives) are the right gates. The fixture-based validation (TR-01/02) is the only feasible path given OQ4 (no real device/config).

---

## Scope and Sequencing

### Current Scope Problems
1. **v0.1 is too large**: The MVP (v0.1) includes:
   - Hierarchical parser (FR-02/03/04/05)
   - Name/object resolution (FR-04/05)
   - 15 checks (FR-11)
   - Absence-based checks (FR-08)
   - Secret classification (FR-09/10)
   - Markdown + CSV output (FR-16)
   - Cross-runtime compatibility (NFR-01/02)
   This is a **v0.2 or v0.3** scope. A true v0.1 should prove the parser and 3–5 checks.

2. **Sequencing risk**: The parser (FR-02/03/04/05) is the load-bearing component. If it fails on nested blocks or repeated-prefix families, all checks are invalid. The plan does not derisk this first.

### Proposed Phased Milestones
| Milestone | Scope | Success Gate | Cut if Blocked |
|-----------|-------|--------------|----------------|
| **v0.1 (Parser Validation)** | Indentation-stack parser (FR-02), repeated-prefix index (FR-03), `name` symbol table (FR-04). **No checks.** | TSC-01: 100% parser unit tests pass on fixture covering CHECK_CATALOG B5 gotchas. | Nothing; this is the foundation. |
| **v0.2 (MVP Checks)** | Add 5 highest-signal checks (telnet, SSH version, `permit ip any any`, cleartext secrets, `console timeout`). | TSC-02/03: 100% true positives, 0 false positives on seeded fixture. | Reduce to 3 checks if parser validation slips. |
| **v0.3 (Absence + Secrets)** | Add absence-based checks (logging, uRPF, banner) and secret classification (FR-08/09/10). | TSC-04/05: All absence checks and credential classification pass. | Defer secret classification if `nt-encrypted` parsing is unstable. |
| **v0.4 (Full MVP)** | Remaining 10 MVP checks (FR-11), object resolution (FR-05), Markdown/CSV output (FR-16). | TSC-02/03/06/07: All MVP checks pass. | Defer object resolution if parser nesting is fragile. |
| **v0.5 (Scale)** | Full CIS/STIG catalog (FR-12), structural checks (FR-13), version/EoL lookup (FR-15). | TSC-02/03 for full catalog. | Defer version lookup if EoL data is volatile. |
| **v0.6 (Depth)** | ACL shadowing (FR-14), baseline/suppression (FR-18). | TSC-02/03 for structural checks. | Out of scope if performance degrades. |

**Cut from v0.1**:
- All checks (FR-06/07/08/09/10/11).
- Object resolution (FR-05).
- Output formatting (FR-16) beyond a raw dump of the parsed tree for debugging.
- Cross-runtime testing (NFR-01/02) until parser is stable.

**Why this sequence**:
- The parser is the single point of failure. If it cannot correctly model `object-group` nesting or `access-list` grouping, no check can be trusted.
- Absence-based checks (FR-08) are harder to implement correctly than presence checks. They should follow, not lead.
- Secret classification (FR-09/10) depends on correct parsing of `snmp-server`, `aaa-server`, `ntp`, and `tunnel-group` blocks. These are repeated-prefix families and must be validated in v0.1.

---

## Critical Path and Leverage

- **Load-bearing component**: The **indentation-stack parser + repeated-prefix index** (FR-02/03). This is the only component that, if broken, invalidates the entire project. The check engine, output formatters, and even the catalog can be rewritten; the parser cannot.
- **Leverage point**: The **synthesized fixture** (TR-01/02). Without a fixture that covers all gotchas in CHECK_CATALOG B5 (nested blocks, repeated-prefix families, `name` resolution, password hashes, multi-line banners), the parser cannot be validated. Building this fixture is the highest-leverage task for v0.1.
- **Critical dependency**: The **check catalog’s authority IDs are advisory** (RESEARCH OQ-A). This is a strength, not a risk: it forces the tool to justify findings by config evidence, not citations. However, it means the catalog data must include **explicit PASS/FAIL patterns** (as in CHECK_CATALOG.md) and not rely on IDs alone.

---
---
## Critical Contradictions and Feasibility Problems

### CRITICAL: Parser Model vs. Real ASA Syntax
- **Conflict**:
  - `20260624_asa-config-analysis_RESEARCH.md` §5 states: "Hierarchy = leading whitespace (1 space/level in real `show run`; key on 'has leading whitespace' + indent stack, never a hardcoded count)."
  - `CHECK_CATALOG.md` B1 states: "Indented blocks: `interface`, `object network/service`, ... Most blocks are 1 level deep; a few nest 2–3 deep."
  - `CHECK_CATALOG.md` B5 gotcha 1: "Indent = 1 space; use a stack, support 2–3 deep nesting."
  - **Problem**: The parser must handle **both** indented blocks (parent/child) **and** repeated-prefix flat families (e.g., `access-list NAME` lines that are not indented but are semantically grouped). The research correctly identifies this, but the **feasibility of implementing this in PowerShell without a full grammar** is unproven. A flat regex approach will fail on nested `object-group` or `group-policy attributes` → `webvpn` → `anyconnect` blocks.
- **Impact**: If the parser cannot distinguish these cases, checks that depend on object resolution (e.g., undefined references) or nested context (e.g., `webvpn` in `group-policy` vs. global) will produce false positives/negatives.
- **Resolution**: v0.1 must **only** validate the parser against a fixture that includes:
  - 2–3 deep nesting (`group-policy` → `webvpn` → `anyconnect`).
  - Repeated-prefix families (`access-list`, `crypto map`, `name`).
  - Multi-line banners.
  - Both NAT shapes (indented object-NAT vs. flat twice-NAT).
  - Both `webvpn` contexts (global vs. group-policy).
  If the parser cannot handle these, v0.1 fails.

### HIGH: Absence-Based Checks vs. Parser Completeness
- **Conflict**:
  - `REQUIREMENTS.md` FR-08: "The check engine MUST support absence-based checks."
  - `CHECK_CATALOG.md` B5 gotcha 7: "Detect findings by ABSENCE (logging enable, uRPF, threat-detection, banner, ssh version 2)."
  - **Problem**: Absence-based checks require the parser to **know what should exist** in a correct config. This is not just a missing line; it is a semantic model of ASA defaults. For example:
    - `logging enable` is off by default (so absence = finding).
    - `ssh version 2` is not the default (v1 is negotiable), so absence = finding.
    - `ip verify reverse-path` is off by default, so absence = finding.
  - The parser must therefore **not just parse what is present, but also reason about what is missing**. This is a higher-order requirement than presence checks.
- **Impact**: If the absence model is incorrect (e.g., misclassifying a default), the tool will flag false positives or miss true findings.
- **Resolution**: Defer absence-based checks to v0.3. v0.2 should only include presence-based checks (e.g., `telnet` present, `permit ip any any`, cleartext secrets).

### HIGH: Secret Classification vs. Token Drift
- **Conflict**:
  - `CHECK_CATALOG.md` B3 defines password hash classification as:
    - `pbkdf2` or `$sha512$...` → strong.
    - `encrypted` → weak.
    - `nt-encrypted` → NT.
    - No token + not `$sha512$` → cleartext.
  - `CHECK_CATALOG.md` B6 flags `nt-encrypted` value layout as `[lower confidence]`.
  - **Problem**: The `nt-encrypted` token may not appear in all ASA 9.x versions, or its format may vary. The research does not confirm its exact syntax across versions.
- **Impact**: Misclassifying `nt-encrypted` as cleartext (or vice versa) will cause false positives/negatives in secret findings.
- **Resolution**: In v0.1, **only classify `pbkdf2`/`$sha512$` as strong and `encrypted` as weak**. Treat `nt-encrypted` as "unknown" and flag it as a warning, not a finding. Revisit in v0.3 after fixture validation.

### MEDIUM: Authority ID Drift vs. Finding Validity
- **Conflict**:
  - `20260624_asa-config-analysis_RESEARCH.md` OQ-A: "Exact CIS recommendation numbers and some STIG V-IDs could not all be verified; they move across benchmark revisions."
  - `REQUIREMENTS.md` SR-05: "A finding MUST be defensible by its config evidence independent of its authority ID."
  - **Problem**: The CHECK_CATALOG.md includes `[unverified]` authority IDs (e.g., "narrative [unverified]" in A1, A4, A6). If a finding’s only justification is an `[unverified]` ID, it violates SR-05.
- **Impact**: Findings tied to unverified IDs may be challenged by clients or auditors.
- **Resolution**: The check catalog data **must** include:
  - A **PASS/FAIL pattern** (regex or absence) for each check.
  - An **authority ID** (marked as verified or unverified).
  - A **human-readable rationale** explaining why the pattern indicates a risk.
  The tool must **never** emit a finding based solely on an unverified ID. This is already implied by SR-05 but should be explicit in the catalog schema.

### MEDIUM: Fixture Fidelity vs. Real Configs
- **Conflict**:
  - `DISCOVERY_NOTES.md` OQ4: "No real or sanitized ASA config is available and no device exists for testing."
  - `SUCCESS_CRITERIA.md` §4: "No iteration is 'shipped' until the tool has performed a real parse of a real ASA `running-config`-format fixture."
  - **Problem**: The fixture must be **syntactically faithful** to real ASA 9.x configs, but the team has no real config to validate against. The research uses "real sanitized configs" from GitHub (e.g., HussainYaqoob/SFC-Project), but these may not cover all edge cases.
- **Impact**: The fixture may miss edge cases (e.g., rare `object-group` nesting, obscure `crypto` syntax), leading to a parser that works on the fixture but fails on real configs.
- **Resolution**:
  1. Build the fixture from **multiple real sanitized configs** (e.g., HussainYaqoob/SFC-Project, nicholasrowley/Cisco-Network-Security-Lab).
  2. Include **all gotchas from CHECK_CATALOG B5** explicitly.
  3. Add a **second, independently authored fixture** (TR-05) in v0.2 to guard against overfitting.
  4. State the validation bound honestly in release notes (as SUCCESS_CRITERIA §4 requires).

---
---
## Security Findings

### Trust Boundaries
- The tool’s **only input** is a local config file (FR-01). The trust boundary is the analyst’s machine.
- The tool **must not** make network calls (SR-01), modify files (SR-02), or leak config data (SR-03/04). These are correctly enforced by requirements.

### Attack Surface
- **Output files**: Markdown and CSV may contain config snippets (evidence). SR-04 requires masking secrets in output, but this is not yet specified in the design.
  - **Risk**: If a secret (e.g., `snmp-server community public`) is included in the evidence, it may appear in the report.
  - **Mitigation**: The tool must **mask secrets in output** (e.g., replace `community public` with `community [REDACTED]`). This should be a requirement (add to SR-04).
- **Parser injection**: The config is treated as untrusted input. The parser must not execute or evaluate any part of the config (e.g., no `Invoke-Expression` on config lines).
  - **Risk**: A maliciously crafted config could exploit PowerShell’s parser if the tool uses `Invoke-Expression` or dynamic code generation.
  - **Mitigation**: The parser must use **pure text processing** (regex, string manipulation). No dynamic code execution. This should be explicit in AR-02.

### Threat Model Gaps
- **No explicit threat model document**: The project lacks a formal threat model (e.g., STRIDE for the tool itself). The security requirements (SR-01/02/03/04/05) cover the main risks, but a threat model would help validate completeness.
- **No supply-chain risk assessment**: The tool is self-contained (NFR-05), but there is no discussion of dependencies (e.g., PowerShell 5.1 baseline modules). Since the tool uses no external modules, this is low risk, but it should be stated explicitly.

---
---
## Efficacy

### Will the Approach Detect What It Claims?
- **Yes, for presence-based checks**: Checks like `telnet` present, `permit ip any any`, or cleartext secrets are straightforward pattern matches. These will work if the parser correctly groups lines.
- **Yes, for absence-based checks, if the model is correct**: Checks like `logging enable` absent or `ssh version 2` missing will work if the tool’s default model matches ASA’s actual defaults.
- **No, for structural checks without object resolution**: Checks like "ACL references undefined object-group" (CHECK_CATALOG A4) require full object resolution (FR-05). Without this, the tool cannot detect these findings. **Defer to v0.4**.
- **Partial, for ACL shadowing**: The ASA-ACL-toolkit approach (FR-14) is a heuristic and may miss some cases. This is acceptable as a vNext feature.

### Highest-Value Efficacy Improvements
1. **Prioritize presence-based checks in v0.2**: These are the most reliable and highest-signal.
2. **Validate the absence model early**: Use the fixture to confirm which settings are off-by-default in ASA 9.x.
3. **Add object resolution in v0.3**: This unlocks undefined-reference and unused-object detection, which are high-value for analysts.

---
---
## Performance and Cost

- **Performance**: The parser’s complexity is O(n) for a single pass (indentation stack + repeated-prefix indexing). The resolution layer (object/group expansion) is O(n * m) where m is the depth of nesting. For a 5,000-line config, this should be well under 10 seconds in PowerShell (NFR-03). The main risk is **regex performance** in PowerShell, which can be slow for complex patterns.
  - **Mitigation**: Use **compiled regex** (`[regex]::new()`) and avoid backtracking-heavy patterns. Prefer simple anchors (e.g., `^\s*interface`).
- **Cost**: The main cost is **development time**, not runtime. The parser and fixture will take the most effort. The check catalog can be built incrementally.

---
---
## Acceptance Criteria and Gates

### Strengths
- TSC-01 (parser correctness) and TSC-02/03 (true positives/false positives) are the right primary gates.
- The fixture-based validation (TR-01/02) is the only feasible path given OQ4.
- The "real call returns data" gate (SUCCESS_CRITERIA §4) correctly ties success to fixture validation.

### Weaknesses
- **No explicit gate for parser validation before checks**: The current plan allows checks to be implemented before the parser is validated. This is backwards.
  - **Fix**: v0.1 must **only** deliver the parser and fixture. No checks. The gate is TSC-01 (100% parser tests pass).
- **No gate for absence model validation**: The absence-based checks (FR-08) require a correct default model. There is no test for this.
  - **Fix**: Add a test that verifies the tool’s default model against ASA 9.x documentation (e.g., confirm `logging enable` is off by default).
- **No gate for secret masking**: SR-04 implies masking but does not require it.
  - **Fix**: Add a requirement that **all secrets in output must be masked** (e.g., `snmp-server community [REDACTED]`).

### Proposed Gates
| Milestone | Gate | Evidence |
|-----------|------|----------|
| v0.1 | Parser correctness (TSC-01) | 100% parser unit tests pass on fixture. |
| v0.2 | Presence-based checks (TSC-02/03) | 100% true positives, 0 false positives on seeded fixture. |
| v0.3 | Absence-based checks (TSC-04) | All absence checks pass true-pos/true-neg. |
| v0.3 | Secret classification (TSC-05) | 100% correct classification on seeded lines. |
| v0.4 | Full MVP (TSC-02/03/06/07) | All MVP checks pass, evidence cites correct lines. |
| All | Offline/read-only (TSC-11) | Process monitor shows 0 connections; input hash unchanged. |

---
---
## Design Risks That Need Better Framing

1. **Parser as a Single Point of Failure**:
   - The entire project depends on the parser’s correctness. If it misparses a block, all checks are invalid.
   - **Mitigation**: The fixture must cover **all** gotchas in CHECK_CATALOG B5. The parser must be unit-tested exhaustively.

2. **PowerShell 5.1 Limitations**:
   - PowerShell 5.1 has weaker regex support (no `\K` or atomic groups) and slower performance than 7+.
   - **Mitigation**: Avoid advanced regex features. Use simple patterns and compiled regex.

3. **Fixture Overfitting**:
   - The tool may be tuned to the fixture and fail on real configs.
   - **Mitigation**: Use **multiple fixtures** (TR-05) and include edge cases from real sanitized configs.

4. **Authority ID Drift**:
   - CIS/STIG IDs may change between revisions, breaking the catalog.
   - **Mitigation**: Treat IDs as advisory metadata. The PASS/FAIL patterns are the source of truth.

---
---
## Recommendations by Priority

### P0 (Fix Before Coding)
1. **Cut v0.1 to parser-only**:
   - v0.1 must **only** deliver:
     - Indentation-stack parser (FR-02).
     - Repeated-prefix index (FR-03).
     - `name` symbol table (FR-04).
     - A fixture covering CHECK_CATALOG B5 gotchas.
     - Parser unit tests (TR-01/03).
   - **No checks, no output formatting, no object resolution.**
   - **Rationale**: The parser is the load-bearing component. All else depends on it.

2. **Add explicit parser validation gate**:
   - v0.1 success = TSC-01 (100% parser tests pass on fixture).
   - **No checks may be implemented until this gate is met.**

3. **Clarify absence-based check model**:
   - Document the **ASA 9.x default model** (e.g., `logging enable` = off, `ssh version` = v1 negotiable).
   - Add a test to validate this model against ASA documentation.
   - **Defer absence-based checks to v0.3.**

4. **Add secret masking requirement**:
   - Update SR-04: "The tool MUST mask all secrets (e.g., passwords, keys, communities) in output files and console output."
   - Implement masking in v0.2 (for presence-based secret checks).

5. **Explicitly forbid dynamic code execution**:
   - Add to AR-02: "The parser MUST use pure text processing. No `Invoke-Expression`, no dynamic code generation."

### P1 (Address in v0.1 Design)
6. **Define the fixture scope**:
   - The fixture must include:
     - 2–3 deep nesting (`group-policy` → `webvpn` → `anyconnect`).
     - Repeated-prefix families (`access-list`, `crypto map`, `name`).
     - Multi-line banners.
     - Both NAT shapes (indented object-NAT vs. flat twice-NAT).
     - Both `webvpn` contexts (global vs. group-policy).
     - All password hash types (`pbkdf2`, `encrypted`, `nt-encrypted`, cleartext).
     - Cleartext secrets (`snmp-server community`, `aaa-server key`, etc.).
   - **Source**: Combine multiple real sanitized configs (e.g., HussainYaqoob/SFC-Project) and add synthetic edge cases.

7. **Define the parser data structures**:
   - Use the model from `20260624_asa-config-analysis_RESEARCH.md` §5:
     - Indentation tree: `{ lineNo, raw, indent, text, parent, children[] }`.
     - Repeated-prefix index: hash maps for ACLs, crypto maps, `name`, tunnel-groups, banners.
   - **Do not** use flat line arrays. The hierarchical model is non-negotiable.

8. **Define the check catalog schema**:
   - Each check must include:
     - `id`: Unique identifier.
     - `category`: Management, AAA, Logging, etc.
     - `severity`: High/Medium/Low.
     - `authority`: CIS/STIG ID (marked verified/unverified) or "tool heuristic".
     - `pass_pattern`: Regex or absence marker.
     - `fail_pattern`: Regex or presence marker.
     - `default_if_absent`: What to assume if the line is missing.
     - `rationale`: Human-readable explanation.
     - `remediation`: How to fix.
   - **Defer absence-based checks to v0.3.**

### P2 (Address in v0.2)
9. **Implement presence-based checks first**:
   - Start with:
     1. `telnet` present (A1).
     2. `permit ip any any` in ACLs (A4).
     3. Cleartext secrets (A2/A5).
     4. `console timeout 0` or >5 (A1).
     5. SNMP v1/v2c community (A3).
   - These are high-signal, low-ambiguity, and do not require absence reasoning.

10. **Add output masking for secrets**:
    - Replace secrets in evidence with `[REDACTED]` or similar.
    - Apply to Markdown and CSV output.

### P3 (Address in v0.3+)
11. **Add absence-based checks**:
    - Start with:
      1. `logging enable` absent (A3).
      2. `ssh version 2` absent (A1).
      3. `ip verify reverse-path` absent (A6).
      4. `banner` absent (A2).
    - Validate the default model against ASA 9.x docs.

12. **Add object resolution**:
    - Implement FR-05 (resolve `object`, `object-group`, `group-object`).
    - Enable undefined-reference checks (A4 heuristics).

13. **Add second fixture**:
    - Use an independently authored sanitized config (TR-05) to guard against overfitting.

---
---
## Documentation and Process Improvements

1. **Add a formal threat model**:
   - Document the tool’s trust boundaries, input assumptions, and attack surface.
   - Include STRIDE analysis for the tool itself (e.g., tampering with output files, information disclosure via logs).

2. **Add a parser specification**:
   - Formalize the parser’s behavior for each construct in CHECK_CATALOG B.
   - Include examples of correct/incorrect parsing for edge cases.

3. **Add a data dictionary for the check catalog**:
   - Define the schema for checks (as in P1 #8) and document each field.

4. **Add a testing strategy**:
   - Document how fixtures are built, how tests are structured, and how regression is prevented.
   - Include a process for adding new checks (e.g., "add to catalog, add test cases to fixture, run tests").

5. **Add a release checklist**:
   - Include:
     - Parser tests pass.
     - Check tests pass (true positives/false positives).
     - Fixture covers all gotchas.
     - Output masking works.
     - No network calls or file mutations.

---
---
## Bottom Line

The core idea is worth building: a PowerShell-based, offline ASA config analyzer fills a real gap and the approach is sound. However, the **first milestone is over-scoped and mis-sequenced**. The project must **ship a parser-only v0.1** that proves it can correctly model ASA syntax (indented blocks, repeated-prefix families, nesting, secrets) against a comprehensive fixture. No checks should be implemented until this parser is validated. The highest risks are parser correctness and the absence-based check model; both must be derisked early. If the team starts coding checks before the parser is proven, the project will sink under the weight of false positives/negatives from a flawed foundation. The consequence of proceeding with the current v0.1 scope is a tool that looks complete but cannot be trusted on real configs.