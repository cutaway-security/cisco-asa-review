# VIBE_HISTORY.md

AI session-continuity memory. Claude writes and reads this file for continuity
across sessions; it is not a document you are expected to maintain by hand.
Newest entry first. Durable decisions and lessons accumulate here over the
project's lifetime.

---

## 2026-06-25 -- examples/ + project-layout tree + tests off main (v0.2c)

Maintainer review of the repo raised three things, all addressed. (1) The README example output was inline-only — no committed artifacts. Added `examples/` with a REAL run of the tool against `tests/fixtures/asa-9x-insecure.txt` (md + csv + the self-contained HTML deliverable), stabilized the filenames (dropped the timestamp for linkability), leak-checked the output (no seeded secret in cleartext; redaction markers present), added an `examples/README.md`, and linked all three from the README. The HTML especially matters — it's the client deliverable and users couldn't see it without running the tool.

(2) `tests/` removed from `main`. The maintainer's call: tests are dev-only and an end user running a review doesn't need the Pester suite or fixtures. Updated RELEASE_TO_MAIN.md to exclude `tests` (added it to the `git rm -r --cached` line and the leak-check). Real consequence I had to design around: the release procedure used to run `pwsh -File tests/Invoke-Tests.ps1` on the orphan `main` tree to verify — impossible once tests aren't shipped. Moved that verify step to run on `claude-dev` BEFORE cutting `main`; it's equivalent because the release is a pure subset (src/ + data/ are byte-identical). Noted trade-off: the "clear this tool by running Guard.Tests yourself" assurance is no longer shippable on `main` — but that was my lean, not the decision.

(3) `data/` purpose was opaque. Kept the data/code separation as-is (deliberate: declarative `.psd1` loaded inertly, never moved into `src/`). Documented it instead. While checking, found that `asa-defaults.psd1` is NOT runtime-loaded — only a test audits it and the catalog comments cite it; it's doc-cited reference data, not engine input (same category as the dead EoL `Hardware` data). The README's new **Project layout** tree (placed before Status so readers who don't have questions can skip it) labels each `src/`/`data/` file's purpose and flags `asa-defaults.psd1` as "reference data; not loaded at runtime."

Released as v0.2c.

---

## 2026-06-25 -- README accuracy+usability review (multi-AI) and improvements

Ran `multi-ai-code-review` on the README (anthropic claude-opus-4-8 + openai gpt-5.4 + mistral-medium) with a custom prompt scoped to README accuracy (claims cross-checked against the code) and usability for two audiences: end users and AI researchers/agents. Key scoping lesson: the default bundle sent the big `claude-dev/` planning docs first and exhausted the 300k-char budget BEFORE the code the reviewers needed to verify claims (check-catalog, src, Invoke-AsaReview) — so I re-ran with `--exclude-glob 'claude-dev/**' 'background/**' 'tests/fixtures/**' 'tests/perf/**'`, which got the bundle to 35 files / ~67k tokens / 0 secrets, all git-tracked (real configs are gitignored and were never in scope). Always dry-run and read the file list; "context budget exhausted" on the files that matter means the review is flying blind.

Refereeing the three reviews mattered more than collecting them. Three reviewer errors had to be dismissed: (1) mistral's #1 "MUST-FIX: catalog has 68 checks, not 58" — I counted the catalog, it's exactly 58; mistral hallucinated. (2) openai's "Companion docs / fixtures / validation corpus are missing" — bundle artifacts: I had excluded those dirs, they exist; the release already strips the companion section from `main`. (3) mistral's "SVG xmlns is an external reference" — pedantic; a namespace is not a fetched resource and the tests assert no src/href/@import. The genuine signal was strong consensus (all three) on usability gaps: no example output, no severity-tier/`not-assessed` explanation, no at-a-glance facts block, and the absolute "no network calls" claim needing review-path scoping.

Applied the full consensus + precision edit set (README only — no tool-code changes, since those need separate test+verify): added an "At a glance" facts table; an "Example output" section generated from a REAL run of the tool against `tests/fixtures/asa-9x-insecure.txt` (147 lines, 58 checks, 39 risk + 5 informational), with the status stream, the report summary, a real finding block, and real CSV rows — explicitly noted as a synthesized fixture, not a live config (the user's instruction: generate the examples so they're accurate, and say it's not live); a "How to read the report" section (severity tiers, Informational excluded from risk counts, `not-assessed`); a "Troubleshooting" section; scoped the offline claim to the review path; softened "mapped to CIS/STIG" (6 of 58 checks are `tool heuristic`) and "analysis is the same regardless of appliance" (some checks are train-conditional); fixed "error/information stream" -> "stderr"; reconciled "58 checks" with the legacy "MVP-15" term.

The humanizer pass was intentionally dropped (maintainer call): the edit set is precision/structure, not voice, so de-AI-ing prose would overcomplicate a simple effort. Five tool-code follow-ups surfaced by the review are tracked in PLAN Phase 8 but NOT done here (stale Guard-test comment; dead EoL Hardware data; status-line "(High/Med/Low)" label that actually includes the 5 informational; broad `key` over-masking; `-Profile` shadows `$Profile`). These need their own test+verify pass.

---

## 2026-06-24 -- generalize to the ASA 9.x family + release v0.2 to main

The user asked whether the tool is 5515-specific or works on other ASA models. The honest answer (verified by grepping the source): it keys on ASA *software* syntax, not the chassis. The parser matches `^interface\s+(\S+)` (any interface token), interface roles derive from `nameif`/`security-level`, and the 58 checks map to CIS/STIG which are written against the software -- nothing in the logic is 5515-specific. The only model-specific datum is the `ASA5515` hardware entry in `data/asa-eol.psd1`, and it's DORMANT: `Test-AsaVersionEol` only evaluates `$eol.Trains` (the software train), never `$eol.Hardware`. The real boundaries are *mode* (single-context routed) and the older switchport platforms (5505 / integrated-switch 5506-X), not the model number.

So the user asked to generalize "5515" -> "ASA 9.x". Done:
- Renamed the four fixtures `asa-5515-*.txt` -> `asa-9x-*.txt` with `git mv` (content untouched -- critical, because the insecure fixture has line-number assertions; renaming a file doesn't shift line numbers, editing content would). Updated all filename references across 8 test files + `expected-findings.psd1` with sed. Suite stayed 124/1-skipped.
- README rewrite: moved Quick Start to the top (right after the description, per the ask); added a "Where it works" section enumerating the ASA family (5500-X, Firepower in ASA mode, ASAv) and the scope assumptions (single-context routed mode; switchport-platform and pre-9.0 caveats); refreshed Status (58 checks, 124 tests, perf-verified); dropped the 5515-origin references. Also fixed a STALE section: the README still described a separate Mermaid `.md` segmentation output, but that writer was removed in issue #1 -- the topology now lives only as inline SVG inside the HTML. Generalized scope wording in VISION / REQUIREMENTS / TEST_ENVIRONMENT / SUCCESS_CRITERIA; left the genuine historical record (DISCOVERY_NOTES, RESEARCH, background/goal.md) intact since the engagement really did start as a 5515 review.

Release decision: cut this as **v0.2** (not v0.1d). The body of work since v0.1c -- 15 -> 58 checks, HTML deliverable, EoL, deep resolution, perf -- is the v0.2 milestone the planning docs have been calling it all along, so the tag should match. Released to `main` per RELEASE_TO_MAIN.md (orphan rebuild, no Claude files), superseding v0.1c.

---

## 2026-06-24 -- v0.2 20k-line perf benchmark (NFR-04) + a real quadratic fix

NFR-04 is scoped to the parser ("no quadratic blowup or unbounded memory at ~20k lines") and is explicitly a NON-BLOCKING benchmark, not a v0.1 gate (TSC-10). Built `tests/perf/New-AsaLargeConfig.ps1` (deterministic large-config generator -- generated in memory, NOT committed as a fixture) and `tests/perf/Measure-AsaPerf.ps1` (times parse + full pipeline at 2.5k/5k/10k/20k, fits a log-log growth exponent AND a top-two-sizes doubling factor).

The benchmark earned its keep immediately: the PARSER was already cleanly linear (251ms at 20k, exponent ~0.55), but the full pipeline took **24.5s at 20k with a 4.28x doubling factor** -- quadratic. Root cause: `Get-AsaReferenceIndex` (the "is this ACL/object/object-group referenced anywhere?" pass behind the Informational hygiene checks) scanned EVERY line for EVERY entity -- O(entities x lines). On 20k lines with thousands of objects that's ~1e8 ops. Fixed by inverting it: one pass builds a `token -> nodes` hashtable, then each entity lookup touches only the handful of lines that actually mention its name. Same semantics (referenced = name appears as a whole token outside its own definition line), now linear: 20k pipeline **24.5s -> 5.1s**, doubling factor **4.28x -> 1.85x**. All hygiene/unused tests stayed green, so behavior is unchanged.

Lesson worth keeping: a log-log exponent fit over a range that starts BELOW the quadratic regime is a deceptive metric -- it read 1.25 ("passing") on the quadratic version because the small sizes have lots of fixed overhead and haven't entered n^2 yet. The doubling factor between the two largest sizes (which double in line count: ~2x linear, ~4x quadratic) is the honest, sensitive test. The verdict now requires BOTH (exponent <= 1.5 AND doubling <= 2.6x).

Note also that the two hygiene checks (`Test-AsaUnusedAcl`, `Test-AsaUnusedObject`) each call `Get-AsaReferenceIndex` independently, so it builds ~3x per review -- acceptable now that each build is linear (~175ms), not worth memoizing on the model (would mean mutating the input object).

`tests/unit/Performance.Tests.ps1` is an OPT-IN regression guard (runs only when env `ASA_RUN_PERF` is set) so the default 124-test suite stays fast and free of timing flakiness; it dot-sources the measurement script (guarded against `exit`, like the EoL updater) and asserts the sub-quadratic verdict. Default suite: 124 passed / 1 skipped. **v0.2 infrastructure is now complete.**

---

## 2026-06-24 -- v0.2 version/EoL (FR-15) + second fixture / anti-overfit (TR-05)

The interesting tension here: the user asked to "check the internet" for EoL data, but the load-bearing guarantee of this tool (SR-01, enforced by Guard.Tests) is that a config review makes ZERO network calls -- the config is sensitive client data. Resolution: split the concern. The REVIEW stays 100% offline and reads a bundled snapshot reference, `data/asa-eol.psd1` (dated 2026-06-24; trains 9.1-9.14 EoL, 9.16-9.22 supported; ASA5515 end-of-support; carries a disclaimer to verify against Cisco). The internet check lives in a SEPARATE, opt-in maintenance tool, `Update-AsaEolData.ps1` -- the only script in the repo that touches the network, deliberately run by the analyst on a connected machine to refresh the reference. Its flow is exactly the user's ask: "check the internet, if unavailable use reference" (fetch JSON feed -> rewrite reference; unreachable/invalid -> warn and keep the bundled one).

Guarding the boundary as code: `Update-AsaEolData.ps1` sits at repo ROOT, not in `src/` and not the entry point, so it is outside Guard.Tests's scanned `$ToolFiles` (correct -- it's allowed to use the network). Added a NEW Guard assertion that the review never *invokes* the updater (entry point + no src file references `Update-AsaEolData`), so the network tool can never be pulled into a review path.

Gotcha fixed: `EolData.Tests.ps1` dot-sources the updater to unit-test `Get-AsaEolFromWeb`, but the script's main body ends in `exit 0`, which would kill Pester. Wrapped the main body in `if ($MyInvocation.InvocationName -ne '.') { ... }` so dot-sourcing only defines the functions.

VERSION-EOL check (`Test-AsaVersionEol`, Medium): parses `ASA Version X.Y`, looks the train up in the bundled reference -- EoL -> finding, Supported -> none, unlisted -> not-assessed (OR-03). Hardened fixture had to move off 9.8 (correctly EoL) to `ASA Version 9.20(2)` for its TN.

TR-05 (second fixture / anti-overfit): rather than hand-author a third synthetic fixture (which would just re-encode my own assumptions), reused the two INDEPENDENT real sanitized configs (HQ-FW2, ASABuzzNick) already present for the TR-07 parser gate. `Robustness.Tests.ps1` runs the whole pipeline (model + zones + reference index + checks) on each and asserts no throw + well-formed findings + findings>0; skips if the gitignored real configs are absent (so CI without them stays green). Catalog now 58 checks. Suite 124/124.

Remaining v0.2 infra: only the 20k-line perf benchmark (NFR-04). On claude-dev; not released.

---

## 2026-06-24 -- v0.2 deep recursive resolution (FR-05b) + undefined references

Deepened `Resolve-AsaNetworkGroup`: was MaxGroupDepth=1 (returning "not-assessed" beyond one level); now MaxGroupDepth=16 with a visited-set CYCLE GUARD, so nested group-object chains resolve fully. "not-assessed" (OR-03) is now reserved for genuinely-unresolvable cases: a circular reference, an undefined group, or the 16-deep backstop. This sharpens ACL-ANY-ANY (a deeply-nested object-group that spans 0.0.0.0/0 is now caught as a finding instead of not-assessed) and the zone model.

New check REF-UNDEFINED (code, Medium): flags rules referencing an object/object-group that is not defined (dangling reference -- typo or deleted object). Token-based walk (skip definition headers; match the standalone `object`/`object-group`/`group-object` tokens, NOT the 'object' inside 'network-object'/'service-object'/'object-group'). Catalog now 57 checks. Note: bare object names in twice-NAT (no `object` keyword) are intentionally not flagged (conservative -- avoid false positives).

Test updates driven by the behavior change: the old "deep nesting -> not-assessed" assertions (SupportModels + Checks) now assert deep nesting RESOLVES (FR-05b), and a CYCLE is the not-assessed case (new tests for both). TP for REF-UNDEFINED via a `permit ip any object-group MISSING-GRP` line added to the coverage fixture; TN on insecure/hardened (all refs defined). Suite 115/115.

Remaining v0.2 infra: version/EoL table (data-source decision needed), second fixture, 20k perf. On claude-dev; not released.

---

## 2026-06-24 -- v0.2 catalog coverage, Slice 7: interface hardening (COMPLETE)

Slice 7 = 4 checks (3 absent + 1 present): IF-SCANNING-THREAT (absent threat-detection scanning-threat), IF-THREAT-STATS (absent threat-detection statistics), IF-SAME-SECURITY (present same-security-traffic permit), DNS-LOOKUP (absent name-server). Catalog now 56 checks. This COMPLETES the commercial catalog-coverage slices (1-7).

TP: scanning-threat/threat-stats/dns-lookup on insecure (it has basic-threat only, no scanning/statistics; dns server-group with no name-server); same-security on coverage. TN on hardened: it already had scanning-threat; appended `threat-detection statistics tcp-intercept ...` and a `dns server-group / name-server`; no same-security-traffic. Added `same-security-traffic permit inter-interface` to coverage for the TP. Skipped DNS-GUARD (default-on in modern ASA makes absence-detection unreliable) and FAILOVER (design-dependent; would false-positive on single-device configs).

(Note: the user's message said "Slice 6" but Slice 6 was already done; interpreted as Slice 7 and flagged it.)

Catalog coverage summary: 56 checks = 15 MVP + 36 v0.2 (S1-7) + 5 hygiene, across management/auth/logging/crypto/access. Commercial-relevant CIS+STIG coverage done. DoD-profile-specific checks (FIPS, exact DoD banner text, split-tunnel-tunnelall, RSA modulus, account-of-last-resort) remain an optional follow-on under the `dod` profile. Remaining v0.2 infra: deep resolution (FR-05b), version/EoL table, second fixture, 20k perf. Suite 113/113. On claude-dev; not released.

---

## 2026-06-24 -- v0.2 catalog coverage, Slice 6: access control (gate passed)

Slice 6 = 3 checks: ACL-IMPLICIT-DENY-LOG (code, per bound ACL: no trailing `deny ip any any log` -> silent implicit deny), ICMP-TO-DEVICE (absent: no `icmp permit/deny` control statements), SYSOPT-PERMIT-VPN (present: decrypted VPN bypasses interface ACL). Catalog now 52 checks.

TP: ACL-IMPLICIT-DENY-LOG + ICMP-TO-DEVICE on insecure (its bound ACLs lack a logged deny; no icmp control); SYSOPT-PERMIT-VPN on coverage. TN on hardened: it already had `deny ip any any log` on both bound ACLs; appended `icmp deny any outside` (it had no icmp control, would have fired); no sysopt permit-vpn. Added `sysopt connection permit-vpn` to coverage for the TP. The implicit-deny-log detector emits one finding per bound ACL missing the logged deny (3 on insecure: outside_in/inside_in have no deny, dmz_in has `deny ip any any` without `log`).

Suite 113/113. ~1 catalog slice left (interface-hardening) + 4 infra items. On claude-dev; not released.

---

## 2026-06-24 -- v0.2 catalog coverage, Slice 5: logging/monitoring (gate passed)

Slice 5 = 4 checks (2 code + 2 data): LOG-BUFFER-SIZE (code: logging buffered on with buffer-size <512KB or absent/default), NTP-REDUNDANT (code: ntp configured with <2 servers), THREAT-DETECTION-BASIC (absent), SNMP-V3-NOPRIV (present: snmp-server group v3 noauth/auth, i.e. not priv). Catalog now 49 checks.

TP: LOG-BUFFER-SIZE on insecure (logging buffered, no buffer-size); NTP-REDUNDANT/THREAT-DETECTION-BASIC/SNMP-V3-NOPRIV on coverage. TN on hardened: appended `logging buffer-size 524288` and a 2nd ntp server (it had 1, NTP-REDUNDANT would have fired); it already had threat-detection basic-threat and snmp v3 priv. Added a single ntp server to coverage so NTP-REDUNDANT has a clean TP. The high-value logging checks were front-loaded (enable/host/timestamp/trap/console/community), so the remaining ones here are lower-severity (mostly Low) -- a deliberately smaller slice.

Suite 113/113. ~2 catalog slices left (access-control, interface-hardening) + 4 infra. On claude-dev; not released.

---

## 2026-06-24 -- v0.2 catalog coverage, Slice 4: crypto strength (gate passed)

Slice 4 = 5 crypto-strength checks, all DATA-DRIVEN (present patterns, no code): CRYPTO-IKE-INTEGRITY (SHA-1 in IKE), CRYPTO-IPSEC-INTEGRITY (esp-sha-hmac), CRYPTO-DH-14 (group 14 < 16), CRYPTO-AES128 (aes/aes-128 instead of aes-256), CRYPTO-SSL-CIPHER (rc4/des/3des/null or low/medium ssl cipher). Catalog now 45 checks.

Scoped to avoid overlap with the existing CRYPTO-WEAK-VPN (which already flags des/3des/md5/group 1-2-5): IKE-INTEGRITY is SHA-1-only (md5 stays with weak-vpn); DH-14 is group-14-only (1/2/5 stay with weak-vpn). Regex care: `^encryption aes(\s|$)` matches plain AES-128 but NOT `aes-256` (the '-' defeats the alternation); `group 14` vs `group 1` handled by `\b`.

TP: CRYPTO-SSL-CIPHER fires on insecure (it has `ssl encryption rc4-sha1 ...`); the other 4 fire on a new weak-crypto block appended to the coverage fixture (ikev1 policy with hash sha / group 14 / encryption aes + transform-set esp-aes esp-sha-hmac). TN: all 5 clean on hardened (aes-256 / sha384 / group 20 / ssl cipher high). No hardened changes needed this slice. Suite 113/113.

~3 catalog slices left (logging/monitoring, access-control, interface-hardening) + 4 infra items. On claude-dev; not released.

---

## 2026-06-24 -- v0.2 catalog coverage, Slice 3: AAA depth (gate passed)

Slice 3 = 8 AAA checks (6 data-driven absent + 2 code): AUTH-ENABLE-PW, AUTH-AAA-ENABLE, AUTH-AAA-HTTP (code, conditional on http server enable), AUTH-CMD-AUTHZ, AUTH-CMD-ACCT, AUTH-PW-COMPLEXITY (code, fires if any of minimum-upper/lower/numeric/special missing), AUTH-PW-LIFETIME, AUTH-BANNER-MOTD. Catalog now 40 checks (15 MVP + 20 v0.2 + 5 hygiene).

TP split: insecure triggers cmd-authz/acct, pw-complexity, pw-lifetime, motd (it has no command authz/acct, no full password policy, no motd banner); coverage triggers enable-pw, aaa-enable, aaa-http (no enable password, no aaa block; added `http server enable` to coverage so the conditional aaa-http fires). TN: appended to hardened `aaa authorization command`, `aaa accounting command`, `password-policy lifetime 90` (it already had the complexity lines + motd banner + enable pw + aaa enable/http). Hardened "zero risk findings" gate still holds. Suite 113/113.

Pattern reminder: when a new ABSENT check would otherwise fire on the hardened baseline (because hardened lacked that one good line), append the good line to hardened. All fixture appends are safe (no hardened/coverage line-number assertions).

~4 catalog slices left (crypto-strength, logging/monitoring, access-control, interface-hardening) + 4 infra items (deep resolution, version/EoL, second fixture, perf). On claude-dev; not released.

---

## 2026-06-24 -- v0.2 catalog coverage, Slice 2 (gate passed)

Slice 2 = 4 numeric/conditional CODE checks (the ones that can't be pure data): MGMT-SSH-TIMEOUT (ssh timeout >5), MGMT-HTTP-TIMEOUT (http server enabled AND idle-timeout missing-or->5), CRYPTO-PFS (crypto map present but no set pfs), CRYPTO-SA-LIFETIME (lifetime seconds >86400). Detectors in checks/structural.ps1; catalog Type='code'. Catalog now 32 checks.

TP: ssh-timeout/http-timeout/pfs already in the insecure fixture; SA-lifetime via a new ikev2 policy (lifetime seconds 172800) appended to asa-9x-coverage.txt. TN: hardened already clean EXCEPT it lacked an http idle-timeout (the conditional HTTP check would have fired) -> appended `http server idle-timeout 5` to hardened. Both fixture appends are safe (no hardened/coverage line-number assertions). Coverage.Tests TP/TN lists extended. Hardened "zero risk findings" gate still holds. Suite 113/113.

Pattern holding well: hardened = clean baseline (append a good line when a new conditional check needs it), insecure = broad TP, coverage = the few cases insecure lacks. On claude-dev; not released.

---

## 2026-06-24 -- v0.2 catalog coverage, Slice 1 (gate passed)

Started the v0.2 catalog expansion. Slice 1 = 8 data-driven checks added as pure CATALOG DATA (no engine code -- the declarative-catalog payoff, MR-01): MGMT-SSH-OUTSIDE (present), AUTH-AAA-SERIAL/LOG-TIMESTAMP/LOG-TRAP/AUTH-PW-LOCKOUT/IF-URPF (absent), LOG-CONSOLE/SNMP-V3-WEAK (present). Catalog now 28 checks (15 MVP + 8 v0.2 + 5 hygiene).

Method that makes catalog growth sustainable: the HARDENED fixture is the clean true-negative baseline -- it already satisfied all 8 (so TN is free); 6 of the 8 true-positives are already present in the INSECURE fixture (it lacks the good lines), and the remaining 2 (console logging, weak SNMPv3) got a small dedicated `asa-9x-coverage.txt`. `Coverage.Tests.ps1` asserts TP on insecure/coverage and TN on hardened, plus catalog integrity (unique ids, known severities). The hardened "zero risk findings" gate still holds.

Had to generalize one brittle test: "exactly 15 risk checks fire on insecure" -> "all 15 MVP fire" (subset). The exact count can't hold as the catalog grows; MVP completeness is still asserted, and Coverage.Tests covers the new checks precisely.

Suite 113/113. On claude-dev; not released. Next slices: more catalog checks (AAA complexity, crypto PFS/integrity, mgmt timeouts -- some need numeric/code detectors), then deep resolution, version/EoL, second fixture, perf.

---

## 2026-06-24 -- Phase 6 / GitHub issue #1 BUILT (gate passed)

All 7 issue-#1 items delivered (108/108 tests; on claude-dev, not yet released).

- **Reference index** (`Get-AsaReferenceIndex.ps1`): an entity is "referenced" if its name appears as a whole token on any non-definition line -- conservative (prefers NOT flagging; under-flagging unused is the safe direction). Verified on the real insecure fixture: `unused_acl`/`partner-fqdn`/`routing-protos`/`nested-admins`/`legacy-ports` flagged; `split_tunnel` (crypto-map + group-policy referenced) NOT flagged -- the crypto-only-ACL guard works on real data.
- **Five hygiene detectors** (Informational) in `checks/structural.ps1`: unused ACL, unused object/object-group, inactive (`inactive` keyword + expired `time-range` via `absolute end` date parse), interface no-ip-not-shutdown, BVI-without-bridge-group.
- **Engine change**: code detectors may now return MANY detections -> one finding per entity (so each unused object is its own CSV row, for tracking). Existing single-detection code checks unchanged.
- **Informational tier**: SeverityRank=3, excluded from High/Med/Low risk counts in MD + HTML; CSV includes them.
- **CSV** (DR-02a): added `RemediationState` (default Open) + `RemediationNotes` (empty) for team tracking.
- **HTML** (FR-37): added a full "Findings detail" section -- every finding with ALL evidence lines, rationale, remediation, rendered natively -> the HTML is now the complete report (the summary table showed only the first evidence line before).
- **Removed** `Write-AsaSegmentation.ps1` and the segmentation `.md` output (FR-38); segmentation lives only in the HTML (inline SVG + matrix). Outputs are now md + csv + html.

**Edges found while building**: (1) bridge-group MEMBER interfaces legitimately have no IP -> the no-ip check must skip them (added `bridge-group` exclusion) -- surfaced by authoring the hygiene fixture. (2) The "exactly 15 MVP" test had to become "all 15 MVP fire (15 non-Informational risk checks)" since hygiene checks now also fire; the hardened zero-FP test scoped to RISK severities (an unused object-group on hardened is a legitimate Informational finding).

Fixtures: added `asa-9x-hygiene.txt` (precise TP/TN incl. crypto-only ACL, expired vs active time-range, shutdown/bridge-member/IP-bearing interfaces, BVI with/without member); existing insecure/hardened fixtures left unchanged (the hygiene checks run on them and their incidental unused items are correctly flagged).

Verified end-to-end: 3 outputs (md/csv/html, no segmentation .md); CSV carries the tracking columns + Informational rows; HTML rendered via WebKit and visually inspected -- full detail + INFO-styled hygiene findings display well.

Still open in Phase 6: the v0.2 catalog coverage (remaining CIS/STIG checks, deep resolution, version/EoL, second fixture).

---

## 2026-06-24 -- Phase 6 planning: GitHub issue #1 folded into v0.2 coverage

GitHub issue #1 "Feature Requests" (Don C. Weber) bundled 7 items; reviewed and triaged with the maintainer, all six open decisions confirmed, folded into Phase 6 (worked alongside v0.2 coverage). NOT built yet -- planning only; awaiting review before code.

Items -> disposition:
- Unused ACLs / unused objects+object-groups / inactive rules -> three Informational hygiene checks driven by a new REFERENCE INDEX (FR-31) that maps ACL/object/object-group/time-range to ALL reference sites. "Unused" must mean unreferenced anywhere (access-group AND crypto map / NAT / nested groups) -- checking only access-group would false-positive on a crypto-only ACL (now an explicit zero-FP success criterion, TSC-15).
- Interface `no ip address` not shut -> check (FR-35). BVI without a matching `bridge-group` -> unused check (FR-36).
- New Informational severity tier (below Low; tracked in CSV, excluded from risk counts).
- Artifact roles locked by the maintainer: HTML = full deliverable (report + visual review), Markdown = consolidation + future AI review, CSV = tracking. CSV extended (DR-02a) with Informational rows + RemediationState (default Open) + RemediationNotes (team fills later).
- HTML becomes the COMPLETE report (FR-37): full findings detail with ALL evidence lines rendered natively after the summary/visuals (the current HTML only shows the first evidence line).
- Segmentation Markdown (Mermaid) output removed (FR-38); `Write-AsaSegmentation.ps1` retired; the segmentation visual lives only in the HTML (inline SVG + matrix). The zone model is retained.

Planning updated: REQUIREMENTS FR-31..FR-38 + DR-02a + Informational tier; ARCHITECTURE §7c (reference index, Informational, CSV, HTML full report, segmentation removal) + module layout (add Get-AsaReferenceIndex.ps1, remove Write-AsaSegmentation.ps1); SUCCESS_CRITERIA TSC-15..TSC-17; PLAN Phase 6 expanded + 4 decision-log rows. Fixtures to be extended at build time (unused/crypto-only ACL, unused object/group, inactive + expired-time-range ACE, no-ip interface, bridge-group-less BVI).

Per the maintainer's gated process: plan updated -> await review -> then build.

---

## 2026-06-24 -- Released v0.1c to main

Re-cut `main` per RELEASE_TO_MAIN.md (orphan rebuild from claude-dev 7406e6d):
release files only, no Claude files (CLAUDE.md/claude-dev/.ai-reviews/background
excluded), release-variant README (no claude-dev links, Status updated to v0.1c),
103/103 tests green on the release tree, force-pushed `main`, tagged **v0.1c**
(previous tag v0.1b retained). v0.1c = MVP checks + segmentation visualization +
self-contained HTML deliverable + any-to-all-zones collapse. `v0.2` deliberately
reserved for the planned coverage milestone, so this additive release is v0.1c.

---

## 2026-06-24 -- Phase 5c: any-to-all-zones collapse (default), -ExpandAnyAny opt-in

A `permit ip any any` fans out to every zone, producing a red-arrow hairball in the topology. At the maintainer's request, collapse is now the DEFAULT and expansion is opt-in.

- `Get-AsaZoneModel.ps1` computes `CollapsedSources`: a source whose any-any reaches every other zone (>=2 destinations). Centralized so the HTML SVG and the Mermaid topology stay consistent.
- Both topologies: by default, a collapsed source's individual any-any edges are suppressed and the node gets a single "ANY/ANY to ALL ZONES" badge (red SVG pill / Mermaid label suffix). `-ExpandAnyAny` (threaded through `Invoke-AsaReview.ps1`) draws every individual flow. The matrix and risk-flow list ALWAYS remain exhaustive -- collapse only de-clutters the diagram; the full detail is never hidden.
- Tests: zone-model CollapsedSources; HTML/Mermaid collapse-default + expand-differential (expanded has more red edges/linkStyles + no badge). Existing Mermaid tests updated (default no longer draws the any-any edges). Suite 103/103.
- Verified by rendering: the default (collapsed) HTML renders clean -- two badged zone boxes instead of an 8-arrow hairball.
- Robustness fix found in testing: the entry point now creates a missing `-OutputDirectory` (writers previously threw on a nonexistent dir).
- Design note: collapse threshold is "reaches every other zone, >=2 dests"; partial any-any (to specific zones) still draws as arrows. The matrix/list are the always-on "expansion."

**Status**: on `claude-dev` only; NOT released to `main`.

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

- `tests/fixtures/asa-9x-insecure.txt` -- known-bad fixture, construct-complete (every CHECK_CATALOG Part B construct incl. B6 legacy `object-group service tcp` + `port-object`, `object-group protocol`, `nt-encrypted`/cleartext/encrypted/pbkdf2 secrets, 3-deep `group-policy attributes` -> `webvpn` -> `anyconnect`, object-NAT + twice-NAT, global webvpn). Triggers all 15 MVP findings.
- `tests/fixtures/asa-9x-hardened.txt` -- true-negative fixture; triggers none of the 15; multi-line `banner login` for the parser reassembly test; strong ikev2 crypto, SNMPv3, authenticated NTP, uRPF.
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
