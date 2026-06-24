# cisco-asa-review Architecture and Project Assessment

- Author: anthropic (claude-opus-4-8)
- Date: 2026-06-24 10:12
- Scope: ARCHITECTURE.md, background/goal.md, 20260624_asa-config-analysis_RESEARCH.md, CHECK_CATALOG.md, DISCOVERY_NOTES.md, REQUIREMENTS.md, SUCCESS_CRITERIA.md, VISION.md
- Repository state: documentation-only, no implementation code detected

---

## Executive Summary

The concept is sound and worth building. The niche is real and well-evidenced: there is no maintained, open-source, offline, PowerShell-native ASA misconfiguration analyzer, and the research survey (RESEARCH §2) documents that gap credibly with named prior art and URLs. The core design insight, that a hierarchical parse plus a repeated-prefix index plus absence reasoning beats flat grep, is correct and is the actual reason the tool justifies its existence. This is not a project that needs to be talked out of itself.

The planning is unusually mature for a pre-code effort. It has already absorbed at least one prior multi-AI review pass and shows the scars honestly: the v0.1a/v0.1b split, the promotion of secret masking to a default MUST, the minimal-resolution carve-out, and the staged load-bearing gate are all the right moves and are traceable to specific findings. The team knows where its load-bearing risk is (the parser) and has sequenced to derisk it first. Credit where due: this is what good scoping looks like.

The milestone shape is approximately right but v0.1a is at the edge of over-scope, and the single most important unresolved risk is not in the design, it is in the validation oracle. The whole project rests on a fixture the team authors themselves, validated against two real configs the team does not yet have permission to commit and may not be able to obtain (OQ-3, OQ-D, TR-07). If TR-07 cannot be satisfied, the v0.1a gate is unprovable and the entire "the parser works on real device output" claim collapses to "the parser works on configs we wrote to match our own parser's assumptions." That circularity risk is named in the docs, which is good, but it is not resolved, and it is a P0 to resolve before coding because it determines whether the first milestone has a gate at all.

The main issues in priority order: (1) the TR-07 real-config dependency is unsecured and gates everything; (2) several absence checks and "permit ip any any" depend on semantic correctness that minimal resolution may not actually deliver, creating a false-positive risk the gate does not fully catch; (3) the defaults model is load-bearing for a large fraction of checks but is specified only as "a named, separately-tested spec" with no content and no source-of-truth discipline; (4) secret masking is specified as default-on but the masking detection itself is a parser-completeness problem that can silently leak.

---

## What Validates Well

These are load-bearing decisions that are correct. Do not relitigate them while fixing the rest.

- **Parser-first sequencing (ARCHITECTURE §1, §14; VISION §5).** Isolating and proving the parser in v0.1a before any check consumes it is exactly right for a system where one component corrupts everything downstream. This is the highest-value structural decision in the plan.
- **Two-index parse (ARCHITECTURE §2; CHECK_CATALOG B2).** The recognition that `access-list`, `crypto map`, `name`, `banner`, and flat `nat` are repeated-prefix flat families, NOT indentation children, is the correct and non-obvious insight. A naive tree would scatter exactly the constructs that carry the most findings. This is genuinely well thought through.
- **Absence as first-class (ARCHITECTURE §5; RESEARCH §5).** Correctly identifying that defaults are omitted from running-config and that the highest-signal findings are missing lines is the difference between a real tool and a grep wrapper.
- **Evidence-over-authority-ID (SR-05, VISION Bet 4, RESEARCH OQ-A).** Treating `[unverified]` CIS/STIG IDs as advisory labels and resting finding validity on config evidence is intellectually honest and defensible. This protects the deliverable against benchmark-number drift.
- **Secret masking default-on (ARCHITECTURE §6, SR-04).** Recognizing the tool's own CSV/Markdown output as a credential-bearing artifact is the right security posture. The reasoning that masking replaces the value but not the surrounding evidence line is correct.
- **Determinism for cross-runtime equivalence (ARCHITECTURE §7, NFR-06).** Catching that hash-map iteration order and culture differ across PS 5.1 and 7+ before it caused intermittent gate failures is a real save.
- **`.psd1` over here-strings for no-eval safety (OQ-2, SR-06).** Native parse with no dynamic evaluation is the correct call for a tool that ingests untrusted text.

---

## Scope and Sequencing

The v0.1a/v0.1b split is correct in principle. My concern is that v0.1a as written is still heavy, and the heaviness hides inside the word "minimal."

**v0.1a is carrying more than "just the parser."** Per ARCHITECTURE §14 and VISION §5, v0.1a includes: reader + indentation tree + repeated-prefix index + `name` resolution + minimal object/object-group resolution + password-hash classification + verbose dump + the defaults model. That is five distinct subsystems, two of which (minimal resolution, defaults model) have explicitly fuzzy boundaries (OQ-1, the "minimal vs deep" blur in §3). Password-hash classification (CHECK_CATALOG B3) is described as "the heart of credential checks" but it is arguably a check, not a parser concern, and it includes a `[lower confidence]` branch (`nt-encrypted`).

**Recommended tiering:**

- **v0.1a-core (the true load-bearing slice):** reader + indentation tree + repeated-prefix index + `name` map + verbose dump. Gate: TR-03 structural tests plus TR-07 two-real-config clean parse. This is the thing that, if wrong, sinks everything. Prove it in isolation.
- **v0.1a-resolve:** minimal object/object-group resolution. Gate it separately, because its correctness is harder to assert and its boundary is contested.
- **v0.1a-classify:** password-hash classification, with the `nt-encrypted` gate already correctly relaxed in TSC-05.

The cut I would make: do not let password-hash classification or minimal resolution share a gate with the structural parser. They have different failure modes (TSC-05 is a classifier problem, TSC-01 is a tree problem) and folding them together makes the v0.1a gate pass-or-fail on the wrong axis. The docs already split the *gate* (SUCCESS_CRITERIA load-bearing guard) into a parser gate and a check gate; extend that discipline one level deeper inside v0.1a.

**v0.1b is well-sized.** Fifteen high-signal single-line checks plus output is the right MVP. No notes other than the resolution dependency flagged below.

**The defaults model is mis-placed in the sequence.** It ships in v0.1a (§14) but it is a check-support artifact, not a parser artifact, and OQ-1 admits its scope is undefined. Scope it to exactly the MVP-15 absence checks and build it alongside v0.1b checks, not in the parser milestone. Building it in v0.1a invites over-building a defaults model for checks that do not exist yet.

---

## Critical Path and Leverage

The load-bearing component is correctly identified as the parser (ARCHITECTURE §1). The plan derisks it first. Good. But the parser is not the deepest risk; the parser's **oracle** is.

The critical path is: TR-07 real configs obtained and committable → parser proven against them → v0.1a gate passable → everything else. The entire downstream plan is gated on TR-07, and TR-07 depends on OQ-3, which is unresolved ("if licensing is unclear, reference them by URL and fetch at dev time"). Fetching at dev time contradicts SR-01/OP-03 (no network, air-gapped). You cannot have a gate that requires fetching configs over the network on a tool whose entire posture is offline-only. The configs must be obtained and committed (or obtained out-of-band and stored locally) before v0.1a can be gated. This is where effort moves the outcome more than any code.

Secondary leverage point: the **defaults model** is load-bearing for TSC-04 and a large fraction of the MVP-15 (`logging enable` absent, `ssh version` missing, `no service password-recovery` absent, NTP-without-auth, missing banner are all absence or default-conditional). A single misclassified default propagates to every absence check that consumes it (§5 admits this). It is currently specified only as "a named, separately-tested spec." That is a promise, not a design. See Design Risks.

---

## Critical Contradictions and Feasibility Problems

**[CRITICAL] TR-07 dev-time fetch contradicts the offline posture.** OQ-3 (ARCHITECTURE §15) proposes, if licensing is unclear, to "reference them by URL and fetch at dev time rather than committing." SR-01 (REQUIREMENTS §3) states the tool MUST NOT make any network connection of any kind, and OP-03/BSC-04 require air-gapped operation. The *tool* and the *test harness* are different processes, so this is not a runtime contradiction, but it is a process contradiction: the v0.1a gate (TR-07, the structural break of fixture circularity) would then depend on network fetch, which cannot run in the air-gapped environment the tool is built for, and makes the gate non-reproducible. Resolve by committing sanitized configs or storing them locally as a one-time manual step. Name which.

**[HIGH] "permit ip any any" detection depends on resolution that minimal resolution may not deliver.** ARCHITECTURE §3 correctly notes `permit ip object-group ANY object-group ANY` is functionally `permit ip any any` only after resolution (FR-05a). But FR-05a defines minimal resolution as "enough to expand the references that the MVP-15 checks evaluate," which is circular: the check needs resolution to be correct, and resolution scope is defined by what the check needs. If an object-group named `ANY` is itself defined via a nested `group-object` (deep resolution, deferred to v0.1b/v0.2 per FR-05b), the MVP check silently misses it or misfires. The TSC-03 zero-FP gate catches over-flagging on seeded good instances, but it cannot catch under-flagging caused by a real-world object-group structure the fixture author did not anticipate. This is a false-negative risk that the gate structurally cannot catch, because the fixture and the resolution scope are authored by the same hand. State explicitly which object-group nesting depths the MVP `permit ip any any` check is and is not valid for, and mark deeper structures as "not assessed" (OR-03) rather than silently passing.

**[MEDIUM] Defaults model completeness is undefined yet gates TSC-04.** OQ-1 admits "how many ASA defaults must be encoded" is open, with the resolution being "scope to the MVP-15 absence checks first." But TSC-04 (SUCCESS_CRITERIA §2) asserts the gate is "all absence checks in CHECK_CATALOG (logging, ssh version, uRPF, banner, threat-detection, etc.) pass." CHECK_CATALOG lists far more absence-conditional checks than the MVP-15. Either TSC-04 is scoped to MVP-15 absences (then say so) or the defaults model must be more complete than OQ-1 scopes it (then v0.1b over-builds). The two documents disagree on the size of the absence-check set the gate covers.

**[MEDIUM] "Identical finding set" vs "byte-identical" cross-runtime gate is stated two ways.** TSC-09 prose (SUCCESS_CRITERIA §2) carefully softens the gate to "identical finding set with identical evidence" with byte-identity as an implementation target. The test-plan table row for TSC-09 (§3) still says "Byte-identical (modulo timestamp)." The narrative fix did not propagate to the table. Pick one; the prose version is the correct one.

**[MEDIUM] uRPF context-conditional check needs interface trust classification that is not specified.** FR-08 and CHECK_CATALOG A6 require uRPF absence to be a finding "on the outside/untrusted interface, not on a management interface." Determining which interface is "untrusted" requires inference (security-level 0? nameif `outside`? a heuristic?). The docs assert the context-conditional rule exists but never specify how trust is determined. CHECK_CATALOG A6 lists "outside iface sec-level 0" as its own check, implying security-level is the signal, but a config can have a security-level-0 interface not named outside, or multiple low-security interfaces. This is an unspecified efficacy-critical heuristic.

**[LOW] Module layout shows `Get-AsaDefaults.ps1` in v0.1a but defaults content is undefined.** ARCHITECTURE §9 lists the file; §14 ships it in v0.1a; OQ-1 says its scope is unresolved. Consistent with the sequencing concern above; the file exists in the layout before its contents are scoped.

**[LOW] `asa-eol.psd1` is listed in the module layout (§9) tagged v0.2 but appears in the v0.1a-shipping `data/` directory diagram without a version marker in the tree itself.** Minor; the tree implies presence, the annotation defers it. Harmless but worth a comment in the file tree.

---

## Security Findings

The threat model is unusually clear for a pre-code project and is mostly correct. One untrusted input (the config text, IR-01), no network (SR-01), read-only (SR-02), no dynamic eval (SR-06), bounded input (SR-07). That is the right boundary and it is well drawn.

**[HIGH] Secret masking is only as good as secret detection, and detection is a parser-completeness problem.** SR-04 and ARCHITECTURE §6 make masking default-on, which is correct. But masking can only mask what it identifies as a secret. The secret surface (CHECK_CATALOG B3, FR-10) is: password hashes, `snmp-server community`, `aaa-server ... key`, `ntp authentication-key ... md5`, tunnel-group PSK. If the parser misses a secret-bearing construct (a version-token-drift variant, a lower-confidence branch B6, a construct not in the catalog), that secret appears unmasked in the CSV evidence. The default-on posture creates a false sense of safety: an analyst trusts the output is masked, hands it to a client, and a missed secret leaks. This is the most dangerous failure mode in the whole tool because it is silent and it inverts the tool's confidentiality promise. Mitigation to specify now: (a) a conservative default that masks any line matching a broad secret-keyword pattern even if the specific construct is not parsed, and (b) a test that asserts no known-secret token from the fixture appears verbatim in default-masked output. Add this as an explicit gate, not an aspiration.

**[MEDIUM] `-RevealSecrets` plus CSV-to-disk is an easy footgun.** SR-04 provides the opt-in reveal flag for "a trusted host." But the CSV is written to disk by default (DR-03, timestamped file). A reveal-secrets run writes cleartext credentials to a timestamped file that may outlive the analyst's attention and get swept into a report archive or a shared drive. The docs say "what happens to the report after it is written is the analyst's responsibility" (§8), which is true but thin. Recommend: when `-RevealSecrets` is set, require an explicit acknowledgment or at minimum emit a loud status-stream warning naming the output file as credential-bearing.

**[LOW] No integrity statement on the bundled catalog/EoL data.** The catalog (`check-catalog.psd1`) and EoL table are bundled data parsed at runtime. SR-06 forbids `Invoke-Expression`, and `.psd1` via `Import-PowerShellDataFile` is the safe parse path, but the docs should state explicitly that the catalog is loaded with `Import-PowerShellDataFile` (data-only, no script execution) and never with `Invoke-Expression` or dot-sourcing. A `.psd1` dot-sourced or invoked is a code-execution vector. Name the safe load API.

**[LOW] Regex catastrophic-backtracking guard is asserted but not designed.** SR-07 requires "regex anchors that avoid catastrophic backtracking (prefer compiled, simply-anchored patterns)." The B4 regex set is mostly well-anchored, but several patterns use `(.*)` / `(.+)` tails (banner text, aaa key child, PSK child). On a hostile multi-megabyte single line these are linear, not catastrophic, but combined with the absence of a per-line length bound (only a file-size guard is specified) a pathological single line could still stress the engine. Specify a per-line length cap alongside the file-size guard.

---

## Efficacy

The check catalog is strong and well-sourced. The efficacy risks are concentrated where the tool must infer rather than match.

- **False negatives from resolution scope (see HIGH above)** are the dominant efficacy risk for the access-control checks. A static tool that under-resolves silently passes bad configs. The OR-03 "not assessed" discipline is the right answer; apply it aggressively wherever resolution depth is uncertain rather than emitting a pass.
- **"permit ip any any" over-flagging is correctly anticipated** (FR-07 "review, not remove"). Good. A literal any-any can be legitimately scoped by NAT and security levels, and the docs handle this with review-framed remediation. This is the right call and protects against handing clients a wrong recommendation.
- **Context-conditional absence is the right idea but under-specified** (uRPF, see MEDIUM above). The efficacy of the entire absence-check category depends on getting the context heuristic right; an over-broad uRPF check that fires on management interfaces will train analysts to ignore it.
- **The fixture-as-oracle problem is the deepest efficacy bound.** The team authors the fixture and the parser. TSC-02/03 assert against seeded expectations. A check can be "100% TP, 0 FP" against a fixture and still be wrong on real configs if the fixture does not contain the construct that breaks it. TR-07 (two real configs) is the only structural break of this circularity, which is exactly why TR-07 being unsecured (CRITICAL above) is so dangerous: it is the one thing standing between "validated" and "validated against our own assumptions," and it is the one thing not yet obtained.

---

## Performance and Cost

Performance is correctly treated as a secondary concern at this stage, and the relevant levers are already named.

- **NFR-07 (no `+=` array growth, list-based accumulation) is the right call** and is the single most important PowerShell-specific performance discipline. PowerShell `+=` on arrays is O(n^2); on a 20k-line config this is the difference between sub-second and minutes. Good that it is a named requirement.
- **Two-index single-pass parse (B2) is the right structure** for the 10-second/5k-line target (NFR-03). The indent-stack approach is linear.
- **Compiled regex (§8, SR-07)** is appropriate. One note: in PS 5.1, ensure regex compilation is actually realized (e.g., `[regex]::new(pattern, 'Compiled')` reused, not a fresh `-match` per line with inline patterns), or the "compiled" claim is nominal. This is an implementation detail to flag for the code review, not a design defect.
- **The 20k-line target is v0.2 (NFR-04, Scale).** Correct to defer; the MVP target of 5k lines is realistic.

No cost concerns; the tool is offline and local.

---

## Acceptance Criteria and Gates

The gates are unusually well-formed. The staged load-bearing guard (SUCCESS_CRITERIA §4) splitting the parser gate from the check gate is exactly the right model and reflects real failure-mode separation. A few refinements:

- **BSC-02 ("client-ready deliverable, light editing") is correctly identified as soft** and tracked separately from hard gates. Good. Keep it out of technical sign-off entirely; it is a satisfaction metric, not a release gate.
- **TSC-09 table/prose mismatch** (MEDIUM above) must be reconciled.
- **TSC-04 scope ambiguity** (MEDIUM above) must be pinned to a specific absence-check set.
- **Add a secret-masking gate.** Per the HIGH security finding, add a hard gate: no seeded secret token appears verbatim in default-masked output. This is currently implied by SR-04 but not present as a measurable criterion in §2/§3.
- **The TR-07 gate needs a fallback definition.** If two committable real configs genuinely cannot be obtained, what is the gate? The docs must not leave this open, because an unresolvable gate is no gate. Define the fallback now (e.g., minimum N independently-authored fixtures by a second person, explicitly labeled as a weaker oracle in release notes).

---

## Design Risks That Need Better Framing

- **The defaults model is a spec promise, not a design.** ARCHITECTURE §5 says "the defaults model is a named, separately-tested spec, not scattered constants" and mitigates a wrong defaults model by testing it. But tested against what? A defaults model tested against a fixture the same team wrote has the same circularity as the parser oracle. The defaults model needs a source of truth (specific Cisco ASA 9.x documentation citations per default), not just a test. Each entry in `Get-AsaDefaults.ps1` should carry a doc citation the way checks carry authority IDs. Without this, the defaults model is a second oracle problem hiding behind the first.
- **The "minimal vs deep" resolution boundary is named as a risk but the mitigation is weak.** "Each check declares whether it reads resolved or raw text" (§3, FR-05a) makes the dependency *visible* but does not make the boundary *correct*. Visibility is necessary, not sufficient. Specify the exact resolution depth v0.1a guarantees (e.g., one level of object-group expansion, no recursive `group-object`) and have checks that need more depth declare themselves "not assessed" in v0.1a.
- **Interface trust classification (uRPF, no-SSH-on-outside, outside-sec-level-0) is used by multiple checks but never specified as a shared model.** Several checks need to know which interfaces are untrusted/outside. This is a small shared subsystem (probably: map nameif + security-level per interface) that should be designed once and consumed by all interface-context checks, not re-derived per check. Name it.
- **CHAPS convention inheritance is "pattern not template" (DISCOVERY) but the line is thin.** The docs are clear that CHAPS is a structural pattern, not a content source. Just confirm in the eventual code review that no CHAPS doc content or stale convention leaked in.

---

## Recommendations by Priority

**P0 (resolve before coding):**

1. **Secure the TR-07 oracle.** Obtain two independently-