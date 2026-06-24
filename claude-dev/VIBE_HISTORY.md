# VIBE_HISTORY.md

AI session-continuity memory. Claude writes and reads this file for continuity
across sessions; it is not a document you are expected to maintain by hand.
Newest entry first. Durable decisions and lessons accumulate here over the
project's lifetime.

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
