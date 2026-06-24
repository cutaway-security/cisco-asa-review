# cisco-asa-review: Consolidated Multi-AI Architecture and Security Review

- Synthesized by: Claude (referee across the reviews below)
- Reviewers: anthropic (claude-opus-4-8), mistral (mistral-medium-latest). openai (gpt-5.4) FAILED — HTTP 401, invalid/stale API key in `/home/cutaway/.claude/keys/openai.key.txt`; refresh and re-run for a third independent voice.
- Date: 2026-06-24
- Material reviewed: 7 files, ~17.8k tokens, 0 secrets redacted, repo state docs-only (Phase 6 bundle: VISION, REQUIREMENTS, SUCCESS_CRITERIA + grounding docs).

## Bottom Line

Both reviewers independently land on **"worth building, concept sound, documentation unusually well-prepared"** — and both independently land on the same structural defect: **v0.1 is over-scoped and the load-bearing parser is not derisked in isolation before checks are built on it.** That is the high-confidence headline. The other strong consensus items: secret-value masking must be a default MUST (the tool's own CSV/Markdown output is otherwise a credential-leak artifact), and the fixture-as-oracle validation loop is circular and needs an independent break. One reviewer (anthropic) additionally caught a real internal contradiction: object-group resolution (FR-05) is deferred to v0.2 while MVP checks depend on it. None of the findings is fatal; all are cheap to fix on paper now. The bundle is **not yet ready to implement** — apply the P0 edits below first.

## Validated Contradictions and Feasibility Problems

High-confidence findings (both reviewers, or confirmed by me against the material). Ordered by severity.

1. **v0.1 over-scoped; parser not isolated from checks. [BOTH — high confidence]**
   v0.1 currently bundles parser + name/object resolution + 15 checks + secret classification + Markdown/CSV + cross-runtime + performance. Both reviewers call this a v0.2 wearing a v0.1 label. If the parser is wrong, every check inherits the defect, and parser defects surface as confusing check failures instead of clean parser-test failures.
   *Resolution (adjudicated):* Adopt anthropic's split — **v0.1a = parser foundation proven in isolation** (indentation tree + repeated-prefix index + `name`/minimal object resolution + password-hash classification), gated on parser unit tests AND a clean parse of a real sanitized config; **v0.1b = MVP-15 checks + Markdown/CSV** built on the proven parser. (I reject mistral's more aggressive 6-milestone cut that defers absence checks all the way to v0.3 — see Contested.)

2. **Object-group resolution deferred but MVP checks depend on it. [anthropic — confirmed by me]**
   FR-05 (resolve object/object-group/nested group-object) is tagged [Scale]=v0.2, but the MVP `permit ip any any` check and undefined-reference heuristics need resolution: an ACE written `permit ip object-group ANY object-group ANY` is functionally any-any only after expansion. RESEARCH §6 itself says the resolution layer is "mandatory, not optional." The requirement tag is wrong; RESEARCH is right.
   *Resolution:* Move **minimal** name/object/object-group resolution (enough for MVP-15 checks) into v0.1a; keep deep recursive `group-object` nesting and unused-object hygiene in [Scale]. State per check whether it operates on resolved or raw text.

3. **Repeatability (BSC-03) and byte-identical cross-runtime (TSC-09) asserted without the engineering to secure them. [anthropic — confirmed]**
   Hash-map iteration order differs across .NET/PS versions; default culture affects string/number handling; line endings differ. None is a requirement yet.
   *Resolution:* Add determinism requirements — deterministic finding sort order (check id, then line number), `InvariantCulture` for all comparisons/sorting, normalized line endings, and **separate the Markdown report stream (stdout) from status/diagnostic output (stderr/information stream)**. Then soften TSC-09 from byte-identity to **"identical finding set with identical evidence"**, which is the property that actually matters.

4. **Secret-value masking is a SHOULD; it must be a MUST/default. [BOTH — high confidence]**
   The tool's output (CSV with evidence text, Markdown) contains cleartext secrets, communities, and PSKs it discovers. As written (SR-04 SHOULD) the deliverable contradicts the DR-01 confidentiality posture.
   *Resolution:* Masking of discovered secret **values** is the **default MUST**, with an explicit opt-in flag to reveal. Applies to both output formats and any console echo.

5. **Fixture-as-oracle circularity. [BOTH — anthropic explicit, mistral as "fixture fidelity"]**
   The fixture is hand-built by the same effort, from the same published-syntax sources, that builds the parser; expected findings are authored by the same team. Parser and fixture can agree with each other while both being wrong about real-device output.
   *Resolution:* Promote **"parse both already-referenced real sanitized GitHub configs (HQ-FW2.txt, ASABuzzNick) without unparsed or misassigned lines"** to a **v0.1a gate** (no need to author expected findings for them — just prove the parser does not choke on real output). This is the cheapest available break of the loop. Add the independent second fixture (TR-05) in v0.1b/v0.2.

6. **`nt-encrypted` 100%-correct threshold conflicts with its own [lower-confidence] flag. [BOTH]**
   TSC-05 demands 100% correct classification including `nt-encrypted`, but CHECK_CATALOG B6 marks its value layout low-confidence. You cannot author a faithful fixture for a layout you are unsure of.
   *Resolution:* Gate on the **security-relevant property — "classified as not-cleartext"** — not exact subtype, until a confirmed real `nt-encrypted` example is obtained.

## Concept and Scope: Synthesized View

Both reviewers affirm the core thesis: an offline, read-only, PowerShell-native ASA misconfiguration linter fills a real, verified gap (no maintained equivalent exists; Posh-Cisco does collection only). Build it.

Reconciled tier plan (my referee call, blending both):

- **v0.1a — Parser foundation (derisk the load-bearing component).** Indentation tree + repeated-prefix index + `name` + minimal object/object-group resolution + password-hash classification. Gate: 100% parser unit tests (TR-03) AND clean parse of two real sanitized configs. No checks, no report (dump parsed model for inspection — satisfies OR-04 early).
- **v0.1b — MVP checks + output.** The MVP-15 (presence AND context-conditional absence), Markdown + CSV, run summary, secret masking. Gate: exact seeded TP / zero FP on the fixture.
- **v0.2 — Coverage.** Remaining CIS/STIG catalog, deep recursive resolution, undefined-reference / unbound-ACL heuristics, second independent fixture, version/EoL table.
- **v0.3 — Depth.** ACL shadowing/redundancy, performance hardening on large configs, baseline/suppression.

**New scope decision both surfaced indirectly — commercial-vs-DoD profile.** The user's context is an *enterprise* ASA. anthropic flags that FIPS-mode, exact-DoD-banner-text, and split-tunnel-tunnelall checks are STIG/DoD-specific and produce noise on a commercial device. Make a **profile distinction explicit now**: default **commercial profile** (CIS-weighted) vs an opt-in **DoD/STIG profile** that enables the DoD-specific items. Bake this into the catalog schema before checks hardcode DoD assumptions.

## Critical Path and Leverage

Unanimous: **the two-pass parser + resolution layer is the load-bearing component.** Everything downstream consumes the parsed model. The plan leads with the parser but did not *isolate* it; the v0.1a/v0.1b split fixes that. Second-order leverage: **`name` resolution and password-hash classification** — small, self-contained, high-consequence (a misclassified hash is the highest-severity miss the tool can make). Both deserve dedicated unit coverage independent of any check. Where effort does **not** pay off now: 20k-line performance tuning (no real config to benchmark; keep the parser non-quadratic by construction and defer the benchmark to v0.3).

## Contested or Single-Reviewer Findings

- **How hard to cut v0.1. [reviewers disagree]** Mistral cuts to parser-only across six milestones and defers *absence checks entirely to v0.3* and object resolution to v0.4. Anthropic keeps the MVP-15 in v0.1b with minimal resolution moved into MVP. **My call: anthropic.** Mistral's deferral of absence checks is too conservative — absence findings include some of the *highest-signal* checks (no `logging enable`, no `ssh version 2`) and are not hard once the ASA-defaults model is written (CHECK_CATALOG already documents the defaults). Keep absence checks in MVP, but require (a) an explicit ASA 9.x defaults model and (b) **context-conditional absence** (uRPF absence matters on the outside interface, not on a management interface) to avoid over-flagging.

- **No-dynamic-code-execution requirement. [mistral only — confirmed, adopt]** Forbid `Invoke-Expression` / dynamic code generation on config content in AR-02. Cheap, correct hardening for a tool that ingests untrusted text.

- **Input robustness / resource bounding. [anthropic only — confirmed, adopt]** No requirement bounds a malformed/hostile/huge input (truncated dump, mixed encodings, pathological indentation, multi-GB file, catastrophic-regex backtracking). Add a max-file-size guard, bounded read, compiled regex, and a stated "anchors must avoid catastrophic backtracking" constraint.

- **BSC-02 "client-ready, light editing" has no objective threshold. [anthropic only — valid]** Either accept it explicitly as a soft business goal or define it against a named Cutaway report template. Do not let a subjective bar sit beside the hard technical gates.

- **Console-logging severity. [anthropic LOW]** Minor; verify against authority rather than carrying Low by default. Non-blocking.

## Where the Reviewers Were Wrong or Shallow

- **No hallucinations in either review.** Every document, requirement ID, and catalog item cited by both reviewers exists in the material. This is a clean pass.
- **Mistral padded with process-doc recommendations** (threat-model doc, parser spec, data dictionary, release checklist, testing-strategy doc). These are reasonable but are documentation-process suggestions, not architecture findings; fold the *substantive* ones (catalog schema, ASA-defaults model spec) into ARCHITECTURE/PLAN and treat the rest as optional. Do not let them inflate the P0 list.
- **Both under-weighted one thing I'll add as referee:** neither pressed on **how findings get an analyst-adjudication affordance.** Static analysis will flag a literal `permit ip any any` that may be operationally fine (scoped by NAT/security-levels). Remediation text must frame such findings as **"review," not "remove,"** so the analyst does not hand a client a wrong recommendation. Capture this as a requirement on remediation wording.

## Security Posture: Merged View

Trust boundary is correct and small: exactly one untrusted input (the config file); no network, no device, no other integration. Merged findings by severity:

1. **[High] Secret masking must be default** (consensus #4 above).
2. **[Medium] Input robustness / no catastrophic backtracking / file-size bound** (anthropic).
3. **[Medium] No dynamic code execution on config content** (mistral).
4. **[Low/clarity] Offline guarantee scope.** SR-01 (no egress by the tool) is enforceable and verifiable. But "the config never leaves the host" depends on the analyst directing output to a safe location — the tool cannot control what happens to the report after it writes it. State that boundary precisely in the deliverable so the confidentiality claim is accurate.

## Efficacy, Performance, and Acceptance Gates

- **Efficacy is won or lost on absence checks** — implement them context-conditionally (above) to avoid over-reporting.
- **`permit ip any any` real-world miss surface** is the object-group-expressed equivalent (fixed by moving minimal resolution into MVP) and correctly-scoped any-any rules (handled by "review not remove" wording).
- **Performance** is not a v0.1 concern; the indent-stack parser is linear by construction and the index is hash-based. One concrete hazard both implicitly raised: avoid PS 5.1 accidental-quadratic patterns — no `+=` array growth or repeated string concatenation for findings/report; use list-based accumulation and compiled regex.
- **Acceptance gates** are unusually well-formed already (measurable, evidence-tied, with a real "what does NOT count" section). Two changes: **stage the single Load-bearing guard** into a v0.1a parser gate (parses real configs + 100% parser tests) and a v0.1b check gate (exact seeded TP/TN); and **soften TSC-09** to identical-finding-set (above).

## Priority-Ordered Remediation Plan

**P0 — apply to the docs before any code:**
1. Resolve the object-group contradiction: minimal resolution into v0.1a; per-check resolved-vs-raw note. (FR-05, FR-11, FR-13)
2. Add determinism requirements (sorted order, InvariantCulture, normalized line endings, separated output streams); soften TSC-09 to identical-finding-set. (new NFR/AR; BSC-03, TSC-09)
3. Make secret-value masking the default MUST with opt-in reveal. (SR-04)
4. Promote "parse two real sanitized configs without choking" to a v0.1a gate. (TR, SUCCESS_CRITERIA guard)
5. Split v0.1 into v0.1a (parser proven in isolation) and v0.1b (checks + output). (VISION arc, PLAN)
6. Add commercial-vs-DoD check profile as an explicit requirement + catalog field. (new FR/DR; CHECK_CATALOG schema)
7. Downgrade the `nt-encrypted` gate to "classified as not-cleartext." (TSC-05)

**P1 — decide during v0.1a design:**
8. Add no-dynamic-code-execution and input-resource-bounding security requirements. (AR-02, new SR)
9. Draw the declarative-catalog-vs-structural-code boundary explicitly; define the check-catalog data schema (id, category, severity, authority+verified flag, profile, pass/fail pattern, default-if-absent, rationale, remediation). (Bet 3, AR-05, DR-04)
10. Require context-conditional absence checks and "review not remove" remediation wording. (FR-08, FR-07)
11. Write the ASA 9.x defaults model as a named spec the absence checks consume.

**P2 — soft / process:**
12. Define BSC-02 against a Cutaway report template or mark it explicitly soft.
13. Refresh the OpenAI key and optionally re-run for a third voice; fold mistral's process-doc suggestions into PLAN where substantive.

## Lessons captured (for VIBE_HISTORY)

- Two independent models converged on the same load-bearing risk (parser isolation) and the same security gap (default secret masking) — high confidence, applied without further debate.
- The single most valuable single-reviewer catch was anthropic's object-group-resolution contradiction, which a scope-only reading missed.
- The fixture-as-oracle circularity is inherent to the no-device constraint; the mitigation (parse real sanitized configs as a structural gate) is now a hard v0.1a requirement, not a nicety.
