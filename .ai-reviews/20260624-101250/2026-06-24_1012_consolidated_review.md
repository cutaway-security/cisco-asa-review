# cisco-asa-review: Consolidated Multi-AI Architecture Review (Pass 2 — Architecture)

- Synthesized by: Claude (referee across the reviews below)
- Reviewers: anthropic (claude-opus-4-8), mistral (mistral-medium-latest), openai (gpt-5.4) — 3/3 succeeded (OpenAI key fixed between passes).
- Date: 2026-06-24
- Material reviewed: 8 files, ~24k tokens, repo docs-only. Scope: ARCHITECTURE.md (under review) + the full bundle for grounding.

## Bottom Line

All three models independently affirm the architecture: concept sound, parser-first sequencing correct, two-index parse the right model, and the **first-pass fixes all landed well** (v0.1a/v0.1b split, default-on masking, minimal-resolution carve-out, determinism, staged gate). The review has moved one layer deeper. The new high-confidence consensus: (1) **v0.1a is still over-scoped** — defaults model and password classification are evaluator work, not parser-proof work, and should not share the parser gate; (2) **the defaults model and the interface-trust model are load-bearing but have no content and no source-of-truth discipline** — they are "second oracle" problems hiding behind the parser oracle; (3) **the TR-07 real-config oracle is unsecured and gates everything**, and the "fetch at dev time" idea contradicts the offline posture; (4) **secret masking is only as good as secret detection** — a missed construct leaks silently and inverts the confidentiality promise, so it needs a hard gate; (5) several **claims and gates outrun the fixture-bound evidence** and need tightening. None is fatal. All are doc-level fixes to apply before coding. The architecture is close — these are the refinements that make the first milestone actually provable.

## Validated Contradictions and Feasibility Problems

Ordered by severity; consensus noted.

1. **Defaults model and interface-trust model are load-bearing but undefined. [ALL THREE — CRITICAL]**
   A large fraction of the MVP-15 (logging-enable absent, ssh-version missing, no-service-password-recovery, NTP-without-auth, missing banner, uRPF) depend on (a) an ASA 9.x **defaults model** and (b) an **interface-trust/role model** (uRPF absence is a finding only on an untrusted interface). Both are asserted but have no content and no source-of-truth. anthropic's sharpest point: a defaults model "tested against a fixture the same team wrote has the same circularity as the parser oracle."
   *Resolution:* (i) Create `data/asa-defaults.psd1` scoped to exactly the MVP-15 absence checks, where **each default carries a Cisco ASA 9.x doc citation** the way checks carry authority IDs — not just a test. (ii) Design a **single shared interface-role model** (map `nameif` + `security-level` per interface) consumed by all interface-context checks, with the rule formalized: *uRPF absence is a finding if `security-level == 0` OR `nameif == outside`*. (iii) Build both alongside v0.1b checks, not in the v0.1a parser core.

2. **TR-07 real-config oracle is unsecured and contradicts the offline posture. [anthropic + openai CRITICAL; mistral HIGH]**
   The whole "parser works on real device output" claim rests on TR-07 (parse two real sanitized configs), but those configs are not yet obtained and OQ-3 proposes "fetch at dev time," which contradicts SR-01/OP-03 (air-gapped, no network) and makes the gate non-reproducible. If TR-07 can't be satisfied, v0.1a has no real gate.
   *Resolution:* Obtain sanitized configs and **store them locally as a one-time manual step (or commit if licensing permits) — never dev-time network fetch**. Define a **fallback gate** if two committable configs genuinely can't be had (e.g., N independently-authored fixtures by a second person, explicitly labeled a weaker oracle in release notes). And define TR-07 operationally: what "clean parse," "unparsed," and "misassigned" mean — **unknown-but-preserved lines (generic nodes) are acceptable if they don't corrupt structure** (openai). The current "no unparsed or misassigned lines" is too absolute given the B6 lower-confidence branches.

3. **v0.1a still over-scoped; defaults model + classifier mis-placed in the sequence. [anthropic + openai — HIGH; mistral dissents]**
   v0.1a bundles reader + parser + minimal resolution + password classification + defaults model. The defaults model and classifier are check-enablement, not parser-proof, and have different failure modes (a classifier bug is not a tree bug) — folding them into the v0.1a gate makes it pass/fail on the wrong axis.
   *Resolution (adjudicated):* **v0.1a-core = reader + indentation tree + repeated-prefix index + `name` map + verbose dump**, gated on TR-03 + TR-07. Minimal resolution, password classification, and the defaults model move to **v0.1b preparation** (built before the checks that consume them). *Mistral dissents* — it wants the defaults model in v0.1a because absence checks depend on it. I reconcile: mistral's dependency point is right (defaults model must exist before v0.1b checks), but that does not require it in the *parser* gate. Build it in v0.1b prep, gate it separately (doc-cited audit), and the dependency is satisfied without contaminating the parser milestone.

4. **Secret masking is only as good as secret detection — silent-leak failure mode. [anthropic HIGH; mistral + openai concur]**
   Default-on masking can only mask what it identifies. A version-token-drift variant or an unparsed B6 construct leaks its secret verbatim into the CSV, and the analyst trusts the output is clean. This silently inverts the tool's confidentiality promise — the most dangerous failure mode in the tool.
   *Resolution:* (i) A **conservative fallback mask**: redact any line matching a broad secret-keyword pattern (`community`, `key`, `pre-shared-key`, `password`, `snmp-server ... v3 ... priv/auth`) even when the specific construct isn't fully parsed. (ii) Apply masking to **verbose/debug output too** (openai). (iii) Add a **hard gate**: no seeded secret token from the fixture appears verbatim in default-masked output (Markdown, CSV, or verbose).

5. **Validation/efficacy claims outrun the evidence base. [openai CRITICAL; anthropic concurs]**
   VISION §7 ("reproduces findings an expert reviewer would produce by hand, with fewer misses and a documented false-positive rate") and broad "any ASA 9.x engagement" reuse (BSC-05) assert expert-equivalence and generalization that fixture-bound validation cannot support.
   *Resolution:* Weaken VISION §7 to what the planned evidence proves (parser handles real configs; checks correct on the fixture), and separate **target-device scope** ("initially validated on ASA 5515-X era 9.x syntax") from **product ambition** (broader ASA 9.x), per openai's HIGH input-scope finding.

6. **`permit ip any any` false-NEGATIVE risk from circular resolution scope. [anthropic HIGH]**
   FR-05a defines minimal resolution as "enough for the MVP checks," which is circular: the check needs resolution to be correct, and resolution scope is defined by the check. A deeply-nested object-group named `ANY` is silently missed, and the zero-FP gate can't catch under-flagging the fixture author didn't anticipate.
   *Resolution:* State the exact object-group nesting depth the MVP check is valid for (e.g., one level of expansion, no recursive `group-object`); mark deeper structures **"not assessed" (OR-03)** rather than silently passing.

7. **SR-07 resource bounds have no thresholds. [ALL THREE]**
   "Max file-size guard" with no number invites drift; only file size is specified, not per-line length or nesting depth.
   *Resolution:* Concrete bounds — e.g., max file size (~10 MB), max line length (~4 KB), max nesting depth (~10). Graceful fail past each.

8. **Gate/claim inconsistencies. [anthropic + openai MEDIUM]**
   - TSC-09: prose says "identical finding set," the §3 table row still says "byte-identical." Reconcile to the prose (finding-set is the gate; byte-identity the implementation target). *(mistral prefers byte-identical; I keep finding-set per the other two — byte-identity is too brittle a release gate.)*
   - TSC-04: "all absence checks in CHECK_CATALOG" vs the defaults model scoped only to MVP-15. Pin TSC-04 to the MVP-15 absence set for v0.1b.
   - NFR-04 / TSC-10 (20k-line): demote from v0.1 gate to non-blocking v0.2 benchmark (the target is one 5515 config).
   - BSC-01 ("under 5 min") and TSC-06 (manual spot-check): demote BSC-01 to a product goal, and machine-assert TSC-06 on seeded cases with only a manual release sample.

## Concept and Scope: Synthesized View

Build it — unanimous. Reconciled tiers:

- **v0.1a-core** — reader + indentation tree + repeated-prefix index + `name` map + verbose dump. Gate: TR-03 structural tests + TR-07 real-config clean parse (operationally defined).
- **v0.1b** — defaults model (doc-cited) + interface-role model + minimal resolution + password classifier + MVP-15 checks (presence + context-conditional absence) + Markdown/CSV + default masking + secret-leak gate. Gate: exact seeded TP / zero FP + secret-masking gate.
- **v0.2** — full catalog, deep resolution, undefined-ref/unbound-ACL heuristics, second independent fixture, version/EoL, 20k-line benchmark.
- **v0.3** — shadowing/redundancy, performance hardening, suppression/baselines.

Keep the MVP-15 as the v0.1b target; openai's "cut to 8–10 deterministic" is a schedule-pressure fallback, not a default — record the deterministic subset as the must-have core.

## Critical Path and Leverage

Unanimous: the parser is the load-bearing component, but its **oracle** (TR-07 real configs) is the deepest risk — effort spent securing two real sanitized configs moves the outcome more than any code. Second-order: the **defaults model and interface-role model** need doc-cited content, not just tests, or they become second oracle-circularity problems. These two shared models are small but consumed by many checks — design each once.

## Contested or Single-Reviewer Findings

- **Defaults model in v0.1a (mistral) vs v0.1b prep (anthropic/openai).** Adjudicated above: v0.1b prep with a separate doc-cited gate satisfies the dependency without contaminating the parser milestone.
- **Byte-identical cross-runtime gate (mistral) vs finding-set (anthropic/openai).** Kept finding-set as gate.
- **Per-check confidence + dependency metadata (openai only).** Adopt — add `confidence` (deterministic / context-sensitive / heuristic) and `dependency` (raw / resolved / defaults / interface-role) to the catalog schema. Cheap, and makes failures diagnosable.
- **`.psd1` load API (anthropic only).** Adopt — state catalog/defaults are loaded with `Import-PowerShellDataFile` (data-only), never dot-sourced or `Invoke-Expression`'d (a dot-sourced `.psd1` is a code-exec vector).
- **`-RevealSecrets` + CSV-to-disk footgun (anthropic).** Adopt — a loud status-stream warning naming the output file as credential-bearing when reveal is set.

## Where the Reviewers Were Wrong or Shallow

- **No hallucinations across all three.** Every cited doc, requirement ID, and section exists. Clean pass.
- **mistral's "max nesting depth 10 / file size 10MB / line 4KB" numbers are illustrative,** not sourced — treat as starting points to validate against real configs, not gospel.
- **openai's push to cut to 8–10 checks** slightly under-weights that the MVP-15 are all single-line/near-zero-ambiguity by construction (RESEARCH §4); the marginal cost of the last five is low. Keep 15, with the deterministic subset as the floor.
- **All three under-pressed one item I'll add:** the **interface-role model is itself absence/default-sensitive** — an interface with no explicit `security-level` inherits a default (0 for a named interface unless set). The shared model must encode that default, or context-conditional checks misfire on configs that rely on defaults. Fold into the defaults-model doc-citation discipline.

## Security Posture: Merged View

Trust boundary correct and small (one untrusted input; no network; read-only; no dynamic eval; bounded input). Merged findings by severity:

1. **[High] Secret-masking silent-leak** — conservative fallback mask + hard gate + verbose coverage (consensus #4).
2. **[High] TR-07 oracle / offline contradiction** — local one-time storage, never dev-time fetch (consensus #2).
3. **[Medium] SR-07 concrete bounds** — file size, line length, nesting depth (consensus #7).
4. **[Medium] `-RevealSecrets` footgun** — loud warning, name the credential-bearing file (anthropic).
5. **[Low] `.psd1` safe-load API** — `Import-PowerShellDataFile` only (anthropic).
6. **[Low] Offline-guarantee precision** — the tool guarantees no egress *by the tool*; it cannot control the report after it is written. State that boundary.

## Efficacy, Performance, and Acceptance Gates

- **Efficacy is won where the tool infers, not matches:** absence-context (interface-role model), resolution-scope under-flagging (use OR-03 "not assessed" aggressively), and crypto token-drift (stay conservative). All three converge here.
- **Performance is correctly secondary.** NFR-07 (no `+=` growth, list accumulation) is the key PS-specific discipline; ensure compiled regex is actually realized (reused `[regex]::new(..., 'Compiled')`, not inline `-match` per line). Demote 20k-line to benchmark.
- **Gates are well-formed;** apply the reconciliations in consensus #8, add the secret-masking gate, define the TR-07 fallback, and pin TSC-04 scope.

## Priority-Ordered Remediation Plan

**P0 — apply to docs before coding:**
1. Add the **defaults model** as doc-cited content (`data/asa-defaults.psd1`, MVP-15 scope, Cisco citations per entry); build in v0.1b prep. (ARCH §5/§9/§14, new DR)
2. Add a **shared interface-role model** with the formalized uRPF/outside rule, encoding security-level defaults. (ARCH §5/§9, FR-08)
3. **Secure the TR-07 oracle** (local one-time storage, no dev-time fetch) + operational definitions + fallback gate. (TR-07, SUCCESS guard, OQ-3)
4. Add the **secret-masking hard gate** + conservative fallback mask + verbose coverage. (SR-04, new TSC/FR)
5. **Narrow v0.1a-core** to the structural parser; move defaults model + classifier + minimal resolution to v0.1b prep. (VISION §5, ARCH §14)
6. Add **concrete SR-07 bounds**. (SR-07)
7. **Weaken VISION §7** efficacy claims; separate target-device from product scope. (VISION §7, new scope note)

**P1 — during v0.1a/v0.1b design:**
8. Add per-check `confidence` + `dependency` metadata to the catalog schema; state `permit ip any any` valid nesting depth + OR-03 "not assessed." (DR-04, FR-05a, FR-07)
9. Reconcile TSC-09 table to prose; pin TSC-04 to MVP-15; demote NFR-04/TSC-10 to benchmark; demote BSC-01; machine-assert TSC-06. (SUCCESS_CRITERIA)
10. State `.psd1` load via `Import-PowerShellDataFile`; `-RevealSecrets` warning. (ARCH §8, SR-04/SR-06)

**P2 — process:**
11. ADRs for the irreversible decisions (parser model, data/code boundary, masking default, v0.1a/b split); one canonical milestone source-of-truth; a contradictions matrix; mark superseded DISCOVERY assumptions (single-stream → separated); naming consistency (`dod`). Fold into PLAN.

## Lessons captured (for VIBE_HISTORY)

- The first-pass fixes were validated by all three models — the second pass found no regressions, only the next layer of depth. The pipeline is working as intended.
- The recurring deep theme across both passes is **oracle circularity**: first the parser/fixture, now the defaults model and interface-role model. The mitigation is the same each time — an *external* source of truth (real configs for the parser; Cisco doc citations for the defaults), not just an internal test.
- The most dangerous newly-surfaced failure mode is **silent secret leakage** from masking-detection gaps — promoted to a hard gate because a security tool that leaks credentials in its own deliverable is worse than no tool.
