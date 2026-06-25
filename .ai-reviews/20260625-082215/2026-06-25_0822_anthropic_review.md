# REVIEW: cisco-asa-review README.md (and code agreement)

## VERDICT

The README is unusually accurate for a project of this size. The headline claims that
matter most — offline/read-only, 58 checks, the output triad, the flags, the EoL
behavior, the segmentation/HTML description — all hold up against the code. I verified
the check count exactly. The few defects are real but narrow: one factual error in the
"Status" section about false positives, a misleading claim about how SSH/HTTP timeout
checks treat absence, and a self-contradicting "Where it works" caveat that the code
flatly disproves. Usability for analysts is the weaker dimension — there is no sample
output and no explanation of the severity tiers or "not-assessed," both of which the
code emits and the README leans on. For AI ingestion the README is strong; the
facts-block is split across prose and a table, but everything is falsifiable.

MUST-FIX accuracy items are few. Most findings are usability.

---

## ACCURACY FINDINGS (prioritized)

### A1 (MUST-FIX). "zero false positives" is overclaimed; the code's own gate is narrower
README "Status": *"the checks produce exact true positives and zero false positives on
the synthesized fixtures."*

The qualifier "on the synthesized fixtures" is present, which is honest — but the
sentence as a whole still reads as a general guarantee, and the catalog itself contradicts
a *general* zero-FP claim. Numerous checks are tagged `Confidence = 'heuristic'`
(`ACL-ANY-ANY`, `IF-URPF`, `ICMP-TO-DEVICE`, `ACL-IMPLICIT-DENY-LOG`, all `HYGIENE-*`,
`VERSION-EOL`, `DNS-LOOKUP`, `CRYPTO-PFS`). `IF-URPF` is a global absence check
(`'^ip verify reverse-path\b'`) that will fire on *any* config lacking that exact line
regardless of whether uRPF is appropriate — a textbook false-positive generator on real
configs. The Robustness test (`Robustness.Tests.ps1`) only asserts findings are
"well-formed," not correct.
**Corrected wording:** "…produce the exact expected true positives and zero false
positives *on the synthesized fixtures*. Many checks are heuristic (see `Confidence` in
the catalog) and will over- or under-flag on real configs; the hardened-fixture gate
bounds false positives only for the seeded scenarios."

### A2 (MUST-FIX). SSH/HTTP idle-timeout: README implies a missing timeout is flagged; the SSH code does not
README "How it works" and the catalog rationale for `MGMT-SSH-TIMEOUT`
("An SSH idle timeout greater than 5 minutes…"). The README's broader "absences …
(no `ssh version 2`…)" framing invites the reader to assume timeout absences are caught.
Code disagrees between the two checks:
- `Test-AsaSshTimeout` (structural.ps1): `if ($null -eq $line) { return @() }   # absent -> default 5 (ok)` — a *missing* `ssh timeout` is treated as compliant.
- `Test-AsaHttpTimeout`: a missing `http server idle-timeout` (when the http server is enabled) *does* fire.

This asymmetry is defensible (ASA SSH default is 5 minutes) but it is undocumented and
inconsistent with HTTP. Not a README error per se, but the README's absence-detection
narrative overgeneralizes.
**Corrected wording (README "How it works"):** add "Some absence checks assume a secure
ASA default and therefore do *not* fire when the setting is omitted (e.g. `ssh timeout`,
whose default is already 5 minutes); see each check's `Kind`/`Rationale` in the catalog."

### A3 (MUST-FIX). "Where it works" overclaims uniformity that the code's own checks break
README "Where it works": *"If your config is a single-context, routed-mode ASA 9.x
device, the analysis is the same regardless of which appliance produced it."* and the
parallel lead sentence.

This is too strong. The analysis is *not* model-independent even within routed-mode 9.x:
- `Test-AsaVersionEol` consults `data/asa-eol.psd1`, whose `Hardware` list flags
  `ASA5515` as end-of-support — model-specific behavior. (Also: the EoL *hardware* entry
  is never consumed by any check — see A6.)
- `MGMT-SSH-VERSION` is explicitly Not-Applicable on 9.16+ per
  `asa-defaults.psd1` (`VersionNote`), so the analysis differs by *train*, contradicting
  "the analysis is the same."
**Corrected wording:** "…the *parsing* is the same regardless of appliance model. A few
checks are version- or platform-conditional (e.g. SSH-version pinning is N/A on 9.16+;
EoL status depends on the train), so findings can differ across releases."

### A4 (minor). Quick-start uses `-Profile` which collides with PowerShell's auto-variable; works but undocumented risk
`Invoke-AsaReview.ps1` declares `[string]$Profile`. `$Profile` is an automatic variable
in PowerShell; using it as a parameter name is legal and scoped locally, so the script
works. But the README never notes this, and an analyst copy-pasting `-Profile` in a
wrapper that also reads `$PROFILE` could be confused. Not an error in behavior — flag for
the maintainer only. No README change strictly required.

### A5 (minor). README "Status" claims "124 Pester tests green" — unverifiable from the bundle, and the perf test is conditionally skipped
The 124 count cannot be confirmed (no test-count manifest), and `Performance.Tests.ps1`
is `-Skip` unless `ASA_RUN_PERF` is set, while the README says "plus an opt-in
performance test" (consistent). The "20,000-line benchmark" is asserted but the perf test
in-bundle runs to ~16k (`-Sizes 4000, 8000, 16000`); the standalone
`tests/perf/Measure-AsaPerf.ps1` is referenced but **not included** in the bundle.
**Corrected wording:** soften to "a benchmark confirms sub-quadratic scaling (the bundled
opt-in test exercises up to ~16k lines; the standalone benchmark covers larger inputs)."

### A6 (minor, code/data drift, not a README claim). EoL hardware list is dead data
`asa-eol.psd1` carries a `Hardware` array (ASA5515 end-of-support) and the README's
"Software version / end-of-life" section implies hardware EoL matters. But
`Test-AsaVersionEol` only reads `$eol.Trains`; nothing consumes `Hardware`. The README
does not explicitly promise hardware EoL findings, so this is drift to fix in code or to
mention as a limitation, not a hard README error. Recommend: either consume it or drop
the claim implied by the dated-hardware snapshot.

### A7 (verified correct — noted per instructions)
- **Check count "58 checks":** I counted the `Checks` array in `check-catalog.psd1`. It
  is exactly 58. **Correct.**
- **Flags `-Profile commercial|dod`, `-RevealSecrets`, `-ExpandAnyAny`:** all present in
  `Invoke-AsaReview.ps1` param block and wired through. **Correct.**
- **Outputs (Markdown stdout + timestamped file, CSV with remediation columns,
  self-contained HTML):** `Write-AsaReport.ps1` (md+csv, `RemediationState`/`RemediationNotes`)
  and `Write-AsaHtmlReport.ps1` confirm naming `*_asa-review_<ts>.{md,csv}` and
  `*_asa-report_<ts>.html`. **Correct.** (README says the HTML is `*_asa-report_*.html`
  — matches.)
- **Offline/no-network/read-only + Guard test:** `Guard.Tests.ps1` enforces the network
  blocklist and the write boundary, and asserts the review never calls the updater.
  **Correct.** `Update-AsaEolData.ps1` is the only `Invoke-RestMethod` user and is outside
  the review path. **Correct.**
- **HTML: inline SVG, no JS, no external refs, any-to-all-zones collapse,
  `permit ip any any` highlighting:** `Write-AsaHtmlReport.ps1` emits inline `<svg>`,
  embedded `<style>`, `ANY/ANY to ALL ZONES` badge, `cell-risk` matrix cells; the
  HtmlReport tests assert no `<script>`, no `src=/href=/@import`. **Correct.**
- **External references** (CIS ASA Benchmark, DISA ASA STIG, NP-View, Nipper, SANS Five
  ICS Controls 2 and 4): mapping to Control 2 (Defensible Architecture) and Control 4
  (Secure Remote Access) is a reasonable framing of the catalog's segmentation/management
  checks. Authorities like `STIG V-2399xx` and `CIS 1.x` are pervasive in the catalog.
  **Plausible and consistent**; nothing contradicts these in code.
- **Manual review checklist:** items 1–12 align with code limits (NAT not combined —
  confirmed `Get-AsaZoneModel` Notes; "only literal/expanded any/any auto-flagged" —
  confirmed `Test-AsaAclAnyAny`; `not-assessed` for circular/deep groups — confirmed
  `Resolve-AsaReferences`). **Correct.**

---

## USABILITY FINDINGS — End users / analysts (prioritized)

### U1 (high). No sample output. The README describes four artifacts but shows none.
An analyst cannot tell what a finding row looks like, what the CSV columns are, or what
the HTML matrix conveys before running it. Add a short fenced example of (a) one Markdown
finding block and (b) the CSV header line (`CheckId,Category,Severity,Status,Authority,
Verified,Confidence,EvidenceLineNo,Evidence,Remediation,RemediationState,RemediationNotes`
— straight from `Write-AsaReport.ps1`). This is the single highest-value edit for users.

### U2 (high). Severity tiers and "Informational excluded from risk counts" are never explained.
The code distinguishes High/Medium/Low (risk) from Informational (hygiene) and from
`not-assessed`, and the summary line prints "Findings: N (High/Med/Low) + Not-assessed".
The README never defines these tiers or states that Informational is excluded from the
risk count — yet the whole report hinges on it. Add a 4-row table: High / Medium / Low /
Informational (+ a line on `not-assessed`).

### U3 (high). "not-assessed" is used in the checklist (item 6) but never defined for a first-time reader.
Define it where it first matters: "`not-assessed` = the tool found the construct but could
not resolve it safely (undefined reference, circular or too-deep object-group); it is
neither a pass nor a finding and must be reviewed by hand." This mirrors
`Test-AsaNetworkGroupIsAny`/`Resolve-AsaReferences` behavior.

### U4 (medium). Troubleshooting is thin. PS 5.1 vs 7 and execution policy are mentioned only via the one-liner.
Add a short troubleshooting note: (a) `Set-ExecutionPolicy -Scope Process` is per-session;
(b) the tool targets 5.1 as the floor and also runs on 7+ (`#Requires -Version 5.1`);
(c) status lines go to stderr by design, so `> review.md` captures only the report (the
second `.EXAMPLE` already relies on this but the README body should say it explicitly).

### U5 (low). Ordering/scannability is good, but the long block-quote "Where this fits" sits above the Quick start.
Analysts want to run the tool first. Consider moving the vendor-comparison block below
Quick start or collapsing it. Minor.

---

## USABILITY FINDINGS — AI researchers / agents (prioritized)

### R1 (medium). The at-a-glance facts are split between prose and the requirements table; no single machine-readable block.
Language (PowerShell 5.1+), dependencies (none at runtime; Pester 5.x dev-only), input
(one ASA 9.x running-config), outputs (md/csv/html), scope (single-context routed 9.x),
check count (58), license (GPLv3) exist but are scattered. Add one compact "Facts" block
(or a single table) so an agent ingests it without inference. Everything needed is already
true in the repo; this is purely presentational.

### R2 (medium). "58 checks" vs "MVP-15" vs "v0.2 coverage" terminology will confuse an agent.
The catalog header still says "The MVP-15 security checks," the README says 58, and tests
reference "MVP-15" and "v0.2." An agent may report the tool as a 15-check tool. Add one
sentence: "The catalog now contains 58 checks; 'MVP-15' refers to the original core set,
retained as terminology in code/tests."

### R3 (low). "Offline" is stated absolutely but one script uses the network.
The README is careful ("the updater is the only network-using script… never invoked by a
review"), and `Guard.Tests.ps1` enforces it. This is fine, but an agent skimming the
"Makes no network calls at all" bullet could mis-summarize the repo as containing no
network code. Add a parenthetical at that bullet: "(the separate `Update-AsaEolData.ps1`
maintenance tool is the sole exception and is never part of a review)."

### R4 (low). Headings are stable and unambiguous; status/version are explicit (v0.2, dated). Good for ingestion. No change.

---

## TOP 5 RECOMMENDED EDITS (priority order)

1. **Add a sample-output block** (one Markdown finding + the exact CSV header) and a
   **severity-tier table** that states Informational is excluded from risk counts and
   defines `not-assessed`. (U1+U2+U3 — biggest user win.)
2. **Soften the "zero false positives" sentence** in Status to scope it to the synthesized
   fixtures and acknowledge heuristic checks (e.g. `IF-URPF`) over/under-flag on real
   configs. (A1.)
3. **Fix the "analysis is the same regardless of appliance" claim** to "parsing is the
   same; some checks are train/platform-conditional (SSH-version N/A on 9.16+, EoL by
   train)." (A3.)
4. **Document the absence-check default convention**, calling out that `ssh timeout`
   absence is treated as compliant while `http server idle-timeout` absence (with the
   server enabled) is flagged. (A2.)
5. **Add a single machine-readable Facts block** and a one-line note reconciling
   "58 checks" with the "MVP-15" terminology used in code/tests. (R1+R2.)

Minor follow-ups for the maintainer (not README edits): consume or drop the unused EoL
`Hardware` data (A6); reconcile the "20,000-line" benchmark claim with the bundled test's
16k ceiling and the missing `tests/perf/Measure-AsaPerf.ps1` (A5).