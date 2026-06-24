# cisco-asa-review Architecture and Project Assessment

- Author: anthropic (claude-opus-4-8)
- Date: 2026-06-24 09:49
- Scope: background/goal.md, and the six claude-dev documents (RESEARCH, CHECK_CATALOG, DISCOVERY_NOTES, REQUIREMENTS, SUCCESS_CRITERIA, VISION)
- Repository state: documentation-only, no code present

## Executive Summary

The core idea is sound and worth building. An offline, read-only, PowerShell-native ASA misconfiguration linter fills a real and verified gap (the Posh-Cisco finding in RESEARCH §2 is the strongest single piece of evidence: no maintained offline PowerShell ASA checker exists). The problem is well-scoped, the constraints are honest, and the team has already done the unglamorous work that kills most projects of this type: they surveyed prior art, extracted a concrete check catalog with parsing gotchas, and named their validation gap out loud (OQ4, the no-real-config problem) instead of hiding it.

This is one of the better-prepared documentation sets I have reviewed. The thinking is disciplined. That said, my job is to find what sinks it, and there are three things that need attention before anyone writes code:

1. **The v0.1 milestone is mis-sized in one specific dimension: it bundles credential/secret classification and the full two-index parser with name resolution into "MVP," which is correct, but it ALSO defers object-group resolution (FR-05) to v0.2 while keeping checks in the MVP that depend on resolved references.** I detail the contradiction below. This is the load-bearing sequencing issue.

2. **The single greatest risk to the entire effort is the validation strategy, and the team knows it but has under-defended it.** The fixture IS the oracle. The fixture is hand-built by the same effort that builds the parser, from the same published-syntax sources the parser is built from. That is a closed loop: a parser and a fixture that agree with each other prove nothing about a real device's output. The "syntactically faithful fixture is the real-call gate" framing in SUCCESS_CRITERIA is honest but it papers over a circularity that needs an explicit independent check.

3. **The repeatability and cross-runtime success criteria (BSC-03, TSC-09) are stated as absolutes that the design cannot guarantee** without specific engineering commitments that are not yet in the requirements (ordering determinism, culture-invariant parsing, line-ending normalization in the hash/diff path).

None of these is fatal. All three are cheap to fix on paper now and expensive to discover in code later.

## What Validates Well

These are real strengths. Do not relitigate them while fixing the rest.

- **Prior-art survey is genuine and load-bearing, not decorative** (RESEARCH §2-3). The five-group taxonomy correctly separates parsers (ciscoconfparse2, ASA-ACL-toolkit) from check engines (nipper-ng findings model) from wrong-delivery-model tools (live auditors) from wrong-syntax tools (IOS auditors). The decision to port nipper-ng's *findings model* and ASA-ACL-toolkit's *shadowing logic* as shapes, not code, is exactly right given the GPLv3 license exposure of those sources against a tool Cutaway wants as a reusable asset.

- **The parser design is the correct model.** The parent/child indentation tree plus a separate repeated-prefix family index (RESEARCH §5, CHECK_CATALOG B2) is the right call, and the explicit recognition that `access-list`, `crypto map`, `name`, and `banner` are repeated-prefix families NOT indentation children (B5 gotcha 3) is the distinction that flat-regex tools get wrong. This is the single most important design insight in the whole set.

- **Reasoning over absence as a first-class case** (FR-08, B5 gotcha 7) is correctly identified as central. Most real ASA findings are missing lines. A team that did not understand this would build a tool that only flags positive-bad lines and silently passes the worst configs.

- **The authority-ID honesty discipline** (R1, OQ-A, SR-05, TSC-07) is mature. Treating CIS/STIG IDs as advisory labels validated by config evidence, never gating a finding on a possibly-misremembered V-ID, is precisely the right posture given that the IDs were partly read off third-party mirrors.

- **Evidence-per-finding** (Bet 4, FR-07, TSC-06) with retained line numbers is the right trust model and is nearly free given the parser retains raw text per node.

- **Scope discipline in "what this is not"** (VISION §6, OOS-01 through OOS-06) is clean. Excluding hitcount/rule-usage and dataplane reachability is correct and well-justified by the prior-art split.

## Scope and Sequencing

The phased arc (v0.1 foundation, v0.2 coverage, v0.3 depth) is the right shape. The MVP-15 shortlist (CHECK_CATALOG A8) is well-chosen: single-line, near-zero ambiguity, high real-world signal. I would ship roughly this arc. Three adjustments:

**Adjustment 1 (the real one): pull the dependency contradiction out of v0.1.** See the Critical Contradictions section. Either the MVP checks that need reference resolution move to v0.2, or minimal object/object-group resolution moves into v0.1. You cannot have FR-05 in [Scale] and `permit ip any any` quality checks plus undefined-reference heuristics implied in MVP.

**Adjustment 2: split the parser milestone from the check milestone inside v0.1.** Right now v0.1 is "parser + name/object resolution + 15 checks + Markdown + CSV + cross-runtime + performance." That is a lot for a first deliverable. Propose:

- **v0.1a (parser foundation):** indentation tree + repeated-prefix index + `name` resolution + password hash classification, proven against the fixture with TR-03 parser unit tests ONLY. No checks, no report. This derisks the load-bearing component in isolation. Output is the parsed model dumped for inspection (satisfies OR-04 verbose mode early).
- **v0.1b (MVP checks + output):** the 15 checks, Markdown + CSV, run summary. Built on a parser that is already proven.

This matters because if the parser is wrong, every check built on it is wrong, and you want to find parser defects against parser tests, not against confusing check failures.

**Adjustment 3: move FIPS/DoD-specific checks out of the MVP framing entirely.** The catalog mixes CIS baseline checks with DoD-STIG-specific items (FIPS mode A1, DoD Notice banner text A2 V-239902, split-tunnel tunnelall A5 V-239982, VPN banner A5 V-239970). These are not universally applicable findings; flagging "FIPS not enabled" or "banner is not the exact DoD text" against a commercial enterprise ASA produces noise. The MVP-15 correctly avoids most of these, but make the DoD-vs-commercial profile distinction explicit as a requirement now, before the catalog hardcodes DoD assumptions. This is a profile/policy decision, not a v0.2 detail.

## Critical Path and Leverage

The load-bearing component is unambiguous: **the two-pass parser and its resolution layer.** Everything downstream (every check, every finding, every piece of evidence) consumes the parsed model. If the indent-stack tree mishandles the 2-3 deep nesting (group-policy attributes -> webvpn -> anyconnect) or the repeated-prefix grouping misassigns lines, every dependent check inherits the defect.

The plan partially derisks this first (v0.1 leads with the parser) but does not isolate it (the parser ships in the same milestone as the checks). Adjustment 2 above fixes that.

The second-order leverage point is the **`name` resolution and password-hash classification** logic (FR-04, FR-09, B3). These are small, self-contained, and high-consequence: a misclassified hash type is a false negative on a credential, the highest-severity miss this tool can make. They deserve dedicated unit coverage independent of any check (TR-03 already calls for this; honor it as a gate, not a checkbox).

Where effort does NOT move the outcome at this stage: performance tuning (NFR-04, 20k-line configs). Real ASA running-configs are rarely that large, and you have no real config to benchmark against anyway. Keep the parser non-quadratic by construction (the indent stack already is) and defer 20k-line work to v0.3 as the arc already does. Do not spend v0.1 cycles here.

## Critical Contradictions and Feasibility Problems

**CRITICAL — Object-group resolution is deferred to v0.2 but MVP checks depend on it.** FR-05 (resolve `object`, `object-group`, nested `group-object` recursively) is tagged **[Scale]** (v0.2). But the MVP check set includes `permit ip any any` detection (A4, A8) and the RESEARCH §3 / §6 design states the two-pass resolution layer is "mandatory, not optional, to support object/ACL hygiene checks and to avoid false positives from unresolved references." An ACE written as `access-list OUT extended permit ip object-group ANY-NET object-group ANY-NET` is functionally `permit ip any any` only after the object-group is resolved. Without FR-05, the MVP `permit ip any any` check sees only the literal `any any` form and misses the object-group-expressed equivalent, OR produces false positives/negatives on object-referenced ACEs.
  - **Sources in conflict:** REQUIREMENTS FR-05 [Scale] vs FR-11 [MVP] (MVP-15) vs RESEARCH §6 item 2 ("two-pass parse + resolution layer is mandatory, not optional"). RESEARCH is right; the requirement tagging is wrong.
  - **Resolution:** Move *minimal* object/object-group/name resolution into MVP (enough to expand references that appear in the MVP-15 checks), and keep only the deeper recursive `group-object` nesting and unused-object hygiene in [Scale]. State explicitly which MVP checks operate on resolved vs raw text.

**HIGH — Repeatability (BSC-03) and cross-runtime byte-identity (TSC-09) are asserted as guarantees the design does not yet secure.** "Two analysts get identical findings" and "byte-identical output across PS 5.1 and PS 7+ modulo timestamp" require: deterministic finding ordering (hash-map iteration order differs across .NET versions and between PS 5.1 and 7), culture-invariant string/number parsing (PS 5.1 default culture can change how `console timeout 5` numeric comparisons or sorting behave), and consistent line-ending handling in any hashed/diffed output. None of these is a requirement yet.
  - **Sources:** SUCCESS_CRITERIA BSC-03, TSC-09; REQUIREMENTS NFR-01/02 (5.1 floor + 7+). The requirements do not mention determinism, culture-invariance, or ordering.
  - **Resolution:** Add explicit requirements: findings MUST be emitted in a deterministic, defined sort order (e.g., by check id then line number); all numeric/string comparisons MUST use InvariantCulture; output MUST normalize line endings. Without these, TSC-09 byte-identity will fail intermittently and unpredictably, which is worse than failing consistently.

**MEDIUM — The fixture-as-oracle circularity.** The validation gate (SUCCESS_CRITERIA Load-bearing guard) is "real parse of a real fixture produces exact expected findings." But the fixture is synthesized by the team (TR-01) from the same published-syntax sources (RESEARCH §5) used to design the parser, and the "expected findings" are authored by the same team. A parser and fixture built from the same mental model will agree with each other while both being wrong about what a real ASA actually emits.
  - **Sources:** SUCCESS_CRITERIA Load-bearing guard, TSC-02/03; TR-01/TR-05; RESEARCH OQ-D.
  - **Resolution:** This is partially mitigated already (TR-05 second independent fixture; BSC-05 independently-sourced sanitized config; RESEARCH references two real sanitized configs on GitHub: HQ-FW2.txt and ASABuzzNick). Make the *real sanitized config parse* a v0.1 gate, not a v0.2 nicety. You do not need to author expected findings for it; you need to prove the parser does not choke on real-device output (no unparsed lines, no misassigned blocks). That breaks the circularity cheaply. Right now BSC-05's independent-config run is cadenced "v0.2+," which leaves v0.1 validated entirely against self-authored material.

**LOW — Console logging severity inconsistency.** CHECK_CATALOG A3 lists "Console logging off" as Low severity with FAIL on `logging console` present, but the rationale (console logging can hang the device under load) is a real availability finding. Not a contradiction, just verify the severity against the authority rather than carrying it as Low by default.

**LOW — `nt-encrypted` confidence cascades into a success threshold.** TSC-05 demands "100% correct on the fixture's seeded credential lines, including the lower-confidence `nt-encrypted`/legacy branches (B6)." But B6 explicitly marks `nt-encrypted` value layout as `[lower confidence]`. Setting a 100% threshold on a branch you have flagged as low-confidence-on-syntax is internally tense: you cannot author a faithful fixture for a layout you are unsure of.
  - **Resolution:** Either downgrade the `nt-encrypted` threshold to "classified as not-cleartext" (the security-relevant property) rather than exact-type, or obtain a confirmed real example before gating on it.

## Security Findings

This is a security tool with a tight trust model, and the documents handle it well. The findings below are about residual gaps, not failures.

- **Trust boundary is correct and small.** Untrusted input is exactly one thing: the config text file (IR-01). No network, no device, no other integration (SR-01, IR-02). The attack surface is parser robustness against malformed/hostile input.

- **GAP — No requirement for parser robustness against adversarial or malformed input.** The config is described as sensitive client data, but a config file could also be malformed (truncated dump, mixed encodings, pathologically deep fake indentation, multi-gigabyte file). The requirements specify graceful handling of empty/non-ASA input (FR-17) but not resource-bounding against a hostile or corrupt file. A regex catastrophic-backtracking input or an unbounded-memory read of a huge file is a real DoS-of-the-analyst risk.
  - **Resolution:** Add a requirement bounding input handling: maximum file size guard, streaming or bounded read, and a note that all regex anchors must avoid catastrophic backtracking (the anchors in B4 look safe, but make it a stated constraint).

- **GOOD — Secret-masking is addressed but only as SHOULD.** SR-04 says the tool SHOULD support masking discovered secret values in output. For a tool whose entire output (Markdown + CSV) contains config evidence including cleartext secrets, secret values, and PSKs, this is the wrong strength. The CSV with evidence text is itself a secrets-bearing artifact. Recommend: masking of secret *values* in output MUST be the default, with an explicit opt-in flag to show them. Otherwise the tool's own deliverable becomes a credential-leak vector, contradicting DR-01's confidentiality posture.

- **Note — what the offline guarantee actually buys.** SR-01 (no network) is enforceable and verifiable (TSC-11 process-monitor check). Good. But be precise in the report language: "the config never leaves the host" depends on the analyst directing output to a safe location (SR-04) and not on any control the tool can enforce after it writes the file. The tool guarantees no egress *by the tool*; it cannot guarantee what happens to the report afterward. State that boundary so the deliverable's confidentiality claim is accurate.

## Efficacy

Will the tool detect what it claims? For the MVP-15, mostly yes, with these caveats:

- **The absence checks are where efficacy is won or lost.** Detecting "no `logging enable`" is trivial; detecting "no `ssh version 2`" correctly requires knowing the default (v1 negotiable) and that the line's absence is itself the finding. The design understands this (B5 gotcha 7). The efficacy risk is *over-flagging by absence*: some "absent" findings are only findings in certain contexts (e.g., uRPF absence matters on the outside interface, not on a management interface). A naive "is this global line absent?" check will over-report. Make context-conditional absence checks explicit where the catalog already implies them (uRPF "on untrusted," A6).

- **The `permit ip any any` check's real-world miss surface** is the object-group-expressed equivalent (covered above as the CRITICAL contradiction) and the `permit ip any any` that is *correctly* scoped by a preceding NAT or by interface security-levels. Static analysis will flag a literal any-any rule that may be operationally fine. That is acceptable for a linter (analyst adjudicates), but the remediation text should frame it as "review," not "remove," to avoid the analyst handing a client a wrong recommendation.

- **Version/EoL (FR-15) is correctly de-risked** by the maintained local table approach and graceful degradation when the version line is absent (OQ-B). Efficacy here is bounded by table freshness, which DR-05's source/revision-date requirement makes visible. Good.

- **The strongest efficacy bet (Bet 1: offline static analysis covers the findings that matter) is sound** and well-defended. The honest "how wrong" (unused-rule questions need device data) is correctly scoped out.

## Performance and Cost

Not a v0.1 concern, and the documents mostly agree. The indent-stack parser is linear by construction; the repeated-prefix index is hash-based. The only genuine performance hazard is recursive object-group expansion (OQ-C correctly flags combinatorial blowup in shadowing analysis, deferred to v0.3). NFR-03 (<10s for 5k lines) is trivially achievable in PowerShell for linear parsing. NFR-04 (20k lines, no quadratic blowup) is the right *constraint* but the wrong *milestone* if it pulls effort into v0.1; keep it as a design invariant ("no quadratic passes") rather than a benchmarked gate until v0.3. The one watch item: building findings by repeated string concatenation or by `+=` array growth in PS 5.1 is accidentally quadratic; specify list-based accumulation.

## Acceptance Criteria and Gates

The success criteria are unusually well-formed: measurable, tied to evidence, with an explicit "what does NOT count as success" section that correctly rejects stub-based tests and ID-only findings. The Load-bearing guard is good discipline. Adjustments:

- **TSC-09 (byte-identical cross-runtime) is too strong as written** and depends on the determinism requirements that do not yet exist (see HIGH contradiction). Either add those requirements or soften the criterion to "identical set of findings with identical evidence," which is what actually matters to the analyst. Byte-identity is a brittle proxy for the real goal.

- **Stage the validation gate across milestones.** The single Load-bearing guard ("real parse of a real fixture, exact findings, zero FP") is correct but currently undifferentiated. Stage it: v0.1a gate = parser reconstructs every B-construct correctly (TR-03 100%) AND parses both real sanitized GitHub configs without unparsed/misassigned lines; v0.1b gate = MVP-15 produce exact seeded TP/TN on the fixture. This separates "the parser works on real input" from "the checks are correct," which are different failure modes.

- **BSC-02 (client-ready deliverable, light editing not rewrite) has no objective threshold.** "Light editing" is a judgment call. Either accept it as a soft business goal (fine) or define a concrete bar (e.g., report sections map 1:1 to a named Cutaway report template). Do not let a subjective criterion sit next to the hard technical gates as if it were equally measurable.

- **Publication/packaging is correctly absent from the technical gates.** Good. The criteria do not contaminate technical sign-off with delivery concerns.

## Design Risks That Need Better Framing

- **The "declarative catalog vs. structural code" boundary (Bet 3, AR-05, DR-04) is acknowledged as hybrid but not yet drawn.** This is the right instinct, but "the boundary MUST be explicit" is a promise, not a design. Before coding, produce the actual taxonomy: which of the ~80 checks are pure presence/absence/pattern (data) and which require structural logic (code). My estimate from the catalog: A1-A3 are almost entirely data-expressible; A4 access-control and A5 crypto have several that need resolution-aware code; the heuristics (undefined references, unbound ACLs, shadowing) are all code. Draw this line now or it will drift, and MR-01 ("add a simple check by editing data only") will quietly become false.

- **CHAPS convention inheritance (DISCOVERY Dependencies) is correctly scoped as pattern-not-content,** but the status-prefix output convention (`[+]/[-]/[*]/[$]/[x]`) plus the "Markdown report to stdout, user redirects" decision (FR-16, R2) needs a feasibility check against TSC-09 byte-identity: status-prefixed diagnostic output interleaved with the Markdown report stream can differ across runtimes. Keep diagnostic/status output on a separate stream (stderr or the information stream) from the Markdown report (stdout), so the report itself is clean and diff-able. The requirements do not currently separate these streams.

## Recommendations by Priority

**P0 — Fix before coding:**

1. **Resolve the object-group resolution contradiction.** Move minimal name/object/object-group resolution into v0.1 MVP, or move the resolution-dependent MVP checks to v0.2. State per-check whether it operates on resolved or raw text. (CRITICAL above.)

2. **Add determinism requirements** (sorted finding order, InvariantCulture comparisons, normalized line endings, separated output streams) before TSC-09/BSC-03 can be honest. Otherwise soften those criteria to "identical finding set" rather than byte-identity. (HIGH above.)

3. **Make masking of secret values the default**, not a SHOULD. The tool's own output is otherwise a credential-bearing artifact that contradicts the confidentiality posture. (Security finding above.)

4. **Promote "parse a real sanitized config without choking" to a v0.1 gate.** This is the cheapest available break of the fixture-as-oracle circularity, and two real configs are already in your reference list. (MEDIUM contradiction above.)

**P1 — Decide before v0.1b:**

5. Split v0.1 into v0.1a (parser proven in isolation) and v0.1b (checks + output). Derisk the load-bearing component before building breadth on it. (Scope Adjustment 2.)

6