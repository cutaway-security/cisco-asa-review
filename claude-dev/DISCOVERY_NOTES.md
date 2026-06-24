# DISCOVERY_NOTES.md — cisco-asa-review

Structured extraction from `background/goal.md` and the initiation conversation
(2026-06-24). Single source of truth for subsequent phases. No drafting here.

## Goal as stated

> "Build a PowerShell-based tool to analyze a Cisco ASA 5515 firewall
> configuration dump ... I need a script to help me analyze this."
> — engagement framing, `background/goal.md`

> "I cannot use online tools, but I can run PowerShell scripts. Hence, the
> analysis will need to work in PowerShell." — user, initiation chat

## Principals

| Who | Role | Cares about |
|-----|------|-------------|
| The analyst (user, Cutaway Security) | Performs the firewall config review | A fast, repeatable, offline way to surface security issues in an ASA config and produce client-ready findings |
| The client (firewall owner) | Owns the ASA 5515 | An accurate, defensible assessment of their firewall posture; confidentiality of their config |
| Report reader (client management / compliance) | Consumes findings | Findings mapped to recognized authority (CIS, DISA STIG) with clear recommendations |

## Technical environment

- **Target device:** Cisco ASA 5515-X. ASA software family 9.x era.
- **Input:** a text configuration dump, produced by `show running-config`
  (or a saved startup-config). Single file, ASA CLI syntax.
- **Analysis host:** an analyst workstation with PowerShell available. Windows
  PowerShell 5.1 is the safe floor; PowerShell 7+ may also be present.
- **No network path to the device** is assumed or needed — analysis is purely
  static/offline over the captured text.

## Explicit asks

- A PowerShell script/tool that analyzes the ASA config for security issues.
- Research existing open-source ASA config analysis tools first (prior art).

## Scope signals

- **In:** offline static analysis of a single ASA config file; security findings;
  reviewable report output.
- **Out (implied):** live device interrogation; remediation/config changes;
  multi-vendor support (this is ASA-specific); any cloud/online submission.

## Embedded rules and logic

The "rules engine" of this tool is the set of security checks. Locked decisions
from initiation that constrain that engine:

- **R1 — Authority mapping:** Findings map to a **combination of the CIS Cisco
  ASA Benchmark and DISA STIG (Cisco ASA)**. Rationale: enterprise firewall in
  an enterprise working area; both are recognized and complementary.
- **R2 — Output:** **Markdown report + machine-readable CSV** of findings.
  Markdown follows Cutaway convention (single stream, user redirects). CSV is
  one row per finding for tracking.
- **R3 — Runtime:** Target **Windows PowerShell 5.1 as the feature floor**, and
  also run on **PowerShell 7+**. Pure text parsing — no external modules.
- **R4 — Offline only:** No online tools, no network calls, no data egress. The
  config is sensitive.
- **R5 — Read-only:** The tool reads a config file and emits a report. It never
  contacts or modifies a device.

## Dependencies

- **Sibling — CHAPS** (`/home/cutaway/Projects/chaps`): Cutaway's PowerShell
  config-hardening assessment tool. Relevant for **convention inheritance**
  (status-prefix output `[+]/[-]/[*]/[$]/[x]`, timestamped output filenames,
  no-dependency rule, read-only posture, markdown output) — NOT a content
  template (it predates the current `claude_frameworks` project style; do not
  copy its docs). Worth examining its tool structure as a pattern, not a source.
- **Frameworks** (`/home/cutaway/Projects/claude_frameworks/templates`): the
  canonical templates and `code-standards/powershell.md` this project uses.

## Open questions (carried into research / design)

- **OQ1:** Which existing open-source ASA analyzers are worth learning from
  (parsing approach, check catalog) — and are any directly portable to or
  callable from PowerShell offline? (Research vector.)
- **OQ2:** What is the authoritative, current check catalog from the CIS Cisco
  ASA Benchmark and the DISA Cisco ASA STIG, and where do they overlap/diverge?
  (Research vector.)
- **OQ3:** ASA config grammar — what are the block/line structures the parser
  must handle (interfaces, object/object-group, access-list, crypto, aaa, snmp,
  logging, http/ssh/telnet, NAT)? (Research vector.)
- **OQ4 (TEST GAP):** No real or sanitized ASA config is available and no device
  exists for testing. Validation must rely on a **synthesized, syntactically
  faithful ASA 5515 config fixture**. This bounds validation confidence and must
  be stated honestly in SUCCESS_CRITERIA and TEST_ENVIRONMENT.

## References

- `background/goal.md` — full goal and constraints.
- `/home/cutaway/Projects/chaps/CLAUDE.md` — convention reference (not content).
- `/home/cutaway/Projects/claude_frameworks/templates/` — canonical templates.
- Initiation chat 2026-06-24 — locked decisions R1–R5, test-data gap OQ4.
