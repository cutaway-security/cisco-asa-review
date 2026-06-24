# REQUIREMENTS.md — cisco-asa-review

**Date:** 2026-06-24 · **Status:** Draft (pre multi-AI validation)
Keywords per RFC 2119 (MUST / SHOULD / MAY). Scope tags: **[MVP]** (v0.1),
**[Scale]** (v0.2), **[vNext]** (v0.3+). Origins point to `DISCOVERY_NOTES.md`
(R1–R5), `20260624_asa-config-analysis_RESEARCH.md`, and `CHECK_CATALOG.md`.

---

## §0 Context & scope

cisco-asa-review is an offline, read-only PowerShell tool that parses a single
Cisco ASA 9.x `show running-config` text dump and reports security findings as
Markdown + CSV. MVP (v0.1) delivers the hierarchical parser, name/object
resolution, and the 15 high-signal checks. The full CIS/STIG catalog and
structural analysis follow in v0.2/v0.3. The tool never contacts a device, never
makes a network call, and never modifies anything.

## §1 Functional requirements

- **FR-01 [MVP]** The tool MUST accept a path to a single ASA config text file as
  input and read it from local disk only. (R4; DISCOVERY explicit ask)
- **FR-02 [MVP]** The tool MUST parse the config into a hierarchical model
  (indentation tree with parent/child line nodes) preserving each line's number
  and raw text. (RESEARCH §5; CHECK_CATALOG B2)
- **FR-03 [MVP]** The tool MUST build a repeated-prefix family index (access-list
  by name, crypto map by name/seq, `name` IP↔symbol map, tunnel-group, banner).
  (RESEARCH §5)
- **FR-04 [MVP]** The tool MUST build a `name`→IP symbol table and resolve `name`
  symbols before evaluating object/ACL references. (CHECK_CATALOG B5 gotcha 8)
- **FR-05a [MVP]** The tool MUST perform *minimal* `object` / `object-group`
  resolution — enough to expand the references that the MVP-15 checks evaluate
  (e.g., an ACE expressed via object-groups that is functionally `permit ip any
  any`). Each check MUST declare whether it operates on resolved or raw text. The
  exact object-group nesting depth v0.1b minimal resolution guarantees MUST be
  stated (e.g., one level of expansion, no recursive `group-object`); structures
  deeper than that MUST be reported "not assessed" (OR-03), never silently passed
  — under-flagging is a false negative the zero-FP gate cannot catch.
  (RESEARCH §6; AI review 20260624-094932: anthropic CRITICAL — FR-05 was
  deferred while MVP checks depend on it; 20260624-101250 anthropic HIGH —
  resolution scope was circular.)
- **FR-05b [Scale]** The tool MUST resolve deep/nested `group-object` references
  recursively and support unused-object hygiene. (RESEARCH §3)
- **FR-06 [MVP]** The tool MUST evaluate a catalog of security checks against the
  parsed model and produce a finding per failed check. (VISION §2)
- **FR-07 [MVP]** Each finding MUST include: check id, category, severity, the
  config evidence (line number(s) + raw text, or an explicit "absent" marker),
  an authority reference (CIS/STIG, or "tool heuristic"), and a remediation note.
  For findings a static tool cannot fully adjudicate (e.g., a literal `permit ip
  any any` that may be correctly scoped by NAT/security-levels), remediation
  wording MUST frame the action as **"review,"** not "remove," so the analyst is
  not handed a wrong recommendation. (VISION §4 Bet 4; CHECK_CATALOG; AI review
  20260624-094932: referee addition.)
- **FR-08 [MVP]** The check engine MUST support **absence-based** checks (flag a
  finding when a required line is not present anywhere in the config), driven by
  a documented ASA 9.x defaults model. Absence checks that are only findings in
  certain contexts MUST be **context-conditional** (e.g., uRPF absence is a
  finding on the outside/untrusted interface, not on a management interface), to
  avoid over-flagging. (RESEARCH §5; CHECK_CATALOG B5 gotcha 7; AI review
  20260624-094932: anthropic efficacy + mistral default-model gate.)
- **FR-08a [MVP]** Interface-context checks (uRPF, no-SSH-on-outside,
  outside-security-level-0) MUST consume a single shared **interface-role model**
  that maps `nameif` and `security-level` per interface and encodes the
  security-level default (a named interface is 0 unless set). The uRPF rule is
  formalized: absence is a finding if `security-level == 0` OR `nameif ==
  outside`. (AI review 20260624-101250: all three — context heuristic was
  asserted but never specified; shared model designed once.)
- **FR-08b [MVP]** The ASA 9.x **defaults model** that absence checks consume MUST
  be a named data file (`data/asa-defaults.psd1`) scoped to the MVP-15 absence
  checks, where each default carries a Cisco ASA 9.x documentation citation (an
  external source of truth, not just a test). (AI review 20260624-101250: all
  three — defaults model was load-bearing but had no content/source-of-truth.)
- **FR-09 [MVP]** The tool MUST classify password/secret lines by hash type
  (pbkdf2/`$sha512$` = strong, `encrypted` = weak, `nt-encrypted` = NT, no tag =
  cleartext) and flag cleartext and weak secrets. (CHECK_CATALOG B3)
- **FR-10 [MVP]** The tool MUST detect cleartext secrets wherever they appear:
  `snmp-server community`, `aaa-server ... key`, `ntp authentication-key ... md5`,
  tunnel-group `pre-shared-key`. (CHECK_CATALOG B3)
- **FR-11 [MVP]** The tool MUST implement the 15 MVP shortlist checks
  (CHECK_CATALOG A8) across management, AAA, logging, crypto, access-control.
- **FR-12 [Scale]** The tool MUST implement the remaining CIS + DISA STIG checks
  in CHECK_CATALOG A1–A7.
- **FR-13 [Scale]** The tool MUST detect access-list entries that reference an
  undefined object/object-group, and ACLs defined but never bound by an
  `access-group`. (CHECK_CATALOG A4 heuristics)
- **FR-14 [vNext]** The tool SHOULD detect redundant/shadowed ACL entries using
  the ASA-ACL-toolkit approach. (RESEARCH §3; OQ-C)
- **FR-15 [Scale]** The tool SHOULD parse the ASA version (`ASA Version` header or
  `boot system flash:` line) and compare it to a local EoL/known-vuln lookup
  table, degrading gracefully when absent. (CHECK_CATALOG A7; OQ-B)
- **FR-16 [MVP]** The tool MUST emit a Markdown report to stdout (user redirects)
  and MUST write a CSV findings file. Status/diagnostic output (OR-02 prefixes,
  run summary, warnings) MUST go to a separate stream (stderr / information
  stream), keeping the stdout report clean and diff-able. (R2; AI review
  20260624-094932: anthropic — stream separation for byte-clean output.)
- **FR-17 [MVP]** The tool MUST exit non-zero on unreadable/empty/non-ASA input
  and explain why; a successful run with findings still exits 0. (powershell.md)
- **FR-18 [vNext]** The tool MAY support a baseline/suppression file to mark known
  accepted findings as informational on later runs. (VISION §5 v0.3)
- **FR-19 [MVP]** The tool MUST support a **check profile** selecting which checks
  apply. The default profile is **commercial** (CIS-weighted). An opt-in
  **DoD/STIG** profile enables DoD-specific checks (FIPS mode, exact DoD banner
  text, mandatory split-tunnel, VPN DoD banner) that would be noise on a
  commercial device. Profile membership MUST be catalog data, not hardcoded.
  (VISION §5 profiles; AI review 20260624-094932: anthropic Adjustment 3.)

### Segmentation & data-flow visualization (Phase 5; decided 2026-06-24)

Origin: `20260624_segmentation-visualization_RESEARCH.md`. Package B (Mermaid
topology + zone matrix), separate output file, always produced.

- **FR-20 [Viz]** The tool MUST derive a **zone model** from the parsed config:
  one zone per in-service interface keyed by `nameif` + effective `security-level`
  (reusing the interface-role model, FR-08a). Zones MAY be grouped into trust
  tiers by security-level band for display.
- **FR-21 [Viz]** The tool MUST map ACE source/destination addresses to zones —
  by longest-prefix match against interface IP/subnets; `any` spans all zones; an
  address not resolvable to a configured interface zone MUST be shown as an
  explicit `external/unknown` zone, never silently dropped. Object/object-group
  references are resolved via the existing resolver (FR-05a), with `not assessed`
  (OR-03) carried through when resolution depth is exceeded.
- **FR-22 [Viz]** The tool MUST derive inter-zone **allowed-flow edges** from the
  permit ACEs of ACLs bound to interfaces/directions via `access-group`. Edges
  represent *configured/allowed* flows per the ruleset, NOT computed dataplane
  reachability (see §11 OOS-02).
- **FR-23 [Viz]** The tool MUST emit a **zone-level Mermaid topology** (nodes =
  zones, edges = allowed inter-zone flows) and a **zone-to-zone connectivity
  matrix** (rows = source zone, cols = destination zone, cell = most-permissive
  allowed posture).
- **FR-24 [Viz]** Risk conditions MUST be highlighted with color **plus** a
  redundant non-color cue (label/badge): `permit ip any any` and other
  high-severity flows render as a thick highest-severity edge / darkest matrix
  cell, each labeled with the offending ACL line and tied to the finding model
  (severity + evidence reused from the check engine; SR-05 evidence-first holds).
- **FR-25 [Viz]** The visualization MUST be written to a **separate output file**
  next to the configuration file (distinct from the findings MD/CSV), timestamped
  (DR-03), and MUST be **produced on every run**.
- **FR-26 [Viz]** All visualization output MUST be generated as local text
  (Mermaid source + Markdown/HTML matrix). The tool MUST NOT invoke any renderer
  or online service; rendering to an image is the analyst's local, offline step
  (SR-01 holds). Secret masking (SR-04) applies to any evidence shown in the
  visualization.

### Consolidated HTML deliverable (Phase 5b; decided 2026-06-24)

Origin: client has no GitHub/VS Code, so Mermaid does not render for them. A
single self-contained HTML report is the client deliverable.

- **FR-27 [Viz]** The tool MUST produce a single **self-contained HTML report**
  that consolidates the findings and the segmentation map (topology + matrix),
  written next to the config (timestamped, never overwriting it), produced on
  every run. It MUST open in any browser with no install and no internet.
- **FR-28 [Viz]** The HTML MUST be self-contained and portable: embedded CSS
  only, the topology drawn as **inline SVG** (renders and prints identically with
  no diagram-as-code renderer), **no JavaScript**, and **no external resource
  references** (so it survives strict client mail/secure-transfer gateways).
  Secret masking (SR-04) applies. The SVG MUST be well-formed and render
  realistically (verified by rendering, not asserted).
- **FR-29 [Viz]** PDF is produced by the analyst/client via the browser's
  Print -> Save as PDF (documented in the report and README); the tool MUST NOT
  require a PDF binary. The Markdown findings/segmentation and CSV remain as
  working/machine-readable artifacts.

## §2 Non-functional requirements (NFR)

- **NFR-01 [MVP]** The tool MUST run on Windows PowerShell 5.1 with no installed
  modules and no .NET beyond the 5.1 baseline. (R3)
- **NFR-02 [MVP]** The tool MUST also run unmodified on PowerShell 7+ on Windows.
  (R3)
- **NFR-03 [MVP]** The tool MUST complete a typical ASA config (<= ~5,000 lines)
  in under 10 seconds on a standard analyst laptop. (VISION §1)
- **NFR-04 [Scale]** The tool SHOULD process a large config (~20,000 lines)
  without unbounded memory growth or quadratic blowup in the parser. (VISION
  Bet 2 mitigation)
- **NFR-05 [MVP]** The tool MUST be a self-contained script set with no install
  step beyond copying files and setting execution policy for the process. (R3)
- **NFR-06 [MVP]** Output MUST be **deterministic** across runs and runtimes:
  findings emitted in a defined sort order (check id, then line number); all
  string/number comparisons and sorting use `InvariantCulture`; output line
  endings normalized. This is what makes repeatability (BSC-03) and cross-runtime
  equivalence (TSC-09) achievable rather than intermittently failing. (AI review
  20260624-094932: anthropic HIGH.)
- **NFR-07 [MVP]** Finding/report accumulation MUST avoid accidentally quadratic
  PowerShell patterns (no `+=` array growth or repeated string concatenation in
  hot paths); use list-based accumulation. (AI review 20260624-094932: anthropic
  performance.)

## §3 Security requirements (SR)

- **SR-01 [MVP]** The tool MUST NOT make any network connection of any kind. No
  HTTP, DNS, SMB, telemetry, or update check. (R4)
- **SR-02 [MVP]** The tool MUST be strictly read-only: it reads the input file and
  writes only its report/CSV to a user-specified or working directory. It MUST
  NOT modify the input or any device. (R5)
- **SR-03 [MVP]** The tool MUST NOT transmit, log externally, or cache the config
  contents anywhere outside the analyst-specified output. (R4; VISION §7)
- **SR-04 [MVP]** Output files containing config evidence MUST be written only
  where the analyst directs. The tool MUST **mask discovered secret values by
  default** in all output (Markdown, CSV, console) — passwords/hashes, SNMP
  communities, AAA keys, NTP keys, PSKs — revealing them only via an explicit
  opt-in flag. The tool's own deliverable must not become a credential-leak
  vector. Masking MUST include a **conservative fallback**: any line matching a
  broad secret-keyword pattern (`community`, `key`, `pre-shared-key`, `password`,
  `snmp-server ... v3 ... auth/priv`) is redacted even when the specific construct
  is not fully parsed, so a parser gap cannot leak a secret. Masking MUST apply to
  verbose/debug output as well as the report. When `-RevealSecrets` is set, the
  tool MUST emit a loud status-stream warning naming the output file as
  credential-bearing. (R4; AI review 20260624-094932 anthropic+mistral — promoted
  to default MUST; 20260624-101250 anthropic HIGH — masking is only as good as
  detection, added fallback + verbose coverage + reveal warning.)
- **SR-05 [MVP]** A finding MUST be defensible by its config evidence
  independent of its authority ID, because some CIS/STIG IDs are `[unverified]`.
  (RESEARCH OQ-A; VISION Bet 4)
- **SR-06 [MVP]** The tool MUST process config content as inert text only. It
  MUST NOT use `Invoke-Expression` or any dynamic code generation/evaluation on
  config input. (AI review 20260624-094932: mistral.)
- **SR-07 [MVP]** The tool MUST bound its handling of malformed or hostile input
  with **concrete thresholds**: max input-file size (~10 MB), max single-line
  length (~4 KB), max nesting depth (~10 levels) — starting points to validate
  against real configs — plus bounded reads and regex anchors that avoid
  catastrophic backtracking (compiled, simply-anchored patterns). A corrupt or
  oversized file MUST fail gracefully, not exhaust memory or hang. (AI review
  20260624-094932: anthropic security GAP; 20260624-101250: all three — bounds
  needed thresholds, not just "a guard".)
- **SR-08 [MVP]** Bundled data files (catalog, defaults, EoL) MUST be loaded with
  `Import-PowerShellDataFile` (data-only parse), never dot-sourced or evaluated.
  (AI review 20260624-101250: anthropic — a dot-sourced `.psd1` is a code-exec
  vector.)

## §4 Integration requirements (IR)

- **IR-01 [MVP]** The only external interface is the **input file contract**: a
  text file in Cisco ASA `show running-config` format (ASA 9.x). The tool MUST
  tolerate CRLF and LF line endings and a leading `: Saved` / `: Hardware:`
  metadata header. (RESEARCH §5)
- **IR-02 [MVP]** The tool MUST NOT depend on any external service, API, or
  device. There are no other integrations. (R4)
- **IR-03 [Scale]** The version/EoL lookup (FR-15) MUST be a local data file
  bundled with the tool, never a network lookup. (OQ-B; SR-01)

## §5 Data requirements (DR)

- **DR-01 [MVP]** Input is sensitive client data. The tool MUST treat the config
  and all derived findings as confidential and keep them local. (R4)
- **DR-02 [MVP]** The findings CSV MUST have a stable column schema: check id,
  category, severity, authority ref, status, evidence line number(s), evidence
  text (optionally masked), remediation. (R2; FR-07)
- **DR-03 [MVP]** All output filenames MUST include a timestamp
  (`YYYYMMDD_HHMMSS`). (Cutaway Absolute Requirements)
- **DR-04 [MVP]** The check catalog MUST be represented as structured data
  (separable from engine code) for presence/absence/pattern checks, with an
  explicit per-check schema: `id`, `category`, `severity`, `profile`
  (commercial / dod), `authority` + `verified` flag, `pass`/`fail` pattern (or
  absence marker), `default_if_absent`, `rationale`, `remediation`. The
  declarative-data vs structural-code boundary MUST be drawn before checks are
  coded: presence/absence/pattern checks are data; resolution-aware/structural
  checks (undefined references, unbound ACLs, shadowing) are engine code. The
  schema MUST also carry `confidence` (deterministic / context-sensitive /
  heuristic) and `dependency` (raw / resolved / defaults / interface-role) so
  failures are diagnosable. (VISION Bet 3; AI review 20260624-094932
  anthropic+mistral — schema + boundary; 20260624-101250 openai — confidence +
  dependency metadata.)
- **DR-06 [MVP]** Each entry in the defaults model (`asa-defaults.psd1`) MUST
  carry a Cisco ASA 9.x documentation citation, so the model has an external
  source of truth and is not a second fixture-circularity oracle. (AI review
  20260624-101250: anthropic.)
- **DR-05 [Scale]** The version/EoL table (FR-15) MUST record source and revision
  date for each entry so staleness is visible. (OQ-B)

## §6 Observability requirements (OR)

- **OR-01 [MVP]** The tool MUST report a run summary: file parsed, line count,
  checks evaluated, findings by severity. (VISION §7)
- **OR-02 [MVP]** The tool MUST use Cutaway status prefixes in console/diagnostic
  output (`[+]` pass, `[-]` fail, `[*]` info, `[$]` report, `[x]` error). (Cutaway
  convention, inherited as convention only)
- **OR-03 [MVP]** The tool MUST report checks it could not evaluate (e.g., version
  absent) as explicit "not assessed," never silently skip. (CLAUDE.md no-stub)
- **OR-04 [SHOULD]** The tool SHOULD support a verbose mode that shows parser
  decisions for troubleshooting a misparse. (NFR-04 debugging)

## §7 Operational requirements

- **OP-01 [MVP]** The tool MUST run from a single entry-point script with
  comment-based help (`Get-Help`). (powershell.md)
- **OP-02 [MVP]** The tool MUST document the one-time `Set-ExecutionPolicy -Scope
  Process -ExecutionPolicy Bypass` step and require nothing else. (powershell.md)
- **OP-03 [MVP]** The tool MUST run fully offline on an air-gapped analyst host.
  (R4)

## §8 Architectural requirements (AR)

- **AR-01 [MVP]** Parsing MUST be separated from checking: a parse layer produces
  the model; a check layer consumes it. (VISION Bet 3)
- **AR-02 [MVP]** The parser MUST use an indentation-stack tree plus a
  repeated-prefix index, not flat single-pass regex over independent lines.
  (RESEARCH §5)
- **AR-03 [MVP]** Each check MUST be an independently testable unit producing a
  structured finding object. (RESEARCH §3)
- **AR-04 [MVP]** Output formatting (Markdown, CSV) MUST be separated from check
  evaluation so formats can be added without touching checks. (R2)
- **AR-05 [Scale]** Structural checks (object resolution, shadowing) MAY live in
  engine code where they cannot be expressed as catalog data; the data/code
  boundary MUST be explicit. (VISION Bet 3)

## §9 Maintainability requirements (MR)

- **MR-01 [MVP]** Adding a simple presence/absence/pattern check MUST be possible
  by editing catalog data without changing engine code. (DR-04)
- **MR-02 [MVP]** Each check MUST carry its authority reference and revision label
  as metadata so benchmark drift is traceable. (RESEARCH OQ-A)
- **MR-03 [MVP]** Code MUST follow `code-standards/powershell.md` (CmdletBinding,
  param validation, try/catch with `-ErrorAction Stop`, no `Format-*` mid-pipe).
- **MR-04 [MVP]** NO emoji/Unicode symbols in code, output, or docs; NO stubs or
  fake data; NO spaces in file/folder names. (CLAUDE.md Absolute Requirements)

## §10 Testing requirements (TR)

- **TR-01 [MVP]** A synthesized, syntactically faithful ASA 5515 config fixture
  MUST exist, covering every construct in CHECK_CATALOG B, including the
  lower-confidence branches (B6). (OQ-D, OQ-E)
- **TR-02 [MVP]** The fixture MUST contain known-bad and known-good instances for
  each MVP check, and tests MUST assert the tool produces exactly the expected
  findings (true positives) and no false positives on the good instances. (OQ-D)
- **TR-03 [MVP]** Parser unit tests MUST cover: indentation nesting (2–3 deep),
  repeated-prefix grouping, `name` resolution, password hash classification,
  multi-line banner reassembly, and the two NAT / two webvpn disambiguations.
  (CHECK_CATALOG B5)
- **TR-04 [MVP]** Tests MUST run offline with no device and no network. (R4)
- **TR-05 [Scale]** A second, independently authored fixture SHOULD be added to
  guard against the tool being overfit to the first fixture. (OQ-D)
- **TR-06 [MVP]** "Done" for any check means it passes its true-positive and
  true-negative fixture assertions — not "the code looks right." (SUCCESS_CRITERIA §4)
- **TR-07 [MVP]** The v0.1a-core parser MUST cleanly parse at least two real
  sanitized ASA configs sourced independently of the team (e.g., the GitHub
  configs cited in RESEARCH references — HQ-FW2.txt, ASABuzzNick), **obtained and
  stored locally as a one-time manual step — never fetched over the network at
  dev time** (that contradicts SR-01/OP-03). Operational definitions: "clean
  parse" = every line is placed in the model with correct parent/child or
  repeated-prefix assignment; an unknown line **preserved as a generic node is
  acceptable** as long as it does not corrupt surrounding structure;
  "misassigned" = a line given the wrong parent/sibling or wrong family. Fallback
  gate if two committable configs cannot be obtained: N independently-authored
  fixtures by a second person, explicitly labeled a weaker oracle in release
  notes. This is the structural break of the fixture-as-oracle circularity and is
  a v0.1a-core release gate. (AI review 20260624-094932 anthropic+mistral;
  20260624-101250 anthropic CRITICAL + openai — secure the oracle, define the
  terms, no dev-time fetch; RESEARCH OQ-D.)
- **TR-08 [MVP]** A masking test MUST assert that **no seeded secret token from
  the fixture appears verbatim** in default-masked output (Markdown, CSV, or
  verbose). This is a hard release gate, not an aspiration. (AI review
  20260624-101250: anthropic HIGH — silent secret-leak failure mode.)

## §11 Out of scope

- **OOS-01** Live device interrogation / SSH / hitcount-based rule-usage analysis.
  Re-entry: a separate live-collection tool (needs device data). (VISION §6)
- **OOS-02** Dataplane/reachability modeling (Batfish territory). Re-entry: none
  planned. NOTE: the Phase-5 visualization (FR-20..FR-26) shows *configured/allowed
  flows per the ruleset*, which is NOT end-to-end reachability — it does not model
  routing, NAT translation, or full cross-path rule-order/shadowing. The output
  must state this so a segmentation map is not mistaken for a reachability proof.
  (VISION §6)
- **OOS-03** Multi-vendor or non-ASA-9.x parsing (IOS, FTD, PIX, others). Re-entry:
  a future parser generalization, explicitly not now. (VISION §6)
- **OOS-04** Remediation / config-change generation / pushing changes. (VISION §6)
- **OOS-05** Any online, SaaS, or telemetry capability. (R4; VISION §6)
- **OOS-06** Compliance certification/attestation. CIS/STIG mapping is guidance
  only. (VISION §6)
