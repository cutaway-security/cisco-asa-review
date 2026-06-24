# State of the Art — Offline Cisco ASA Configuration Analysis

**Project:** cisco-asa-review
**Date:** 2026-06-24
**Author:** Claude (cutsec-init pipeline, Phase 2)
**Status:** Survey complete; feeds VISION / REQUIREMENTS / ARCHITECTURE

---

## 1. Scope and methodology

This survey answers the research vectors raised in `DISCOVERY_NOTES.md`:

- **OQ1 — Prior art:** what open-source tools already analyze Cisco ASA (or
  general firewall) configs, how they parse, what they check, and whether their
  logic is portable to an offline PowerShell tool.
- **OQ2 — Check catalog:** what the CIS Cisco ASA Benchmark and the DISA Cisco
  ASA STIG actually require, expressed as patterns over `running-config` text.
- **OQ3 — Config grammar:** the ASA `show running-config` structure and the
  syntax of every security-relevant block the parser must handle.

Method: three parallel research agents fanned out across vendor documentation
(Cisco ASA command/config references), benchmark sources (CIS via cisecurity.org
and the Tenable audit mirrors, DISA STIGs via stigviewer.com and NCP/NIST),
open-source repositories (GitHub, PyPI), and real sanitized ASA configurations.
Every claim below is traceable to a source URL listed in §7. Findings that the
agents could not confirm from a primary source are flagged **[unverified]** and
carried as such — they are not treated as fact.

A standing caveat: **no real or sanitized engagement config is available, and no
ASA 5515 device exists for testing** (DISCOVERY_NOTES OQ4). This survey therefore
grounds the parser design in published syntax and real configs found in the wild,
not in the target config. That bound is carried into SUCCESS_CRITERIA.

---

## 2. Definitions and prior art

**Cisco ASA running-config** — the text produced by `show running-config` on an
ASA appliance. It is a flat list of lines whose hierarchy is encoded by leading
whitespace, in the same style as Cisco IOS. ASA 9.x is the relevant software
family for the 5515-X.

**Static config analysis** — inspecting that text offline for security-relevant
properties, without contacting the device and without modeling live traffic.
This is distinct from *dataplane/reachability analysis* (what Batfish does) and
from *live auditing* (what tools requiring an SSH session do).

The prior-art landscape sorts into five groups:

1. **Commercial closed auditors.** Titania **Nipper / Nipper Studio /
   InfraSight** is the canonical firewall-config auditor — vulnerabilities,
   hardening against CIS "where supported," and compliance mapping (NIST 800-53,
   800-171, PCI DSS, CMMC) across 180+ devices including Cisco firewalls. Closed
   source; its logic cannot be read. Historically descended from the open
   "CiscoParse"/early GPL nipper before commercialization.

2. **Open ASA-aware checkers (legacy / frozen).** **nipper-ng** is the GPLv3
   fork frozen at 0.11.10 — a C "Network Infrastructure Configuration Parser"
   that reads a config file offline and emits findings with recommendations. It
   covers legacy ASA/PIX. Its modern Python port, **pynipper-ng**, is GPLv3 but
   **abandoned since January 2022** (v0.2.0-ALPHA). nipper-ng's value to this
   project is its *findings model* (issue → severity → rationale → fix) and its
   concrete rule encodings, not its code.

3. **Open offline parsers without a check engine.** **ciscoconfparse2** (GPLv3,
   active, v0.9.18 May 2026) is the de-facto reference parser. It supports an
   `asa` syntax mode (via the library's `syntax='asa'` API parameter) and models
   config as **linked parent/child blocks** keyed off indentation (GPLv3 and the
   parent/child model verified 2026-06-24 by re-fetching the repo). The original **ciscoconfparse** (v1, frozen) supports
   a 2-level model. Also **AlekzNet/Cisco-ASA-ACL-toolkit** (Apache-2.0) — parses
   ASA ACLs offline and implements **rule shadowing/redundancy/aggregation**
   logic that is directly portable — and **avezhlev/assa** (offline ASA parser,
   license [unverified]). None of these is a security checker; they parse.

4. **Open live auditors (wrong delivery model).** **WatchThisFirewall / WTF.v1**
   (GPLv3, active to 2025) and **tonhe/asa-audit** (Apache-2.0) perform real ASA
   security checks (ACL hit-counts/age, NAT, unused objects) but **require a live
   SSH connection** and live hitcounts. Good check-catalog inspiration; they
   cannot run offline against a static dump.

5. **Open IOS-family auditors (wrong syntax).** **ccat** (GPLv3, stale 2018)
   audits Cisco config files offline against the IOS hardening guide; **jonarm/
   cisco-ios-audit**, **Tes3awy/cisco-config-auditor** (IOS-XE) similar. Their
   *check-list organization* is a useful model; their ASA syntax coverage is
   absent.

6. **Model-based analysis (out of scope to reimplement).** **Batfish**
   (Apache-2.0, active) lists ASA among supported devices and builds a
   vendor-independent behavioral model from config text to answer reachability/
   ACL questions. Powerful, but a Java engine plus Python client — impractical
   to port to PowerShell and broader than a misconfiguration linter.

**PowerShell landscape — the gap.** The only PowerShell Cisco module found is
**Posh-Cisco** (GPLv3) — SSH backup and `Get-Cisco*` collection, with **zero
auditing and no offline parsing of misconfigurations** (verified 2026-06-24 by
re-fetching the repo: backup/SSH retrieval + basic troubleshooting only; its
documented device list is Catalyst, ASA appears only in Gallery tag metadata).
No maintained,
open-source, offline, PowerShell-native ASA security-misconfiguration analyzer
exists. **That is the niche this project fills.**

---

## 3. Research vector 1 — Prior-art parsing approaches worth borrowing

The convergent lesson across ciscoconfparse2, the ASA-ACL-toolkit, and assa:

1. **Use a hierarchical parent/child block model, not flat line regex.** Treat
   each line as a node that knows its parent and children, keyed off
   leading-space indentation depth. Flat regex alone misreads nested
   policy/crypto/group-policy blocks.

2. **Two-pass parsing.** Pass 1 builds a symbol table (`name` map, `object` and
   `object-group` definitions). Pass 2 resolves `access-list` / NAT / crypto
   references against it. This is required to detect undefined references, unused
   objects, and ACL shadowing offline.

3. **Borrow ACL redundancy/shadowing logic** from the ASA-ACL-toolkit (overlap
   aggregation, redundant-rule detection) — the most directly portable
   algorithmic prior art, and it runs purely on config text.

4. **Borrow nipper-ng's findings model** — each misconfiguration maps to a
   structured finding (issue, severity, rationale, remediation). Do not port its
   code; port its shape.

5. **Organize checks declaratively** (the ccat/jonarm pattern): a check catalog
   where each check is an independently testable rule against the parsed tree,
   mapped to an external authority.

**What this project deliberately does not attempt:** live hitcount analysis
(requires a device), and dataplane reachability modeling (Batfish territory).
Those are named as out-of-scope so the static tool is not measured against them.

---

## 4. Research vector 2 — The check catalog (CIS + DISA STIG)

The full catalog is captured in `claude-dev/CHECK_CATALOG.md` (companion to this
survey) organized by category with PASS/FAIL patterns, default-if-absent
semantics, severity, and authority IDs. The authorities:

- **DISA STIG — Cisco ASA**, split into NDM (device management), FW (firewall),
  VPN, and IPS modules, published as XCCDF XML. ASA NDM observed at v2r4
  (2026-03-24). Severity maps CAT I = High, CAT II = Medium, CAT III = Low.
- **CIS Cisco Firewall / ASA 9.x Benchmark** (v4.1.0 L1, v1.1.0 L2 observed via
  the Tenable audit mirror; canonical PDFs at cisecurity.org). Level 1 ≈
  baseline, Level 2 ≈ defense-in-depth.

**Honesty flags carried from research:** individual STIG V-IDs and CIS
recommendation numbers were read off stigviewer.com and the Tenable audit pages;
several exact sub-numbers could not be individually confirmed and are flagged
`[unverified]` in the catalog. The tool must therefore treat authority IDs as
*advisory labels*, not load-bearing claims — a finding's validity rests on the
config evidence, not on a possibly-misremembered V-ID. This is a deliberate
design constraint (see REQUIREMENTS SR / ARCHITECTURE).

The categories, each with concrete config-text checks:

1. **Management plane** — telnet disabled; `ssh version 2`; SSH/HTTP source
   restriction (not `0.0.0.0 0.0.0.0`); no SSH/HTTP on outside; `console
   timeout` 1–5 (default `0` = no timeout is the common real finding); SSH/HTTP
   idle-timeout; SSH FIPS key-exchange/cipher; RSA modulus >= 2048; AUX disabled.

2. **Authentication / AAA** — non-default `passwd`/`enable password`; password
   encryption master key; `no service password-recovery`; local lockout
   (`max-fail`); `aaa authentication {ssh|serial|enable|http} console`; >= 2 AAA
   servers with LOCAL fallback; single account-of-last-resort; password-policy
   (length, complexity, min-changes, lifetime); login/exec/motd banners (DoD
   notice text for STIG).

3. **Logging / monitoring** — `logging enable` (off by default); syslog host(s)
   (STIG wants 2); trap level; buffer size; timestamps; NTP authentication +
   trusted-key + redundant server; SNMP v3-priv only (flag v1/v2c communities,
   especially `public`/`private`); threat-detection basic.

4. **Access control** — no overly-permissive ACE (`permit ip any any`, esp.
   inbound on outside); implicit-deny logging; ICMP-to-device restricted; no
   proxy-ARP on untrusted; VPN traffic traverses ACL (`sysopt connection
   permit-vpn` is a finding); routing-protocol auth. Plus tool heuristics with
   no discrete authority ID: ACEs referencing undefined object-groups, ACLs not
   bound by any `access-group`, expired `time-range`.

5. **Crypto / VPN** — prefer IKEv2 (flag IKEv1); DH group >= 16 (flag 1/2/5);
   AES-256 phase-1 and ESP; SHA-2 integrity (flag MD5/SHA-1); PFS set; SA
   lifetime bound; WebVPN/SSL TLS 1.2+ (flag tlsv1/1.1/sslv3); strong SSL
   ciphers; split-tunnel policy. Legacy weak-crypto regex set (`esp-des`,
   `esp-3des`, `esp-md5-hmac`, `crypto ikev1`, `hash md5`, `group 1|2|5`) is
   high-signal even where CIS lacks a discrete number.

6. **Interface / network hardening** — uRPF (`ip verify reverse-path`);
   threat-detection scanning/statistics; DNS guard; outside interface
   security-level 0; `same-security-traffic` not gratuitously permissive; unused
   interfaces `shutdown`; failover; botnet filter (L2).

7. **Software / version currency** — supported, non-EoL 9.x train; image
   integrity. **Implementation note:** the running-config rarely contains the
   exact image version. Parse the `ASA Version 9.x(y)` header line or `boot
   system flash:` line if present; compare against a maintained EoL/known-vuln
   list rather than hardcoding CVEs (Cisco PSIRT is the source of truth).

**Highest-signal first checks** (single-line, near-zero ambiguity, dominate real
ASA findings): telnet present; `ssh version` missing/v1; SSH/HTTP any-source;
`console timeout 0`/>5; `logging enable` absent; no `logging host`; SNMP v1/v2c
community; weak VPN crypto set; SSL < TLS 1.2; `no service password-recovery`
absent; password-policy missing; NTP without authentication; `permit ip any any`;
`aaa authentication ssh console` absent; missing banner. These fifteen anchor the
MVP check set.

---

## 5. Research vector 3 — Config grammar and parser design

**The model.** An ASA running-config is a sequence of lines whose hierarchy is
encoded purely by leading whitespace (1 space per nesting level in a real `show
run`; key on "has leading whitespace" with a parent-context stack, never a
hardcoded count). Most blocks are 1 level deep; a few nest 2–3 deep
(`group-policy ... attributes` → `webvpn` → `anyconnect ...`). A bare `!`
visually separates blocks but does **not** define them — indentation does.

**Two structural patterns** the parser must handle distinctly:

- **True indented blocks** — a header opens a sub-mode, children indented:
  `interface`, `object network/service`, `object-group`, `crypto ikev1/ikev2
  policy`, `crypto ipsec ikev2 ipsec-proposal`, `tunnel-group *-attributes`,
  `group-policy attributes`, `policy-map`, `webvpn`, `aaa-server ... host`.
- **Repeated-prefix flat lines** — semantically grouped but NOT indented; each
  line repeats the key: `access-list <NAME> ...`, `crypto map <NAME> <SEQ> ...`,
  `name <ip> <str>`, twice/manual `nat (...) source ...`, `banner <type> ...`,
  `http/ssh/telnet <ip> <mask> <if>`. These must be grouped by repeated key, not
  by indentation.

**Recommended data structure (two indices built in one pass):**

1. **Indentation tree** — line nodes `{ lineNo, raw, indent, text, parent,
   children[] }`, assembled with an indent stack (push when indent increases, pop
   while indent <= stack top).
2. **Repeated-prefix family index** — hash maps keyed on the repeated token(s):
   ACL name → ordered ACE/remark list; crypto-map NAME/SEQ → lines; `name` →
   IP→symbol map (build first); tunnel-group name → attribute sub-blocks; banner
   type → joined text.

A resolution layer then recursively expands `object` / `object-group` /
`group-object` references and substitutes `name` symbols.

**Critical parsing gotchas** (each is a latent false-positive/negative source):

- **Password hash type = trailing token.** `pbkdf2` (strong, `$sha512$...`),
  `encrypted` (legacy weak), `nt-encrypted` (NT hash), and **no token + not
  `$sha512$` = cleartext** (a finding). `*****` = redacted. This classification
  is the heart of credential checks.
- **Cleartext secrets to flag wherever they appear:** `snmp-server community`,
  `aaa-server ... key`, `ntp authentication-key ... md5 <key>`, tunnel-group
  `pre-shared-key`.
- **Default-and-absent semantics.** Defaults are omitted from running-config.
  Many findings are detected by **absence** (`logging enable`, `ip verify
  reverse-path`, `threat-detection`, `banner`, `ssh version 2`), not by a
  positive bad line. The check engine must reason over absence.
- **`no` forms** are printed only when non-default (`no service
  password-recovery` = hardened).
- **`names` feature** — once `names` is on, symbolic names replace IPs
  elsewhere; resolve the `name` map before resolving objects/ACLs.
- **Two NAT shapes** (indented object-NAT vs flat twice-NAT) and **two `webvpn`
  contexts** (global vs group-policy) — disambiguate by parent context.
- **Token-spelling drift across versions** — IKEv1 `hash` vs IKEv2 `integrity`;
  IKEv2 `lifetime seconds N` vs IKEv1 bare `lifetime N`; ipsec-proposal
  `sha-1`/`sha-256` (hyphenated) vs policy `sha`/`sha256`.
- **Multi-line banners** repeat the `banner <type>` prefix per text line —
  reassemble consecutive same-type lines.

Per-construct regex anchors and verbatim syntax examples are captured in
`claude-dev/CHECK_CATALOG.md` and reproduced from the research into the parser
design in `ARCHITECTURE.md`.

---

## 6. Implications for this project

1. **Build a ciscoconfparse2-style hierarchical block parser in pure
   PowerShell.** This is the proven model and there is no PowerShell
   implementation of it — that absence is the project's reason to exist.

2. **Two-pass parse + resolution layer** is mandatory, not optional, to support
   object/ACL hygiene checks and to avoid false positives from unresolved
   references.

3. **Seed the check catalog from DISA ASA STIG + CIS ASA 9.x**, implement the
   fifteen high-signal checks first (MVP), and treat authority IDs as advisory
   labels validated by config evidence (because some IDs are `[unverified]`).

4. **Adopt a declarative check architecture** (one rule = one testable unit
   against the parsed tree) and nipper-ng's structured finding model (issue,
   severity, evidence, rationale, remediation).

5. **Reason over absence as a first-class case** — a large fraction of ASA
   findings are "setting not present." The check engine and the parsed model
   must make "is X absent?" as easy to ask as "is Y present and bad?".

6. **Output Markdown + CSV** (locked decision R2). Markdown carries narrative
   findings; CSV carries one row per finding (check id, category, severity,
   evidence line, authority ref, remediation) for tracking.

7. **No live, no network, no egress** (R4/R5). Every capability above is
   achievable purely on static text — confirmed by the prior-art split (the
   only things requiring a device are hitcount-based, which we exclude).

---

## 7. Open questions the literature does not resolve

- **OQ-A — Authority ID drift.** Exact CIS recommendation numbers and some STIG
  V-IDs could not all be verified; they move across benchmark revisions.
  *Resolution:* store IDs as advisory metadata, cite revision, never gate a
  finding on the ID alone.
- **OQ-B — Version/EoL data.** ASA EoL and known-vuln trains change over time and
  are not in the running-config. *Resolution:* a maintained local lookup table,
  updated deliberately, not hardcoded CVEs; degrade gracefully when the version
  line is absent.
- **OQ-C — ACL shadowing depth.** Full shadowing analysis with object-group
  expansion is combinatorially heavy. *Resolution:* phase it — start with
  exact/obvious redundancy (ASA-ACL-toolkit-style), defer full overlap modeling.
- **OQ-D — Validation without a real device (DISCOVERY_NOTES OQ4).** No
  engagement config and no 5515 to test against. *Resolution:* build a
  synthesized, syntactically faithful ASA 5515 fixture from the verified syntax
  in §5 and real sanitized configs; state the validation bound honestly in
  SUCCESS_CRITERIA; the "real call returns data" gate becomes "a real, faithful
  config fixture parses and produces correct findings."
- **OQ-E — Legacy syntax confidence.** A few constructs (`object-group service
  {tcp|udp}` + `port-object`, `object-group protocol`, `nt-encrypted` value
  layout) are `[lower confidence]` on verbatim token order. *Resolution:* mark
  those parser branches as lower-confidence and prioritize fixture coverage there.

---

## References

Prior art:
- Titania Nipper — https://www.titania.com/products/nipper ; https://www.titania.com/nipper-infrasight
- nipper-ng — https://www.kali.org/tools/nipper-ng/ ; https://github.com/arpitn30/nipper-ng
- pynipper-ng — https://github.com/syn-4ck/pynipper-ng
- ciscoconfparse — https://github.com/mpenning/ciscoconfparse ; parent/child model https://www.pennington.net/py/ciscoconfparse/tutorial_parent_child.html
- ciscoconfparse2 — https://github.com/mpenning/ciscoconfparse2 ; https://pypi.org/project/ciscoconfparse2/
- Batfish — https://github.com/batfish/batfish ; https://batfish.readthedocs.io/en/latest/supported_devices.html
- ntc-soteria — https://github.com/networktocode/ntc-soteria
- tonhe/asa-audit — https://github.com/tonhe/asa-audit
- WatchThisFirewall/WTF.v1 — https://github.com/WatchThisFirewall/WTF.v1
- Cisco-ASA-ACL-toolkit — https://github.com/AlekzNet/Cisco-ASA-ACL-toolkit
- avezhlev/assa — https://github.com/avezhlev/assa
- ccat — https://github.com/frostbits-security/ccat
- Tes3awy/cisco-config-auditor — https://github.com/Tes3awy/cisco-config-auditor
- jonarm/cisco-ios-audit — https://github.com/jonarm/cisco-ios-audit
- Posh-Cisco — https://github.com/Nevets82/Posh-Cisco ; https://www.powershellgallery.com/packages/Posh-Cisco/

Authorities:
- DISA Cisco ASA STIGs — https://www.stigviewer.com/stigs/cisco_asa_ndm ; .../cisco_asa_firewall ; .../cisco_asa_vpn ; https://public.cyber.mil/ ; https://ncp.nist.gov/checklist/1001
- CIS Cisco Firewall/ASA Benchmark — https://www.cisecurity.org/benchmark/cisco ; https://www.tenable.com/audits/CIS_v4.1.0_Cisco_Firewall_ASA_9_Level_1 ; https://ncp.nist.gov/checklist/revision/344
- Cisco Guide to Harden Cisco ASA Firewall — https://www.cisco.com/c/dam/en/us/support/docs/security/asa-5500-x-series-next-generation-firewalls/200150-Hardening-Cisco-ASA-Firewall.pdf
- Cisco ASA Threat Detection — https://www.cisco.com/c/en/us/support/docs/security/asa-5500-x-series-next-generation-firewalls/113685-asa-threat-detection.html

Grammar / syntax (Cisco config guides + real configs):
- ASA Objects for Access Control 9.17 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa917/configuration/firewall/asa-917-firewall-config/access-objects.html
- ASA Extended/Standard ACLs 9.2 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa92/configuration/general/asa-general-cli/acl-extended.html ; .../acl-standard.html
- ASA Access Rules 9.2 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa92/configuration/firewall/asa-firewall-cli/access-rules.html
- ASA NAT 9.1 / 9.12 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa91/configuration/firewall/asa_91_firewall_config/nat_objects.html ; .../asa912/.../nat-reference.html
- ASA Basic Settings / passwords 9.15 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa915/configuration/general/asa-915-general-config/basic-hostname-pw.html
- ASA Management Access 9.19 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa919/configuration/general/asa-919-general-config/admin-management.html
- ASA SNMP 9.16 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa916/configuration/general/asa-916-general-config/monitor-snmp.html
- ASA Syslog 9.19 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa919/configuration/general/asa-919-general-config/monitor-syslog.html
- ASA Protection Tools (uRPF) 9.1 / Threat Detection 9.20 — https://www.cisco.com/c/en/us/td/docs/security/asa/asa91/configuration/firewall/asa_91_firewall_config/protect_tools.html ; .../asa920/.../conns-threat.html
- ASA password hashing (pbkdf2/sha512) — https://www.attackdebris.com/?p=451
- Real sanitized configs — https://raw.githubusercontent.com/HussainYaqoob/SFC-Project/master/Show%20Run/HQ-FW2.txt ; https://raw.githubusercontent.com/nicholasrowley/Cisco-Network-Security-Lab/master/ASABuzzNick
- VPN/crypto syntax — https://networklessons.com/cisco/asa-firewall/cisco-asa-site-site-ikev2-ipsec-vpn ; https://grumpy-networkers-journal.readthedocs.io/en/latest/VENDOR/CISCO/VPN/CISCO_IKEV1/ASA_IKEV1_S2S_PSK.html ; https://www.networkstraining.com/configuring-site-to-site-ipsec-vpn-on-asa-using-ikev2/ ; https://www.pinglabz.com/cisco-asa-anyconnect-ssl-vpn/
- SSL/TLS ciphers — https://integratingit.wordpress.com/2021/01/27/securing-asa-tls-ciphers/
