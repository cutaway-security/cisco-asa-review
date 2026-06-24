# VIBE_HISTORY.md

AI session-continuity memory. Claude writes and reads this file for continuity
across sessions; it is not a document you are expected to maintain by hand.
Newest entry first. Durable decisions and lessons accumulate here over the
project's lifetime.

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
