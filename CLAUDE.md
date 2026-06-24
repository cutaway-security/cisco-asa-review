# CLAUDE.md - Project Rules and Guidelines

## Project Overview

**Project**: cisco-asa-review
**Repository**: https://github.com/cutaway-security/cisco-asa-review
**Development Branch**: claude-dev
**Release Branch**: main
**Description**: An offline, read-only, pure-PowerShell tool that parses a Cisco
ASA 9.x `show running-config` text dump and reports security findings (insecure
management access, weak crypto, permissive access rules, missing logging and
hardening, cleartext secrets) as a Markdown report plus a machine-readable CSV,
mapped to the CIS Cisco ASA Benchmark and DISA Cisco ASA STIG. It never contacts
a device and never makes a network call: the config is sensitive client data that
must not leave the analyst's host. Built for Cutaway Security firewall reviews.

---

## Branch Model

- **`claude-dev`** is the development branch. ALL work happens here, including
  every Claude/AI development artifact: `CLAUDE.md`, the `claude-dev/` planning
  set, `.ai-reviews/`, and `background/`.
- **`main`** is the release branch. It contains ONLY the released project files
  (the tool, tests, data, README, LICENSE, .gitignore). It MUST NOT contain any
  Claude/development files. The two branches have independent histories.
- **Releasing** = moving the project files for release from `claude-dev` onto
  `main` (a curated copy), never a branch merge — a merge would drag the Claude
  files onto `main`. Do not merge `claude-dev` into `main`.

---

## Essential Documents (Read in Order)

Before starting any development session, read these documents in order:

1. **CLAUDE.md** - This file. Project rules, constraints, and conventions
2. **claude-dev/ARCHITECTURE.md** - System design, decisions, constraints, data flow
3. **claude-dev/PLAN.md** - Roadmap, current phase, milestones, acceptance gates
4. **claude-dev/RESUME.md** - Development status, what is in progress, blockers, session context
5. **claude-dev/VIBE_HISTORY.md** - Decision trail and lessons. AI session-continuity memory: Claude writes and reads it, it is not a document you are expected to maintain by hand

**At session start**: Confirm you have read these documents before proceeding. List your understanding of the current state and next steps. Wait for confirmation before proceeding.

---

## Development Process Rules

When encountering issues during development:

1. **STOP** - Do not continue to next task
2. **DIAGNOSE** - Identify root cause with specific error messages and line numbers
3. **FIX** - Implement a solution
4. **VERIFY** - Confirm the fix works with actual testing
5. **DOCUMENT** - Record the issue and solution in RESUME.md
6. **ASK** - If unable to resolve after reasonable attempts, STOP and ask for clarifying directions

**Never assume code works without testing. Never move forward with unresolved issues.**

### Phase Completion Process

Before moving to the next phase:

1. **Verify** - All components of current phase working
2. **Test** - Run tests relevant to the phase
3. **Gate** - Confirm the phase's objective acceptance gate passes (a pass/fail test, not "looks done")
4. **Document** - Update RESUME.md with session activity
5. **Summarize** - Provide summary of completed work
6. **Plan** - List steps for next phase
7. **Confirm** - Wait for user confirmation before proceeding

---

## Absolute Requirements

- NO emoji, icons, or Unicode symbols in source code, output, or documentation
- NO stubs, placeholders, or fake data -- implement real functionality or mark clearly as TODO with explanation
- NO claiming code works without testing -- be honest about untested code
- NO moving forward when issues are unresolved
- NO spaces in file or folder names
- All output files must contain a timestamp in the filename (format: YYYYMMDD_HHMMSS)
- Never declare any iteration, MVP, or version "shipped," "closed," or "complete" until the staged load-bearing gate in SUCCESS_CRITERIA.md has passed: the v0.1a-core parser gate (parser unit tests + clean parse of two real sanitized configs) and the v0.1b check gate (exact seeded true positives, zero false positives, no verbatim secret in masked output). Because no production ASA device or client config is available, the faithful fixture plus the real sanitized configs are the "real call returns data" gate -- and that validation bound MUST be stated in every release note until a real engagement config has been run through the tool.

---

## Secret Hygiene

- API keys are plaintext `*.key.txt` files and live in `/home/cutaway/.claude/keys`, not in the project.
- `*.key.txt` is the first line of `.gitignore`. Never commit a key.
- The analyzed ASA config and all derived findings are sensitive client data. They stay local; the tool masks discovered secret values in output by default (SR-04).

---

## Code Quality Standards

Follow the standard code quality rules for this project's language. Reference
`claude-dev/code-standards/powershell.md` (CmdletBinding, parameter validation,
try/catch with `-ErrorAction Stop`, no `Format-*` mid-pipeline, version-gated
features, comment-based help, meaningful exit codes).

### Project-Specific Standards

- Target Windows PowerShell 5.1 as the feature floor; the tool MUST also run on PowerShell 7+. No installed modules -- built-in cmdlets only.
- Offline and read-only always: no network calls of any kind (SR-01); read the input, write only the report/CSV where directed; never modify the input or any device (SR-02).
- Process config content as inert text: no `Invoke-Expression` or dynamic evaluation (SR-06). Load bundled `.psd1` data with `Import-PowerShellDataFile` only (SR-08).
- Determinism (NFR-06): findings sorted by check id then line number; `InvariantCulture` for all comparisons/sorting; normalized line endings; Markdown report on stdout, status/diagnostics on a separate stream.
- Secret masking on by default, including a conservative keyword fallback for unparsed constructs; `-RevealSecrets` opt-in emits a credential-bearing warning (SR-04).
- Use Cutaway status prefixes on the status stream: `[+]` positive, `[-]` negative, `[*]` info, `[$]` report, `[x]` error (convention inherited from CHAPS as pattern, not content).
- Parser before checks: the v0.1a-core parser is proven in isolation before any check consumes it. Each check declares whether it reads raw or resolved model and carries confidence + dependency metadata.
- Every finding carries config evidence; a finding stands on its evidence, not on a possibly-`[unverified]` authority ID (SR-05).

---

## Branding and Website

Cutaway Security branding is the default. This is a CLI tool with no website; no
web scaffold is used. Note any deviation here.

---

## Project Content Lives in the Planning Docs

This file holds operating rules. Project-specific content lives in `claude-dev/` and is not duplicated here:

| Content | Home |
|---------|------|
| Technical constraints (protocols, platform, dependencies) | claude-dev/ARCHITECTURE.md (Constraints) + claude-dev/REQUIREMENTS.md (IR/AR) |
| Project scope (in / out) | claude-dev/VISION.md (What this is not) + claude-dev/REQUIREMENTS.md (scope / out of scope) |
| Security check catalog + parser grammar | claude-dev/CHECK_CATALOG.md |
| Prior art and research | claude-dev/20260624_asa-config-analysis_RESEARCH.md |
| Testing criteria and environment | claude-dev/REQUIREMENTS.md (testing) + claude-dev/SUCCESS_CRITERIA.md (test plan) + claude-dev/TEST_ENVIRONMENT.md |

---

## Communication Style

- Focus on substance, skip unnecessary praise
- Be direct about problems -- identify specific issues with line numbers
- Question assumptions and challenge problematic approaches
- Ground claims in evidence, not reflexive validation
- When stuck, explain what was tried and ask specific questions
- For human-facing deliverables (README, client reports, docs), avoid AI writing tells; the `humanizer` skill covers this

---

## Documentation Updates Required

When making changes, update the appropriate documents:

| Change Type | Update |
|-------------|--------|
| Architecture or constraint change | claude-dev/ARCHITECTURE.md |
| Phase completion | claude-dev/PLAN.md |
| Session activity | claude-dev/RESUME.md |
| Problem encountered | claude-dev/RESUME.md |
| Durable decision or lesson | claude-dev/VIBE_HISTORY.md |
| New or changed check | claude-dev/CHECK_CATALOG.md + README.md |
| Usage change | README.md |

---

## Session Workflow

### Starting a Session

1. Read CLAUDE.md (this file)
2. Read claude-dev/ARCHITECTURE.md
3. Read claude-dev/PLAN.md
4. Read claude-dev/RESUME.md
5. Read claude-dev/VIBE_HISTORY.md (newest entry)
6. State your understanding of current status
7. List proposed next steps
8. Wait for confirmation before proceeding

### During Development

1. Work on one task at a time
2. Test each change before moving on
3. Document issues in RESUME.md
4. Stop and ask if encountering persistent issues

### Ending a Session

1. Update claude-dev/RESUME.md with what was accomplished
2. Update claude-dev/PLAN.md with completion status
3. Add durable decisions or lessons to claude-dev/VIBE_HISTORY.md
4. List any blockers or open questions
5. Provide summary of session

---

## Note on Automation

The Session Workflow and Documentation Updates rules above are candidates for
automation via Claude Code hooks (a SessionStart hook to load context, a Stop
hook to enforce doc updates). Until those hooks are configured, follow them
manually.
