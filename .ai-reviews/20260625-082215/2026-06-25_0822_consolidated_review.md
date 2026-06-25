# Consolidated review — README.md accuracy + usability

**Date:** 2026-06-25 · **Reviewers:** anthropic (claude-opus-4-8), openai (gpt-5.4),
mistral (mistral-medium) · **Mode:** architecture, custom README prompt · **Bundle:**
35 files (README + src/ + data/ + tests/unit), 0 secrets, git-tracked. `claude-dev/`,
`background/`, and `tests/fixtures/` were excluded so the char budget reached the code
the reviewers needed to verify claims.

## Verdict

The README is accurate on the claims that matter — offline/read-only, the 58-check
count, the output triad, the flags, EoL behavior, the segmentation/HTML description all
hold up against the code (independently verified). The real gaps are **usability**, not
accuracy: no example output, no explanation of the severity tiers / `not-assessed`, no
at-a-glance facts block. A handful of small wording overclaims are worth tightening.

## Referee notes (findings dismissed or corrected)

- **mistral "catalog has 68 checks, fix 58 → 68" (its #1 MUST-FIX): WRONG.** I counted
  the `Id` entries in `data/check-catalog.psd1` — exactly **58**. anthropic and openai
  both verified 58. The README is correct; mistral miscounted. Dismissed.
- **openai "Companion docs / fixtures / validation corpus are missing" (its #1, #2, #3,
  #13): bundle artifacts, not README defects.** I deliberately excluded `claude-dev/**`
  and `tests/fixtures/**` from the review bundle, so the reviewer couldn't see them. The
  companion docs exist on `claude-dev`; the release procedure strips that section from the
  `main` README anyway. The fixtures exist; `tests/fixtures/real/` is intentionally
  gitignored (the README's "Validation bound" already says so). Dismissed as README
  issues — but two real kernels survive: the hardcoded "124 tests" number is brittle, and
  the quick-start mixes the dev test command into the user path (see S4).
- **mistral "SVG `xmlns` is an external reference, so 'no external references' is false"
  (its #3): pedantic non-issue.** A namespace declaration is not a fetched resource; the
  HtmlReport tests assert no `<script>`, `src=`, `href=`, or `@import`. Optional ultra-
  precision: say "no fetched external resources." Low value.
- **mistral/openai "ASA 9.x only / transparent / switchport overclaim": already hedged.**
  The README's "Where it works" already says pre-9.0 "may parse but are not a target,"
  transparent "parses, but a few interface checks assume routed L3," and switchport
  platforms "still parse, but interface-level checks are written for routed interfaces."
  No change needed beyond S1.

## Consensus findings (2+ reviewers, verified) — worth doing

- **C1 — Severity tiers + `not-assessed` are never explained (all three).** The report
  hinges on High/Medium/Low vs Informational (excluded from risk counts) and
  `not-assessed` (unresolved: undefined/circular/too-deep refs), but the README defines
  none of them. **Add a short "How to read the report" section** with a 4-tier table and a
  one-line `not-assessed` definition. Highest-value user fix.
- **C2 — No example output (all three).** Add a fenced sample: one Markdown finding block,
  the exact CSV header (`CheckId,Category,Severity,Status,Authority,Verified,Confidence,
  EvidenceLineNo,Evidence,Remediation,RemediationState,RemediationNotes`), and the three
  output filenames (`*_asa-review_<ts>.md/.csv`, `*_asa-report_<ts>.html`).
- **C3 — No at-a-glance facts block for AI agents (all three).** Add a compact markdown
  table (language, runtime, dependencies, input, outputs, scope, check count, license,
  network behavior). NOT YAML frontmatter — GitHub renders that poorly; a table serves
  humans and agents both.
- **C4 — Offline claim should be scoped to the review path (all three).** The "Makes no
  network calls at all" bullet is absolute; the repo contains the opt-in
  `Update-AsaEolData.ps1`. Add a parenthetical pointing at it as the sole, non-review
  exception (already explained in the EoL section).
- **C5 — Troubleshooting is thin (all three).** Add a short note: execution policy is
  per-session; PS 5.1 floor / 7+; status goes to stderr so `> out.md` captures only the
  report; "no findings" is not proof of secure.
- **C6 — "mapped to CIS/STIG" is too broad (anthropic + openai; verified).** 6 of 58
  checks carry `Authority = 'tool heuristic'`. Soften to "most checks map to the CIS …
  and DISA … STIG; a few are tool heuristics."

## Singleton findings with merit

- **S1 (anthropic) — "the analysis is the same regardless of appliance" is too strong.**
  Some checks are train-conditional (`MGMT-SSH-VERSION` is N/A on 9.16+ per
  `asa-defaults.psd1`; EoL depends on train). Soften to "the *parsing* is the same; some
  checks are version/train-conditional."
- **S2 (openai) — status "error/information stream" → "stderr".** Verified: the code uses
  `[Console]::Error.WriteLine`. Minor precision.
- **S3 (anthropic) — reconcile "58 checks" with the "MVP-15"/"v0.2" terms used in
  code/tests** so an agent doesn't report a 15-check tool. One sentence.
- **S4 (openai) — separate the dev test command from the user quick-start** (label it
  "Development / verification").

## Maintainer follow-ups (code, not README)

- Guard test description drift: `Guard.Tests.ps1` says "only Write-AsaReport performs file
  writes" but allows two writers (`Write-AsaReport`, `Write-AsaHtmlReport`). Stale comment.
- EoL `Hardware` array (`asa-eol.psd1`, ASA5515) is dead data — `Test-AsaVersionEol` only
  reads `Trains`. Consume it or drop it. (Already known.)
- `Protect-AsaLine`'s `(^\s*key\s+)(\S+)` over-masks any line starting with `key` —
  acceptable fail-safe for a masking tool, but it is masking-first, precision-second.
- `-Profile` shadows PowerShell's `$Profile` automatic variable (works; locally scoped).
- README "20,000-line benchmark" is accurate (standalone `Measure-AsaPerf.ps1` runs to
  20k); the bundled opt-in test only goes to ~16k. Reviewers flagged this only because the
  standalone script was excluded from the bundle. Optional one-line clarification.

## Recommended edit set (priority order)

1. **How to read the report** — severity-tier table + Informational-excluded note +
   `not-assessed` definition (C1).
2. **Example output** — Markdown finding + CSV header/row + output filenames (C2).
3. **At-a-glance facts table** near the top (C3).
4. **Scope/precision wording**: offline→review-path (C4); "most checks map to CIS/STIG,
   some heuristic" (C6); "parsing is the same, some checks train-conditional" (S1);
   "stderr" (S2); 58-vs-MVP-15 note (S3).
5. **Troubleshooting** note + separate the dev test command (C5, S4).
