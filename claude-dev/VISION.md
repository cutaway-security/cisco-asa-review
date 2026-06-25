# VISION.md — cisco-asa-review

**Author:** Cutaway Security (Don C. Weber) · drafted via cutsec-init
**Date:** 2026-06-24
**Status:** Draft (pre multi-AI validation)

---

## 1. Vision

By the end of 2026, a Cutaway analyst reviewing a Cisco ASA firewall hands the
device's `running-config` to a single PowerShell tool that runs entirely on the
analyst's own machine — no internet, no upload, no device access — and gets back
a clear, prioritized, authority-mapped findings report (Markdown for the human,
CSV for tracking) within seconds. The analyst is the user; the analyst's
workstation is the substrate; the posture is offline-first and read-only because
the configuration is sensitive client data that must never leave the host. The
tool turns a tedious, error-prone manual line-by-line review into a repeatable
first pass that surfaces the issues that matter and shows the exact config line
that proves each one.

## 2. Why a tool, not a one-off script

The obvious alternative is to grep the config a few times per engagement and
eyeball the rest. That is what most reviewers do, and it is why ASA reviews are
inconsistent: the findings depend on which fifteen things the reviewer remembered
to look for that day. The research survey (`20260624_asa-config-analysis_RESEARCH.md`)
confirmed the structural reason a real tool wins:

- ASA config is a **hierarchical, reference-laden grammar** (object-groups nested
  in object-groups, ACLs referencing objects referencing names). Half the
  high-value findings — unused objects, undefined references, overly-broad rules,
  cleartext secrets buried in sub-blocks — are invisible to flat grep and only
  fall out of a proper parse-and-resolve pass.
- A large fraction of findings are **absences** (no `logging enable`, no `ssh
  version 2`, no uRPF). You cannot grep for a line that is not there; you need a
  model that knows what should be present and reasons over what is missing.
- The check catalog worth applying (CIS ASA + DISA ASA STIG) is **~80 checks**,
  too many to hold in a reviewer's head and apply uniformly every time.

A parser plus a declarative check catalog makes the review **repeatable,
explainable, and complete** in a way ad-hoc scripting never is. The investment is
in the parser and catalog once; every future ASA engagement draws on it.

## 3. Principal map

| Principal | Role | Cares about |
|-----------|------|-------------|
| The Cutaway analyst (primary user) | Runs the tool during an engagement | Speed, accuracy, low false positives, evidence per finding, offline safety |
| The client (firewall owner) | Subject of the review | Confidentiality of the config; a defensible, actionable assessment |
| Report reader (client IT / management / compliance) | Consumes the deliverable | Findings tied to recognized authority (CIS, DISA STIG) with clear remediation |
| Don C. Weber / Cutaway | Tool owner, methodology authority | A reusable asset that raises the floor on every ASA review and reflects Cutaway's standards |

## 4. Strategic bets

**Bet 1 — Offline static analysis covers the findings that matter.**
*Claim:* the high-value ASA review findings (management exposure, weak crypto,
permissive rules, missing logging/hardening, cleartext secrets) are all derivable
from the static `running-config` alone. *Why right:* the prior-art survey shows
every offline parser plus the CIS/STIG catalogs operate purely on config text;
the only checks needing a live device are hitcount-based (rule usage). *How wrong:*
if a client's real question is "which rules are unused," static analysis cannot
fully answer it. *Mitigation:* scope rule-usage analysis out explicitly (VISION
§6), and document that hitcount review needs device data.

**Bet 2 — PowerShell is the right and sufficient substrate.**
*Claim:* a pure-PowerShell tool (5.1 floor, 7+ compatible, no modules) meets the
analyst's constraint and is enough to build a real hierarchical parser and check
engine. *Why right:* the constraint is hard (no online tools, PowerShell is what
runs on the host); text parsing needs no external dependencies. *How wrong:*
PowerShell string/regex performance on very large configs could disappoint, or
the parser could get awkward versus a "real" parsing language. *Mitigation:*
design the parser as plain object trees, benchmark against a large fixture, keep
regex anchored and simple.

**Bet 3 — A declarative, authority-mapped check catalog is the durable core.**
*Claim:* separating the check catalog (data) from the engine (code) is what makes
the tool maintainable as benchmarks change. *Why right:* CIS/STIG revisions move;
a data-driven catalog absorbs that without engine rewrites. *How wrong:* some
checks are too structural to express as data and leak into code. *Mitigation:*
accept a hybrid — data for simple presence/absence/pattern checks, code for
structural checks (ACL shadowing, object resolution) — and keep the boundary
explicit.

**Bet 4 — Evidence-per-finding is non-negotiable for trust.**
*Claim:* every finding must cite the exact config line(s) that prove it. *Why
right:* analysts must verify before reporting to a client; unexplained findings
get discarded. Authority IDs in the research were partly `[unverified]`, so the
config evidence — not the citation — is what makes a finding defensible. *How
wrong:* evidence extraction adds complexity. *Mitigation:* the parser retains
line numbers and raw text on every node, so evidence is free.

## 5. The arc

<!-- AI review 20260624-094932: anthropic+mistral — v0.1 split into v0.1a/v0.1b to derisk the load-bearing parser in isolation before checks are built on it. -->

**v0.1a-core — Parser foundation (derisk the load-bearing component first).** A
working PowerShell hierarchical ASA config parser: indentation tree +
repeated-prefix index + `name` map + verbose dump. No checks, no classifier, no
defaults model in this slice — those are check-enablement with different failure
modes and must not share the parser gate. Gate: 100% parser unit tests pass AND
the parser cleanly parses two real sanitized ASA configs (obtained and stored
locally as a one-time step). This breaks the fixture-as-oracle circularity: the
parser is proven against real device output, not only self-authored material.
<!-- AI review 20260624-101250: anthropic+openai — v0.1a narrowed; classifier/defaults/resolution moved to v0.1b prep. -->

**v0.1b — MVP checks + output.** First the v0.1b-prep models (minimal
object/group resolution, password-hash classifier, a doc-cited ASA defaults
model, and a shared interface-role model — each gated separately), then the 15
high-signal MVP checks (RESEARCH §4 shortlist), presence and *context-conditional*
absence, built on the proven parser. Markdown + CSV output with secret-value
masking on by default (including a conservative fallback mask and a no-leak gate).
Proven against a synthesized, syntactically faithful ASA 9.x fixture (exact
expected findings, zero false positives on good instances).

**v0.2 — Coverage (the full catalog).** The remaining CIS + DISA STIG checks
across all seven categories, absence-aware, with authority mapping and severity.
Deep recursive object resolution; undefined-reference and unused-object
detection. A second, independently authored fixture to guard against overfitting.

**v0.3 — Depth (analysis + polish).** ACL redundancy/shadowing (ASA-ACL-toolkit
approach), version/EoL lookup table, report-quality improvements, performance
hardening on large configs, optional finding suppression/baseline.

**Check profiles (decided now, not later).** Because the primary target is an
*enterprise/commercial* ASA, the default profile is **commercial** (CIS-weighted).
DoD/STIG-specific checks that produce noise on a commercial device (FIPS mode,
exact DoD banner text, mandatory split-tunnel-tunnelall, VPN DoD banner) live in
an opt-in **DoD/STIG profile**. The catalog carries a profile field so the
distinction is data, not hardcoded assumption.
<!-- AI review 20260624-094932: anthropic — commercial-vs-DoD profile made explicit before the catalog hardcodes DoD assumptions. -->

## 6. What this is not

- **Not a live auditor.** It never connects to a device, never needs SSH, never
  reads hitcounts. Rule-usage ("is this rule unused?") is out of scope — that
  needs device data.
- **Not a dataplane/reachability modeler.** It does not compute end-to-end
  reachability or simulate traffic (that is Batfish's domain). The planned
  segmentation/data-flow visualization (Phase 5) shows *configured/allowed flows
  per the ruleset*, explicitly labeled as such — it is a segmentation map, not a
  reachability proof.
- **Not multi-vendor.** ASA 9.x only. Not IOS, not FTD/Firepower, not PIX-era,
  not other firewalls.
- **Not a remediation tool.** It reports; it never modifies a device or generates
  config changes to push.
- **Not an online/SaaS service.** No upload, no API, no telemetry. Offline is the
  point.
- **Not a compliance certification.** It maps findings to CIS/STIG as guidance,
  not as an audited attestation.

## 7. What success looks like at the horizon

<!-- AI review 20260624-101250: openai+anthropic — efficacy claims weakened to match the fixture-bound validation base; target-device vs product scope separated. -->

*Scope note:* the tool targets the **ASA 9.x `show running-config` syntax**, which
is set by the ASA software version rather than the appliance model — so it applies
across the ASA family (5500-X series, Firepower in ASA mode, ASAv) running ASA 9.x,
in **single-context routed mode**. Its validation base is synthesized ASA 9.x
fixtures plus independent real sanitized configs; broader reuse is earned as more
real configs are run through it, not claimed up front.

- An analyst runs one PowerShell command against an ASA config and, in under a
  few seconds, receives a Markdown report and CSV with prioritized findings, each
  citing its config evidence and mapped to CIS/STIG guidance.
- The tool reproduces, **on the validation fixture**, the seeded findings exactly
  (true positives) with zero false positives on the good instances — and parses
  real sanitized configs without choking. Expert-equivalence on arbitrary real
  configs is a goal to be earned through independent validation, not a claim the
  current evidence supports.
- A second analyst running the same tool on the same config gets the same
  findings (repeatability the manual process lacks).
- The check catalog can absorb a CIS/STIG revision by editing data, not rewriting
  the engine.
- Nothing about the client's config ever leaves the analyst's machine.
