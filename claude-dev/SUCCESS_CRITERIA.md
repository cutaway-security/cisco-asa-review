# SUCCESS_CRITERIA.md — cisco-asa-review

**Date:** 2026-06-24 · **Status:** Draft (pre multi-AI validation)
Business and technical criteria, each measurable. Tied to evidence in §3.

---

## §1 Business success criteria

- **BSC-01** A Cutaway analyst can review an ASA config with this tool in **under
  5 minutes** end to end (run + read findings), versus a manual review measured
  in hours. *Measured:* timed dry run against the fixture by an analyst. **Product
  goal, not a release gate** — it mostly measures human reading time, not tool
  quality. (AI review 20260624-101250: openai — not a product gate.)
- **BSC-02** The tool produces a **client-ready deliverable** — a Markdown report
  with prioritized, evidence-backed findings and CIS/STIG references — that an
  analyst can hand to a client with light editing, not a rewrite. *Measured:*
  report sections map to a named Cutaway report template (objective bar). This is
  a **soft business goal**, tracked separately from the hard technical gates;
  "light editing" alone is a judgment call. (AI review 20260624-094932: anthropic
  — subjective criterion sitting beside hard gates.)
- **BSC-03** The review is **repeatable**: two analysts running the tool on the
  same config get identical findings. *Measured:* same-input diff = empty.
- **BSC-04** The tool runs in a **sensitive/air-gapped engagement** without
  violating the no-egress constraint, so it is usable on real client data.
  *Measured:* SR-01 verification (§3).
- **BSC-05** The tool becomes a **reusable Cutaway asset**: applicable to any ASA
  9.x engagement, not just this one device. *Measured:* runs correctly on the
  fixture plus at least one independently-sourced sanitized config.

## §2 Technical success criteria

- **TSC-01 (Parse correctness)** The parser reconstructs the correct parent/child
  hierarchy and repeated-prefix families for every construct in CHECK_CATALOG B.
  *Threshold:* 100% of TR-03 parser unit tests pass.
- **TSC-02 (Detection — true positives)** For each implemented check, the tool
  flags every known-bad instance in the fixture. *Threshold:* 100% of seeded
  true positives detected (no misses) for MVP checks.
- **TSC-03 (Detection — false positives)** The tool does not flag the known-good
  instances. *Threshold:* 0 false positives on seeded good instances; any
  unavoidable FP is documented with rationale.
- **TSC-04 (Absence detection)** Absence-based checks correctly flag missing
  required lines, driven by the doc-cited defaults model and (for
  context-conditional checks) the interface-role model. *Threshold:* all **MVP-15**
  absence checks pass true-pos/true-neg for v0.1b; the full absence set is gated
  in v0.2 as the catalog expands. (AI review 20260624-101250: anthropic+mistral —
  TSC-04 scope was ambiguous vs the MVP-15-scoped defaults model.)
- **TSC-05 (Secret classification)** Password/secret lines are correctly
  classified and cleartext/weak secrets flagged. *Threshold:* 100% correct on the
  fixture's seeded credential lines. For the lower-confidence `nt-encrypted`
  branch (B6), the gate is the security-relevant property — **classified as
  not-cleartext** — not exact subtype, until a confirmed real `nt-encrypted`
  example is obtained. (AI review 20260624-094932: anthropic+mistral — 100%
  exact-subtype gate conflicted with the [lower-confidence] flag.)
- **TSC-06 (Evidence integrity)** Every finding cites a correct line number and
  the matching raw line (or an explicit "absent"). *Threshold:* **machine-asserted**
  for all seeded fixture cases (evidence resolves to the actual config line);
  manual audit only on a release sample. (AI review 20260624-101250: openai —
  manual spot-check was too weak.)
- **TSC-12 (Secret non-leak)** No seeded secret token from the fixture appears
  verbatim in default-masked output (Markdown, CSV, **or the visualization
  output**). *Threshold:* hard pass/fail; any verbatim secret is a release
  blocker. (AI review 20260624-101250: anthropic HIGH — TR-08.)
- **TSC-13 (Visualization correctness, Phase 5)** From the fixtures, the zone
  model and inter-zone flows derive correctly, and the `permit ip any any` risk is
  highlighted (red edge / darkest cell, labeled with the ACL line) on the insecure
  fixture and absent on the hardened fixture. *Threshold:* the insecure
  visualization contains the outside→inside ANY/ANY risk edge and matrix cell;
  the hardened one contains none; Mermaid + matrix are well-formed and
  deterministic across runs; no online renderer is invoked (static guard extends).
  *Status:* **MET (2026-06-24)** — `tests/unit/Segmentation.Tests.ps1`, 14 tests;
  catches both literal and object-group-expressed ANY/ANY; suite 89/89 green.
- **TSC-15 (Hygiene checks, Phase 6 / issue #1)** On the fixtures, the tool
  correctly flags: an unused (unreferenced-anywhere) ACL; an unused object and an
  unused object-group; an `inactive` ACE and an expired-`time-range` ACE; an
  interface with no IP that is not shut down; and a BVI with no matching
  bridge-group — all as Informational, with **zero false positives** on the
  referenced/active/shutdown counterparts (in particular an ACL used only by a
  crypto map MUST NOT be flagged unused). *Threshold:* exact seeded TP / zero FP
  on the extended fixtures.
- **TSC-16 (CSV tracking, issue #1)** The CSV includes Informational rows and the
  `RemediationState` (default Open) and `RemediationNotes` columns; the schema is
  stable and parses cleanly. *Threshold:* asserted by test.
- **TSC-17 (HTML full report, issue #1)** The HTML contains the full findings
  detail with ALL evidence lines per finding (not just the first), rendered
  natively; the standalone segmentation Markdown is no longer produced.
  *Threshold:* HTML contains a finding's additional evidence lines; no
  `*_asa-segmentation_*.md` is written; rendering still visually verified.
- **TSC-14 (HTML deliverable, Phase 5b)** A single self-contained HTML report
  consolidates findings + topology + matrix; it opens in any browser with no
  install/internet, contains no JavaScript and no external references, the inline
  SVG is well-formed and renders realistically, ANY/ANY is highlighted, no secret
  leaks, and output is deterministic. *Threshold:* automated tests assert
  structure/no-JS/no-external-ref/no-leak/determinism; the SVG rendering is
  visually verified by rendering to an image (not asserted blind). *Status:*
  **MET (2026-06-24)** — `tests/unit/HtmlReport.Tests.ps1`, 9 tests; rendered via
  WebKit (wkhtmltoimage) and inspected; PDF path confirmed (wkhtmltopdf); 98/98
  green.
- **TSC-07 (Authority traceability)** Every finding carries a CIS/STIG reference
  or "tool heuristic," with revision label, and remains valid on evidence alone.
  *Threshold:* manual audit confirms no finding depends solely on an `[unverified]`
  ID.
- **TSC-08 (Output integrity)** Markdown and CSV are well-formed; CSV matches the
  DR-02 schema; filenames carry a timestamp. *Threshold:* CSV parses cleanly;
  Markdown renders; schema/timestamp asserted by test.
- **TSC-09 (Compatibility)** Equivalent results on Windows PowerShell 5.1 and
  PowerShell 7+. *Threshold:* the fixture run produces an **identical finding set
  with identical evidence** (same findings, ids, line numbers, evidence text)
  across both runtimes. Byte-identity is the implementation target enabled by
  NFR-06 determinism, but the gate is finding-set equivalence, which is what the
  analyst relies on. (AI review 20260624-094932: anthropic HIGH — byte-identity
  was too brittle a proxy without the determinism requirements.)
- **TSC-10 (Performance)** A ~5,000-line config completes in < 10s (NFR-03, a
  release gate). The ~20,000-line no-quadratic-blowup target (NFR-04) is a
  **non-blocking v0.2 benchmark**, not a v0.1 gate — the engagement target is a
  single ASA 5515 config. (AI review 20260624-101250: anthropic+openai — 20k was
  premature as a gate.)
- **TSC-11 (Offline/read-only)** No network activity and no input mutation during
  a run. *Threshold:* SR-01/SR-02 verification (§3) shows zero connections and an
  unchanged input file hash.

## §3 Test plan (criterion → evidence)

| Criterion | Test | Data source | Threshold | Cadence |
|-----------|------|-------------|-----------|---------|
| TSC-01 | Parser unit tests (Pester) | Fixture + crafted snippets | 100% pass | Every change to parser |
| TSC-02/03 | Check true-pos/true-neg suite | Seeded fixture | 100% TP, 0 FP | Every check added |
| TSC-04 | Absence-check suite | Fixture minus required lines | All pass | Every check added |
| TSC-05 | Credential classification test | Seeded password/secret lines | 100% correct | Every change to classifier |
| TSC-06/07 | Evidence + authority audit | Generated report/CSV | All resolve; no ID-only finding | Per release |
| TSC-08 | Output schema/format test | Generated CSV + MD | Parses, schema, timestamp | Per release |
| TSC-09 | Cross-runtime run | Fixture | Identical finding set + evidence (byte-identity is impl target) | Per release |
| TSC-10 | Timed runs | 5k line fixture (20k = non-blocking benchmark, v0.2) | < 10s | Per release |
| TSC-11 | Egress + immutability check | Process monitor + input hash | 0 connections; hash unchanged | Per release |
| TSC-12 | Secret non-leak | Default-masked output vs seeded secrets | 0 verbatim secrets | Per release |
| BSC-01 | Timed analyst dry run | Fixture | < 5 min | Per release |
| BSC-03 | Repeatability diff | Two runs/analysts | Empty diff | Per release |
| BSC-05 | Independent-config run | 2nd sanitized config (TR-05) | Parses, plausible findings | v0.2+ |

## §4 What does NOT count as success

- A check that "looks correct" but has no passing true-positive AND true-negative
  fixture assertion. Untested is not done. (TR-06)
- "Tests pass" where the tests assert against stubbed parser output instead of a
  real parse of a real config-format fixture. Stub-based tests are wiring checks,
  not validation.
- A report that lists findings without config evidence, or whose evidence does
  not resolve to the cited line.
- A finding whose only justification is an authority ID — especially an
  `[unverified]` one — with no config evidence behind it. (SR-05)
- Any run that makes a network call, mutates the input, or writes config contents
  outside the analyst-specified output. (SR-01/02/03)

### Load-bearing guard (staged across milestones)

<!-- AI review 20260624-094932: anthropic+mistral — single guard staged into a parser gate and a check gate, which are different failure modes. -->

> **v0.1a parser gate.** The parser MUST reconstruct every construct in
> CHECK_CATALOG Part B correctly (100% of TR-03 parser unit tests) AND cleanly
> parse at least two independently-sourced real sanitized ASA configs (TR-07)
> with no unparsed or misassigned lines. "The parser works on real device
> output" is proven here, separately from check correctness.
>
> **v0.1b (and every later) check gate.** No iteration, MVP, or version is
> "shipped," "closed," or "complete" until the tool has performed a **real parse
> of a real ASA `running-config`-format fixture** and produced the **exact
> expected findings** (true positives) with **zero false positives** on the
> seeded good instances.
>
> Because no production ASA device or client config is available for development
> (DISCOVERY_NOTES OQ4), the syntactically faithful fixture plus the real
> sanitized configs together **are** the "real call returns data" gate — and this
> bound on validation confidence MUST be stated in every release note until a
> real engagement config has been run through the tool.
