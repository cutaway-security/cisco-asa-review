# VIBE_HISTORY.md

AI session-continuity memory. Claude writes and reads this file for continuity
across sessions; it is not a document you are expected to maintain by hand.
Newest entry first. Durable decisions and lessons accumulate here over the
project's lifetime.

---

## 2026-06-24 -- Phase 5b: consolidated self-contained HTML deliverable (gate passed)

**Why**: the client has no GitHub/VS Code, so the Mermaid `.md` does not render for them. Needed a deliverable that displays with nothing installed.

**Decision (with the maintainer)**: one self-contained HTML report consolidating findings + segmentation. Topology = hand-emitted **inline SVG** (NOT JS-rendered Mermaid, NOT an analyst-side renderer); matrix = colored HTML table; embedded CSS; **no JavaScript, no external references**. Rationale: renders identically in any browser and prints to PDF with nothing installed, and an HTML-with-only-SVG/CSS attachment survives strict client mail/secure-transfer gateways that strip HTML+JS. PDF = browser Print -> Save as PDF (no PDF binary in the tool).

**What landed**: `src/Write-AsaHtmlReport.ps1` (findings table with severity colors, inline-SVG zone topology in trust-tier columns with red ANY/ANY arrows + untrusted styling, colored zone matrix, risk-flow list; masking applied; deterministic). Wired into `Invoke-AsaReview.ps1` (always produced; now four outputs: MD findings, CSV, segmentation.md (Mermaid, internal), and the HTML deliverable). Guard write-boundary extended. `tests/unit/HtmlReport.Tests.ps1` (9 tests). Suite 98/98.

**Addressing the maintainer's SVG concern ("SVG often does not display as coded")**: verified by RENDERING, not asserting. Rendered the HTML to a PNG with wkhtmltoimage (WebKit, same engine family as browsers) and visually inspected it -- the SVG topology and matrix display realistically and usably; the SVG also validates as well-formed XML (xmllint / [xml] parse). Confirmed the PDF path with wkhtmltopdf (47KB PDF). Layout stays robust because zones aggregate to a few nodes (tier-column layout, directional arrows by column comparison).

**Lessons**: for a client deliverable, "diagram-as-code" (Mermaid) is the wrong final form -- it needs a renderer the client lacks. Inline SVG + HTML table is the portable answer: zero deps both sides, print-stable, mail-gateway-safe (no JS). Keep Mermaid as the INTERNAL artifact (renders in GitLab/VS Code for our own use). Always visually verify rendered output for a deliverable, not just structure assertions.

**Status**: on `claude-dev` only; NOT released to `main`.

---

## 2026-06-24 -- Phase 5: segmentation + data-flow visualization (gate passed)

**What landed**

- `src/Get-AsaZoneModel.ps1` -- zones from the interface-role model (nameif + security-level, tiered Untrusted/DMZ/Trusted); address→zone mapping by longest-prefix vs interface subnets (uint32 math, no network); `any`/0.0.0.0-0 = all zones, unmapped = explicit `external`, OR-03 not-assessed carried through; inter-zone allowed-flow edges from access-group-bound permit ACEs (in/out/global handled).
- `src/Write-AsaSegmentation.ps1` -- a separate Markdown file: zone-level Mermaid flowchart (tier subgraphs, untrusted classDef, red `linkStyle` on risk edges), a zone-to-zone connectivity matrix, and a risk-flow list. ANY/ANY highlighted and attributed to the offending ACL line; masking applied; the configured-flows-not-reachability boundary + best-effort gaps stated in-file.
- Wired into `Invoke-AsaReview.ps1` (always produced, third output alongside MD + CSV). Guard write-boundary extended to the new writer.
- `tests/unit/Segmentation.Tests.ps1` (14 tests). Suite 89/89 green; end-to-end verified.

**Durable decisions / scope**

- Best-effort STOP-GAP, explicitly not a commercial segmentation tool -- the output says so. Shows CONFIGURED/ALLOWED flows per the ruleset, NOT reachability (NAT/routing/shadowing not modeled, OOS-02).
- Pure offline TEXT emission (Mermaid + Markdown matrix); no renderer invoked. The analyst renders Mermaid locally (VS Code/GitLab/GitHub) -- no online tool, SR-01 holds; the static guard enforces it.
- Detects BOTH literal `permit ip any any` and object-group-expressed any/any (`permit ip object-group ANY object-group ANY`) -- the latter is the one flat tools miss; reuses the existing resolver + Test-AsaNetworkGroupIsAny.

**Lessons (bugs found via the real end-to-end run, then fixed + test-guarded)**

- **PowerShell `-eq` coercion:** `$isAny -eq 'not-assessed'` with a [bool] `$true` on the LEFT coerces the RHS string to [bool] (non-empty = true), so a genuine object-group any/any was misread as "unknown" and dropped from the map. Fix: test type first (`$isAny -isnot [bool]`) before the boolean branch. Standing reminder for this codebase: when a value may be bool OR a sentinel string, never put the bool on the LHS of `-eq` against a string literal.
- **Edge line attribution:** an aggregated zone→zone edge (which merges several ACEs) initially labeled itself with the first line, so a scoped `permit tcp` line got tagged "ANY-ANY". Fix: select the any/any contributing line for the label/evidence. Both bugs now have dedicated tests.
- The real-output review was what surfaced both -- echoes the project's "verify against real output, not just green tests" discipline.

**Project context**

- Phase 5 gate PASSED: 89/89 tests + clean end-to-end run (insecure fixture: outside row + inside row all ANY-ANY in the matrix; risk flows correctly cite line 80 literal + line 81 object-group). On `claude-dev` only; NOT yet released to `main`.
- Next (pending instructions): release Phase 5 to main (RELEASE_TO_MAIN.md), Windows PS 5.1 verification, Phase 6 (v0.2 coverage).

**Next session**

- Await instructions: release to main and/or proceed to Phase 6.

---

## 2026-06-24 -- v0.1b published + validated on PowerShell 7; visualization under consideration

- Repo cloned and run on a real host under PowerShell 7: the tool executed end to end and produced both the Markdown and CSV reports correctly (user-reported). PSv7 is now validated in practice. Still pending for a "shipped" claim: Windows PowerShell 5.1 run (TSC-09/NFR-01), a runtime egress monitor (TSC-11), and a findings-accuracy review against a real engagement config.
- New direction (researched + decided + PLANNED, NOT yet built): a separate VISUALIZATION output for network segmentation + data flow, highlighting ANY/ANY risk, for conversations and reports. Two research passes (representation styles + offline diagram-as-code formats) saved to `20260624_segmentation-visualization_RESEARCH.md`. Decision: **Package B** = zone-level **Mermaid topology + zone-to-zone matrix**, **separate output file**, **produced on every run**. Key findings: aggregate by security zone (nameif+security-level); topology for conversation / matrix for report (mature tools ship both; Nipper + Cisco CDO ship neither = differentiation); Mermaid + matrix are pure offline text rendering with zero install in VS Code/GitLab/GitHub (no online tool, SR-01 holds). Boundary recorded: the map shows CONFIGURED/ALLOWED flows, NOT reachability (no routing/NAT/shadowing modeled; OOS-02) — output must say so. Planning updated: REQUIREMENTS FR-20..FR-26 + OOS-02 note, ARCHITECTURE §7b + module layout + §14, SUCCESS_CRITERIA TSC-12 extended + TSC-13, VISION §6 boundary, PLAN Phase 5 (Coverage→6, Depth→7) + 2 decision-log rows. Per maintainer's gated process: options → plan → (await go-ahead) → build. NOT started.

---

## 2026-06-24 -- Branch model: main = release-only, claude-dev = development

Pushed to private repo cutaway-security/cisco-asa-review. Per the maintainer's
convention: `main` holds ONLY released project files and must contain NO Claude/
dev artifacts (CLAUDE.md, claude-dev/, .ai-reviews/, background/); `claude-dev`
holds everything. main was rebuilt as an ORPHAN branch (independent history)
containing the release allowlist only, with a release-variant README (no
claude-dev/ companion links). Release is a curated copy from claude-dev, never a
merge (a merge would drag Claude files onto main). Procedure documented in
claude-dev/RELEASE_TO_MAIN.md; convention added to CLAUDE.md "Branch Model".
Tag v0.1b points at the main release commit.

---

## 2026-06-24 -- Phase 4: v0.1b check engine + output (gate passed; v0.1b MVP reached)

**What landed**

- `data/check-catalog.psd1` -- the 15 MVP checks as data (DR-04 schema: id, category, severity, profile, authority+verified, confidence, dependency, rationale, remediation), with detector type present/absent/code.
- `src/Invoke-AsaChecks.ps1` -- engine; dispatches present (pattern), absent (default-backed), code detectors; emits findings sorted deterministically (severity, ordinal id, line).
- `src/checks/structural.ps1` -- the 4 code detectors: console-timeout (numeric + default-0), snmp-community (standalone + host-line v1/v2c), ntp-auth (conditional absence), acl-any-any (resolution-aware, returns not-assessed beyond depth).
- `src/Protect-AsaSecret.ps1` -- default-on masking with conservative keyword fallback.
- `src/Write-AsaReport.ps1` -- Markdown (stdout) + timestamped MD/CSV written next to the config, never overwriting it; status on a separate stream.
- `Invoke-AsaReview.ps1` -- entry point (params, profile, exit codes, run summary).
- `tests/unit/Checks.Tests.ps1` (engine oracle, masking, e2e) + `tests/unit/Guard.Tests.ps1` (static no-network / write-boundary). Suite 73/73.

**Durable decisions**

- Output location (user instruction this session): report + CSV write to the CONFIGURATION FILE's own directory by default (not cwd), with a guard that refuses any output path equal to the config file. Markdown also goes to stdout (R2). ARCHITECTURE section 10 updated.
- Detector split honors AR-05: simple presence/absence checks are catalog data; the 4 genuinely structural checks (numeric/conditional/resolution) are code in checks/structural.ps1. 11 of 15 are pure data.
- Passive-boundary enforced in CODE: `Guard.Tests.ps1` greps all tool scripts for network/active-collection/dynamic-exec primitives and for writes outside Write-AsaReport, failing the build on violation. This is the static complement to the runtime egress check (TSC-11), added at the user's emphasis on passive-only.
- README now has a "Passive and offline by design" section spelling out no-device / no-network / read-only / inert-data, and that the analyst exports the config out-of-band.

**Lessons**

- The big time-sink: `return ,$array` (leading-comma wrap) inside functions made `@(func -param ...)` keep the result as a 1-element array-of-array, so Where-Object "matched everything" and counts were wrong. Two of the apparent failures (hardened FP, not-assessed multi-status) were this artifact, not real bugs. Fix: emit the collection NORMALLY (`$findings | Sort-Object ...` as the trailing expression) so the pipeline unrolls; let the CALLER's `@()` guarantee array-ness. Also: `Write-Output $sorted` when $sorted is $null (empty Sort-Object result) emits a literal $null -> a phantom 1-element finding; emit the pipeline directly instead so empty stays empty.
- Pester 5 `It -Skip:(expr)` and `<->` in titles bit us in earlier phases; this phase's gotchas were all array-unrolling. Worth a standing note: prefer pipeline-style emission + caller @() over comma-wrap returns in this codebase.
- The SNMP-COMMUNITY structural check catches BOTH the standalone `snmp-server community X` and the inline `snmp-server host ... community X version 2c` -- closing the v0.2 gap flagged in Phase 3. Verified in the real run (host-line community shown masked).

**Project context**

- Phase 4 gate PASSED: 73/73 tests + a clean end-to-end CLI run (15 findings on the insecure copy, `community [REDACTED]`, zero seeded-secret leaks, input file byte-identical after run, outputs beside the config). This is the v0.1b "real call returns data" milestone -- against the faithful fixtures + a real config copy, since no live device/client config exists.
- Remaining before a "shipped" claim: run on Windows PowerShell 5.1 (TSC-09/NFR-01) and a runtime egress monitor (TSC-11). Dev host is Linux/pwsh 7.6.2.

**Next session**

- After summary review: Windows PowerShell 5.1 verification, then Phase 5 (v0.2 coverage) -- full CIS/STIG catalog, deep resolution, undefined-ref/unbound-ACL heuristics, version/EoL table, second independent fixture.

---

## 2026-06-24 -- Phase 3: v0.1b-prep support models (gate passed)

**What landed**

- `src/Get-AsaSecrets.ps1` -- `Get-AsaPasswordClass` (value+tag -> pbkdf2 / encrypted / nt-encrypted / cleartext / redacted) and `Get-AsaSecrets` (scans the model for passwords, SNMP communities, AAA keys, NTP keys, tunnel-group PSKs; returns Class + IsCleartext per secret).
- `src/Get-AsaInterfaceRoles.ps1` -- per-interface nameif + effective security-level (encodes the default: inside=100, other=0), InService, IsUntrusted (= security-level 0 OR nameif outside).
- `src/Resolve-AsaReferences.ps1` -- `Resolve-AsaName`, `Resolve-AsaNetworkGroup`, `Test-AsaNetworkGroupIsAny`. One level of group-object expansion; deeper nesting and undefined references return Assessed=$false ("not-assessed", OR-03).
- `data/asa-defaults.psd1` -- the 8 MVP absence/conditional defaults, each doc-cited.
- `tests/unit/SupportModels.Tests.ps1` -- 20 tests. Suite now 56/56.

**Durable decisions**

- Secret classification is unified: PSKs / SNMP communities / AAA keys / NTP keys have no hash tag in running-config, so their VALUE is run through the same `Get-AsaPasswordClass` -- a `$sha512$` value (password-encryption-protected) classifies as not-cleartext, a literal classifies as cleartext. This is why the hardened fixture's `$sha512$`-wrapped aaa-key and PSK come back not-cleartext while its `md5 sharedntpkey` comes back cleartext.
- `nt-encrypted` is classified to its own label but the TSC-05 gate only asserts IsCleartext=$false (not exact subtype), per the second multi-AI pass relaxation -- a confirmed real `nt-encrypted` sample is still needed before gating the subtype.
- The defaults model carries a per-entry Cisco doc citation (DR-06), making it an externally-grounded model, not a second self-authored oracle. The MGMT-SSH-VERSION entry records the real version nuance found during research: the `ssh version` command was removed in 9.16(1), so the check is N/A on 9.16+ and applies to 9.x < 9.16 (our fixtures are 9.8).
- A cross-consistency test asserts the defaults model's CheckIds equal exactly the MVP checks whose Kind is absence/conditional-absence in `expected-findings.psd1` -- so the two data files can't silently drift apart.

**Lessons**

- Web-verified the SSH-version default before writing the defaults entry (CIS recommends pinning `ssh version 2`; pre-9.16 it isn't enforced by default; 9.16+ removed the command). Cheap check that turned a vague "v1 negotiable" claim into a version-scoped, citable default. Confirms the value of the doc-cited-defaults discipline.
- Known small gap (logged in RESUME Open Questions): the classifier captures the standalone `snmp-server community X` line but not the inline community in `snmp-server host ... community X`. Not a problem for the Phase-3 oracle, and Phase 4's conservative keyword fallback mask (SR-04) will redact it regardless -- but the SNMP-COMMUNITY check itself should also read the host-line form in Phase 4.

**Project context**

- Phase 3 gate PASSED: 56/56 tests green. All four support models the v0.1b checks depend on are built and tested: secret classifier, interface-role model, minimal resolution, doc-cited defaults.
- Next: Phase 4 assembles these into the check engine + the 15 MVP checks + Markdown/CSV output with default masking, gated on the expected-findings oracle (exact TP / zero FP) and the no-leak gate (TSC-12).

**Next session**

- Build `data/check-catalog.psd1` (the 15 MVP checks as data) and `src/Invoke-AsaChecks.ps1`, wiring catalog + model + defaults + interface-roles + secrets; then `Write-AsaReport.ps1` with masking-on and the `Invoke-AsaReview.ps1` entry point.

---

## 2026-06-24 -- Phase 2: v0.1a-core parser (gate passed)

**What landed**

- `src/Read-AsaConfig.ps1` -- bounded, encoding-safe reader (SR-07: 10 MB file / 4 KB line guards, CRLF/LF normalization, graceful throws). Read-only.
- `src/ConvertTo-AsaModel.ps1` -- the load-bearing parser. Single pass builds (1) an indentation tree of line nodes (indent stack, MaxDepth guard) and (2) a repeated-prefix family index (access-list by name, crypto map by name, name IP/symbol map, banner multi-line reassembly per type, tunnel-group, http/ssh/telnet, twice-NAT), plus object/object-group/interface symbol tables. Line number + raw text retained per node. No resolution, no checks, no network, no dynamic eval (SR-06).
- `src/Show-AsaModel.ps1` -- verbose model dump (OR-04): tree + index summary.
- `tests/unit/Parser.Tests.ps1` -- 21 TR-03 tests + the TR-07 real-config gate.

**Durable decisions**

- Node shape: `{ LineNo, Raw, Indent, Text, Kind, Parent, Children, Depth }`. Kind in {line, blank, separator, metadata}. Only 'line' nodes participate in the indent stack; blank/`!`/`:`-metadata attach at top level and never parent (so `!` separators don't corrupt nesting, and every line is still placed).
- "Clean parse" / "no misassigned lines" (TR-07) is operationalized as an invariant: a preorder DFS of the tree yields exactly the file line order 1..N, and every child's indent is strictly greater than its parent's. This is machine-checked (`Get-IntegrityProblems`) on both fixtures and both real configs.
- NAT disambiguation falls out of the tree for free: object-NAT is an indented child of an `object network` block; twice-NAT is a top-level `nat (...) source ...` line. Same for the two webvpn contexts (global indent-0 vs nested under `group-policy attributes`). No special-casing needed -- the parent/child model handles it.

**Lessons**

- Pester 5's Detailed output renderer chokes on a `<->` arrow in an It title with a cryptic `CommandNotFoundException: The term '$-' is not recognized` at DISCOVERY/render time. It is NOT a code bug -- the parser was correct. Keep test titles free of `<->` (and likely other operator-like punctuation). Cost me one debugging cycle; isolated by reproducing with a 2-line throwaway test.
- The verbose dump (Show-AsaModel) doubles as a cross-validator: its index counts on the insecure fixture matched the Phase-1 expected-findings construct expectations exactly (5 ACLs with outside_in=3/inside_in=2, 5 objects, 6 object-groups, 5 interfaces, maxdepth 2, twice-nat 1), and on the real ASABuzzNick config it correctly reassembled 4 multi-line banner types and indexed 14 interfaces. Good cheap confidence that the parser handles real device output.
- Dev host is Linux/pwsh 7.6.2; the tool must still be verified on Windows PowerShell 5.1 (NFR-01) before any "shipped" claim -- carried as a Next Step.

**Project context**

- Phase 2 gate PASSED: 36/36 tests green (15 corpus + 21 parser), exit 0. The load-bearing parser is proven in isolation against real device output before any check consumes it -- exactly the v0.1a/v0.1b discipline the multi-AI passes insisted on.
- Next: Phase 3 builds the v0.1b-prep support models (minimal resolution, password classifier, defaults model, interface-role model), then Phase 4 the checks.

**Next session**

- Build the password-hash classifier first (smallest, highest-consequence -- a misclassified hash is the worst miss), using the insecure fixture's `Secrets` block as the oracle; then the defaults + interface-role models.

---

## 2026-06-24 -- Phase 1: test environment + fixtures (gate passed)

**What landed**

- `tests/fixtures/asa-5515-insecure.txt` -- known-bad fixture, construct-complete (every CHECK_CATALOG Part B construct incl. B6 legacy `object-group service tcp` + `port-object`, `object-group protocol`, `nt-encrypted`/cleartext/encrypted/pbkdf2 secrets, 3-deep `group-policy attributes` -> `webvpn` -> `anyconnect`, object-NAT + twice-NAT, global webvpn). Triggers all 15 MVP findings.
- `tests/fixtures/asa-5515-hardened.txt` -- true-negative fixture; triggers none of the 15; multi-line `banner login` for the parser reassembly test; strong ikev2 crypto, SNMPv3, authenticated NTP, uRPF.
- `tests/fixtures/expected-findings.psd1` -- the validation oracle. Fixes the canonical MVP-15 check IDs and, per fixture, MustFire / MustNotFire / Secrets / ConstructsPresent.
- `tests/fixtures/real/` (gitignored) -- two real sanitized configs fetched once: HQ-FW2 (ASA 9.18, 299 lines) and ASABuzzNick (592 lines, crypto-rich).
- `tests/Invoke-Tests.ps1` + `tests/unit/Corpus.Tests.ps1` -- Pester 5 harness.

**Durable decisions**

- The MVP-15 check IDs are now fixed (in `expected-findings.psd1`): MGMT-TELNET, MGMT-SSH-VERSION, MGMT-ANY-SOURCE, MGMT-CONSOLE-TIMEOUT, LOG-ENABLE, LOG-HOST, SNMP-COMMUNITY, CRYPTO-WEAK-VPN, CRYPTO-SSL-TLS, AUTH-PWRECOVERY, AUTH-PWPOLICY, NTP-AUTH, ACL-ANY-ANY, AUTH-AAA-SSH, AUTH-BANNER. These become the catalog IDs in Phase 4. SSH/HTTP any-source is one check (MGMT-ANY-SOURCE), keeping the shortlist at 15.
- Two-fixture true-positive/true-negative design: absence checks can't be both present and absent in one file, so the insecure fixture is the "everything fires" oracle and the hardened fixture is the "nothing fires" oracle. The manifest asserts symmetry (every MustFire id is also a MustNotFire id).
- Real configs are stored locally and gitignored, fetched once by hand -- the test harness never reaches the network (verified: no network cmdlets in test code). This is the TR-07 corpus and the structural break of fixture circularity.

**Lessons**

- Pester 5 evaluates `It -Skip:(expr)` during DISCOVERY, before `BeforeAll` runs. A `-Skip` condition that referenced a `$script:` path set in `BeforeAll` threw `ArgumentNullException` at discovery. Fix: compute discovery-time conditions inline from `$PSScriptRoot` (which IS available at discovery), not from BeforeAll-scoped vars.
- `New-PesterConfiguration` needs `Run.PassThru = $true` for `Invoke-Pester` to return the result object; without it the summary counts are null (the run still works, exit logic still correct).
- The dev host is Linux with pwsh 7.6.2; Pester 5.7.1 installed from PSGallery (dev-only dependency, not a tool dependency). The tool must still be verified on Windows PowerShell 5.1 later (NFR-01).

**Project context**

- Phase 1 gate PASSED: 15/15 Pester tests green, exit 0. Fixtures + manifest validate; both real configs present and ASA-shaped.
- Next: Phase 2 builds the v0.1a-core parser, tested (TR-03) against the insecure fixture's `ConstructsPresent` list and gated (TR-07) on a clean parse of both real configs.

**Next session**

- Build `Read-AsaConfig.ps1` and `ConvertTo-AsaModel.ps1` (indentation tree + repeated-prefix index), then the parser unit tests. Gate before any checks.

---

## 2026-06-24 -- Project initialization (cutsec-init pipeline)

**What landed**

- `background/goal.md` -- the engagement goal and constraints.
- `claude-dev/DISCOVERY_NOTES.md` -- structured discovery, locked decisions R1-R5, test-data gap OQ4.
- `claude-dev/20260624_asa-config-analysis_RESEARCH.md` -- prior-art + CIS/STIG + grammar survey, fully cited.
- `claude-dev/CHECK_CATALOG.md` -- the working check catalog (CIS+STIG) and parser syntax/regex reference.
- `claude-dev/VISION.md`, `REQUIREMENTS.md`, `SUCCESS_CRITERIA.md`, `ARCHITECTURE.md` -- the planning spine.
- `claude-dev/PLAN.md`, `RESUME.md`, `TEST_ENVIRONMENT.md` -- running logs.
- `CLAUDE.md`, `README.md`, `LICENSE` (GPLv3), `.gitignore` -- orientation + hygiene.
- `claude-dev/code-standards/powershell.md` -- copied for self-containment.
- `.ai-reviews/20260624-094932/` (pass 1, Vision+Reqs+Success) and `.ai-reviews/20260624-101250/` (pass 2, Architecture), each with per-reviewer reviews + a consolidated synthesis.

**Durable decisions**

- Pure-PowerShell (5.1 floor, 7+ compatible, no modules), offline, read-only, no egress. The config is sensitive client data.
- Hierarchical parent/child parser + repeated-prefix family index is the load-bearing core. No PowerShell-native offline ASA analyzer exists -- that gap is the reason to build (RESEARCH §2).
- Findings map to CIS Cisco ASA + DISA Cisco ASA STIG, but authority IDs are advisory: a finding stands on its config evidence, because several CIS/STIG IDs could not be verified (OQ-A, SR-05).
- Output is Markdown + CSV; secret-value masking is on by default (the deliverable is otherwise credential-bearing).
- v0.1a-core (parser only) is proven in isolation before any check is built on it (v0.1b). Defaults model, interface-role model, password classifier, and minimal resolution are v0.1b prep, gated separately.
- Commercial check profile is default; DoD/STIG checks are opt-in (enterprise target).
- Validation bound: no real ASA device or client config exists. The faithful fixture + real sanitized public configs are the "real call returns data" gate; this bound is stated in every release note until a real config is run.

**Lessons (from the two multi-AI passes)**

- Pass 1 (Vision/Reqs/Success): two reviewers converged that v0.1 was over-scoped and the parser was not isolated -> split into v0.1a/v0.1b. Both flagged that secret masking must be a default MUST, not a SHOULD. anthropic alone caught a real contradiction: object-group resolution was deferred while MVP checks depended on it -> minimal resolution moved into MVP. Determinism requirements (sorted order, InvariantCulture, normalized EOL, separated streams) added so repeatability/cross-runtime gates are honest.
- Pass 2 (Architecture): all three reviewers (anthropic, mistral, openai) validated the first-pass fixes and drilled deeper. The recurring deep theme across both passes is ORACLE CIRCULARITY -- first the parser/fixture, then the defaults model and interface-role model. The mitigation is the same each time: an external source of truth (real configs for the parser; Cisco doc citations for the defaults), never just an internal test. The most dangerous newly-surfaced failure mode is silent secret leakage from masking-detection gaps -> promoted to a hard no-leak gate (TSC-12) plus a conservative keyword fallback mask. The "fetch real configs at dev time" idea was caught as contradicting the offline posture -> store locally, one-time manual.
- Citation audit (Phase 11): re-fetched the two load-bearing prior-art sources. Posh-Cisco confirmed collection-only / no auditing (the "gap" claim holds); ciscoconfparse2 confirmed GPLv3 + parent/child model. Two sub-claims tightened for precision: Posh-Cisco's ASA support is Gallery-tag metadata only (Catalyst in its documented list), and ciscoconfparse2's ASA support is via the `syntax='asa'` API parameter, not the landing README. No fabrications; the architecture-driving conclusions are intact.
- Tooling lesson: the OpenAI review key (`/home/cutaway/.claude/keys/openai.key.txt`) was initially invalid (a non-`sk-` value, HTTP 401). The user replaced it with a valid `sk-proj-` key; verified live via `GET /v1/models` (HTTP 200, gpt-5.4 present) before re-running. anthropic + mistral keys were valid throughout.

**Project context**

- Sibling CHAPS (`/home/cutaway/Projects/chaps`) is the convention reference (status prefixes, timestamped output, no-dependency, read-only, markdown) -- PATTERN not content; CHAPS predates the current `claude_frameworks` project style, so its docs were deliberately NOT used as templates.
- Templates and `code-standards/powershell.md` came from `/home/cutaway/Projects/claude_frameworks/templates`.
- LICENSE is GPLv3 (Cutaway default for tools, matching CHAPS). Note: nipper-ng / ciscoconfparse prior art is GPLv3, but only their shapes (findings model, parse model) are borrowed, not code -- no derived-work obligation.

**Next session**

- User to direct Phase 1: author the fixture and obtain the two real sanitized configs, then build the v0.1a-core parser. Confirm understanding of the staged gate before coding.
