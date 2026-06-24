# CHECK_CATALOG.md — ASA 9.x Security Checks + Parser Syntax Reference

Companion to `20260624_asa-config-analysis_RESEARCH.md`. This is the working
reference the check engine and parser are built from. Authority IDs are advisory
labels: items flagged `[unverified]` were not confirmable to an exact number/V-ID
and must never gate a finding by themselves (see RESEARCH §4, OQ-A). Severity:
STIG CAT I = High, CAT II = Medium, CAT III = Low; CIS L1 ≈ baseline, L2 ≈
defense-in-depth.

---

## PART A — CHECK CATALOG

### A1. Management plane

| Check | Authority | PASS | FAIL | Default if absent | Sev |
|---|---|---|---|---|---|
| Telnet disabled | CIS 1.6.5; STIG V-239911 | no `telnet ` lines | any `telnet <ip> <mask> <if>` / `telnet timeout` | telnet off | High |
| SSH version 2 only | CIS 1.6.2 | `ssh version 2` | `ssh version 1` or no `ssh version` line | v1 negotiable | High |
| SSH source restriction | CIS 1.6.1 | `ssh <specific> <mask> <if>` | `ssh 0.0.0.0 0.0.0.0 <if>` | none allowed | Medium |
| No SSH on outside | narrative `[unverified]` | no `ssh ... outside` | `ssh <ip> <mask> outside` | n/a | High |
| SSH FIPS key-exchange | STIG V-239931/V-239913 | `ssh key-exchange group dh-group14-sha1`+ | weak/absent | weaker default | High |
| HTTP/ASDM source restriction | CIS 1.7.1; STIG V-239911 | `http <specific> <mask> <if>` | `http 0.0.0.0 0.0.0.0` or unneeded `http server enable` | http off | Medium |
| Console timeout 1–5 | CIS 1.8.1; STIG V-239920 | `console timeout 5` | `console timeout 0` or >5, or absent | `0` = no timeout (finding) | High |
| SSH idle timeout <=5 | CIS 1.8.2; STIG V-239920 | `ssh timeout 5` | >5 | 5 (ok) | High |
| HTTP idle timeout <=5 | CIS 1.8.3; STIG V-239920 | `http server idle-timeout 5` | >5 or absent | longer | High |
| Mgmt session quota | STIG V-239896 | `quota management-session <n>` | absent | 5 | Medium |
| FIPS mode (DoD) | STIG V-239930/931 | `fips enable` | absent | off | High |
| RSA modulus >=2048 | CIS 1.6.3 (L2) | modulus 2048+ | <2048 | 1024 | Medium |

### A2. Authentication / AAA

| Check | Authority | PASS | FAIL | Default | Sev |
|---|---|---|---|---|---|
| Logon password non-default | CIS 1.1.1 | `passwd <hash>` | default `cisco` | `cisco` | High |
| Enable password set | CIS 1.1.2 | `enable password <hash>` | absent | none | High |
| Password-encryption master key | CIS 1.1.3 | `key config-key password-encryption` | absent | absent | Medium |
| service password-recovery disabled | CIS 1.1.4 | `no service password-recovery` | absent | recovery enabled | Medium |
| Local lockout <=3 | CIS 1.4.1.1 | `aaa local authentication attempts max-fail 3` | absent / >3 | no lockout | Medium |
| AAA ssh console | CIS 1.4.3.5; STIG V-239940 | `aaa authentication ssh console <grp> LOCAL` | absent | none | High |
| AAA serial console | CIS 1.4.3.4; STIG V-239940 | `aaa authentication serial console ...` | absent | none | High |
| AAA enable/http console | CIS 1.4.3.1/.2 | present | absent | none | Medium |
| >=2 AAA servers + LOCAL fallback | STIG V-239940 | 2+ `aaa-server host` + LOCAL | single/local-only | none | High |
| Single account-of-last-resort | STIG V-239912 | one local priv15 fallback | multiple local accts | n/a | Medium |
| Command authorization/accounting | CIS 1.4.4.1/1.4.5.1 | `aaa authorization/accounting command` | absent | none | Medium |
| Password-policy length >=14/15 | CIS 1.1.5; STIG V-239914 | `password-policy minimum-length 15` | absent / lower | not enforced | Medium |
| Password-policy complexity | CIS 1.1.5; STIG V-239915–918 | minimum-upper/lower/numeric/special 1 | absent | not enforced | Medium |
| Password-policy min-changes >=8 | STIG V-239919 | `minimum-changes 8` | absent | not enforced | Medium |
| Password lifetime | CIS 1.1.5 | `password-policy lifetime 90` | absent | no expiry | Medium |
| Login/exec/motd banner | CIS 1.5.1–1.5.4 | banner set | absent | none | Low–Med |
| DoD Notice banner text | STIG V-239902 | `banner login` w/ exact DoD text | missing/altered | none | Medium |

### A3. Logging / monitoring

| Check | Authority | PASS | FAIL | Default | Sev |
|---|---|---|---|---|---|
| Logging enabled | CIS 1.10.1 | `logging enable` | absent | disabled | Medium |
| Console logging off | CIS 1.10.2 | no `logging console` | `logging console` | off | Low |
| Syslog host(s) | CIS 1.10.3 `[approx]`; STIG V-239943 (>=2) | `logging host <if> <ip>` | none / <2 for STIG | none | High |
| Syslog TCP + permit-hostdown | STIG V-239858 | TCP host + `logging permit-hostdown` | UDP / none | UDP | Medium |
| Trap level | CIS `[approx]` | `logging trap notifications` | absent / too low | none | Medium |
| Buffer size >=512KB | CIS 1.10.9 | `logging buffer-size 524288` | < | 4096 | Low |
| Timestamps | CIS (renumbered) | `logging timestamp` | absent | off | Low |
| NTP authentication | CIS 1.9.1.1; STIG V-239929 | `ntp authenticate` | absent | disabled | Medium |
| NTP key + trusted-key | CIS 1.9.1.2; STIG V-239929 | key + trusted-key (SHA256 for STIG) | absent / MD5 | absent | Medium |
| Redundant NTP server | CIS 1.9.1.3; STIG V-239924 (>=2) | 2+ `ntp server` | single/none | none | Medium |
| SNMP v3 priv only | CIS 1.11.1; STIG V-239928 | `snmp-server group <g> v3 priv` | `snmp-server community` (v1/v2c) | none | Medium |
| SNMP v3 SHA+AES | CIS 1.11.2; STIG V-239927/928 | `auth sha ... priv aes 256` | MD5/DES/noauth | none | Medium |
| SNMP community not default | CIS 1.11.5 | no `public`/`private` | `community public` | n/a | Medium |
| Threat-detection basic | STIG V-239860; CIS 3.6 | `threat-detection basic-threat` | absent | off | Medium |

### A4. Access control

| Check | Authority | PASS | FAIL | Default | Sev |
|---|---|---|---|---|---|
| No overly-permissive ACE | Cisco guide; CIS narrative `[unverified]` | scoped ACEs | `access-list <x> extended permit ip any any` (esp inbound outside) | implicit deny (defeated by explicit any-any) | High |
| Implicit-deny logging | Cisco guide `[unverified]` | trailing `deny ip any any log` | none | implicit deny silent | Low |
| ICMP to device restricted | CIS 2.5; Cisco guide | `icmp deny any <outside>` / scoped | no `icmp` control | ICMP allowed | Medium |
| No proxy-ARP untrusted | CIS 2.2 (L2) | `sysopt noproxyarp <if>` | absent | proxy-arp on | Low |
| VPN traffic traverses ACL | CIS 3.13 (L2) | no `sysopt connection permit-vpn` | present | permit-vpn bypasses ACL | Medium |
| Routing protocol auth | CIS 2.1.x (L2) | OSPF/EIGRP/BGP auth | none | none | Medium |
| (heuristic) ACE → undefined object-group | tool | all refs resolve | ACE references missing group | n/a | Medium |
| (heuristic) ACL not bound | tool | every ACL has `access-group` | ACL defined, never bound | n/a | Low |
| (heuristic) expired time-range | tool | no past `time-range` in active ACE | expired range still referenced | n/a | Low |

### A5. Crypto / VPN

| Check | Authority | PASS | FAIL | Sev |
|---|---|---|---|---|
| Prefer IKEv2 | STIG V-239952 | `crypto ikev2 policy`+`enable` | IKEv1 / `isakmp` in use | Medium |
| IKE DH group >=16 | STIG V-239957 | `group 16` (or 19/20/21/24) | `group 1/2/5` (STIG: even 14) | High |
| IKE P1 encryption AES-256 | STIG V-239979 | `encryption aes-256` | DES/3DES/AES-128 | High |
| IPsec ESP AES-256 | STIG V-239980 | proposal `esp encryption aes-256` | DES/3DES/AES-128 | High |
| IKE integrity SHA-2 | STIG V-239958 | `integrity sha384` | SHA-1/MD5 | Medium |
| IPsec integrity SHA-2 | STIG V-239959 | `sha-384 sha-256` | SHA-1 | High |
| PFS enabled | STIG V-239954 | `set pfs group<n>` | none | Medium |
| IKE SA lifetime <=24h | STIG V-239964 | `lifetime seconds 86400`- | longer | Medium |
| WebVPN/SSL TLS1.2+ | STIG V-239975; CIS 1.7.2 | `ssl server-version tlsv1.2 dtlsv1.2` | tlsv1/1.1/sslv3/any | High |
| SSL strong cipher | CIS 1.7.3 | strong AES-256 list | weak/default incl DES/RC4/3DES | Medium |
| Split-tunnel disabled (DoD) | STIG V-239982 | `split-tunnel-policy tunnelall` | split enabled | Medium |
| VPN banner (DoD) | STIG V-239970 | group-policy `banner value <DoD>` | absent | Medium |
| (high-signal) legacy weak crypto | tool/STIG | none | `crypto ikev1`, `encryption des/3des`, `hash md5`, `group 1/2/5`, `esp-des`, `esp-3des`, `esp-md5-hmac` | High |

### A6. Interface / network hardening

| Check | Authority | PASS | FAIL | Default | Sev |
|---|---|---|---|---|---|
| uRPF anti-spoofing | CIS 3.7; Cisco guide | `ip verify reverse-path interface <untrusted>` | absent on outside | off | Medium |
| Threat-detection scanning | STIG V-239864 | `threat-detection scanning-threat` | absent | off | Medium |
| Threat-detection statistics | CIS 3.6 | `threat-detection statistics tcp-intercept` | absent | off | Low |
| DNS guard | CIS 2.3 | `dns-guard` / inspection | absent | depends | Low |
| Outside iface sec-level 0 | CIS 3.8 | outside `security-level 0` | higher | 0 unless set | Medium |
| same-security-traffic minimal | narrative `[unverified]` | not permitted unless required | `same-security-traffic permit ...` unjustified | off | Low |
| Unused interfaces shut | CIS 1.2.4 | `shutdown` on unused | up + no nameif | admin-up | Medium |
| Failover | CIS 1.2.3 | `failover` | absent | off | Low |

### A7. Software / version

| Check | Authority | PASS | FAIL | Sev |
|---|---|---|---|---|
| Supported/non-EoL ASA OS | STIG V-239944 | current supported 9.x | EoL/known-vuln train | High |
| Image integrity | CIS 1.3.1/1.3.2 | verified image | unverified | Medium |

Note: version is usually NOT in running-config. Parse `ASA Version 9.x(y)` header
or `boot system flash:` if present; compare to a maintained local EoL/known-vuln
table (OQ-B). Degrade gracefully if absent.

### A8. MVP shortlist (implement first — single-line, near-zero ambiguity)

telnet present · `ssh version` missing/v1 · SSH/HTTP any-source · `console
timeout 0`/>5 · `logging enable` absent · no `logging host` · SNMP v1/v2c
community · weak VPN crypto set · SSL < TLS1.2 · `no service password-recovery`
absent · password-policy missing · NTP without authentication · `permit ip any
any` · `aaa authentication ssh console` absent · missing banner.

---

## PART B — PARSER SYNTAX REFERENCE

### B1. Grammar model

- Hierarchy = leading whitespace (1 space/level in real `show run`; key on
  "has leading whitespace" + indent stack, never a hardcoded count).
- Most blocks 1 deep; `group-policy attributes` → `webvpn` → `anyconnect` nests
  2–3 deep.
- `!` separates visually, does NOT define blocks. `: ` prefix = header metadata
  (`: Saved`, `: Hardware: ASA5515`).
- **Indented blocks:** `interface`, `object network/service`, `object-group`,
  `crypto ikev1/ikev2 policy`, `crypto ipsec ikev2 ipsec-proposal`,
  `tunnel-group *-attributes`, `group-policy attributes`, `policy-map`, global
  `webvpn`, `aaa-server ... host`.
- **Repeated-prefix flat families:** `access-list <NAME>`, `crypto map <NAME>
  <SEQ>`, `name <ip> <str>`, twice `nat (...) source`, `banner <type>`,
  `http/ssh/telnet <ip> <mask> <if>` — group by repeated key, not indentation.

### B2. Data structure

1. Indentation tree: `{ lineNo, raw, indent, text, parent, children[] }` via
   indent stack (push on deeper indent; pop while indent <= stack top).
2. Repeated-prefix family index: ACL name → ACE/remark list; crypto-map
   NAME/SEQ → lines; `name` → IP↔symbol map (build FIRST); tunnel-group name →
   attribute blocks; banner type → joined text.
3. Resolution layer: recursively expand `object`/`object-group`/`group-object`/
   `network-object object`/`service-object object`; substitute `name` symbols.

### B3. Password hash classification (credential checks core)

| Trailing token | Meaning | Format |
|---|---|---|
| `pbkdf2` | PBKDF2-HMAC-SHA512, strong | `$sha512$<iter>$<b64salt>$<b64digest>` |
| `encrypted` | legacy reversible/weak | short base64-like, no `$` |
| `nt-encrypted` | NT/MD4 hash `[lower confidence on value layout]` | NT-derived |
| (none) | CLEARTEXT — finding | plain ASCII |

Rules: `pbkdf2` or `^\$sha512\$\d+\$[^$]+\$[^$]+$` → strong; `encrypted` → weak;
`nt-encrypted` → NT; no token and not `$sha512$` → cleartext finding; `*****` →
redacted (classify by tag).

Cleartext secrets to flag wherever seen: `snmp-server community`, `aaa-server ...
key` (child of host line), `ntp authentication-key ... md5 <key>`, tunnel-group
`pre-shared-key`.

### B4. Regex anchors (per construct)

- Parent/flat vs child: `^\S` vs `^\s+`; indent depth `^( *)\S` capture length.
- Separators: `^\s*!\s*$`; header `^:\s`.
- interface: `^interface\s+(\S+)`; ` nameif\s+(\S+)`, ` security-level\s+(\d+)`,
  ` ip address\s+(\S+)\s+(\S+)(?:\s+standby\s+(\S+))?`, ` shutdown\s*$`.
- name: `^name\s+(\S+)\s+(\S+)(?:\s+description\s+(.*))?`.
- object: `^object\s+(network|service)\s+(\S+)`; child `^\s+(host|subnet|range|fqdn)\b`,
  `^\s+service\s+(\S+)`, `^\s+nat\s+\(([^,]+),([^)]+)\)\s+(dynamic|static)\b`.
- object-group: `^object-group\s+(network|service|protocol)\s+(\S+)(?:\s+(tcp|udp|tcp-udp))?`;
  child `^\s+(network-object|service-object|port-object|protocol-object|group-object|description)\b`.
- access-list: `^access-list\s+(\S+)\s+(?:line\s+\d+\s+)?(extended|standard|remark)\b`;
  then `(permit|deny)`, `\b(host|any|object|object-group)\b`, ports
  `\b(eq|gt|lt|neq|range)\s+(\S+)`, `\blog\b`.
- access-group: `^access-group\s+(\S+)\s+(?:(in|out)\s+interface\s+(\S+)|global)`.
- twice NAT: `^nat\s+\(([^,]+),([^)]+)\)\s+source\s+(static|dynamic)\b`.
- passwords: `^(username\s+(\S+)\s+password|enable password|passwd)\s+(\S+)(?:\s+(pbkdf2|encrypted|nt-encrypted))?`.
- aaa: `^aaa authentication\s+(ssh|http|serial|telnet|enable)\s+console\s+(\S+)(?:\s+(LOCAL))?`;
  `^aaa-server\s+(\S+)\s+protocol\s+(\S+)`; child `^\s+key\s+(.+)$`.
- mgmt: `^(ssh|telnet|http)\s+(\d+\.\d+\.\d+\.\d+)\s+(\S+)\s+(\S+)`;
  `^http server enable`; `^console timeout\s+(\d+)`.
- snmp: `^snmp-server\s+(host|community|group|user)\b`; `community\s+(\S+)`;
  `\bv3\b`, `\b(noauth|auth|priv)\b`.
- logging/ntp: `^logging\s+(enable|trap|host|buffered|timestamp)\b`;
  `^ntp\s+(server|authenticate|authentication-key|trusted-key)\b`.
- crypto: `^crypto (ikev1|ikev2) policy\s+(\d+)`;
  `^crypto map\s+(\S+)\s+(\d+)?\s*(match|set|interface)\b`;
  `^crypto ipsec (ikev1 transform-set|ikev2 ipsec-proposal)\s+(\S+)`.
- tunnel-group: `^tunnel-group\s+(\S+)\s+(type|general-attributes|ipsec-attributes|webvpn-attributes)\b`;
  PSK child `^\s+(ikev1 pre-shared-key|ikev2 (local|remote)-authentication pre-shared-key)\s+(.+)$`.
- group-policy: `^group-policy\s+(\S+)\s+(internal|external|attributes)\b`.
- ssl/webvpn: `^ssl\s+(cipher|server-version|trust-point)\b`; `^webvpn\s*$`
  (global) vs `^\s+webvpn\s*$` (nested).
- hardening flags: `^no service password-recovery`,
  `^ip verify reverse-path interface\s+(\S+)`,
  `^threat-detection\s+(basic-threat|statistics|rate)\b`,
  `^banner\s+(motd|login|exec|asdm)\s+(.*)$`.

### B5. Gotchas (false-positive/negative sources)

1. Indent = 1 space; use a stack, support 2–3 deep nesting.
2. `!` separates but doesn't close blocks — indentation does.
3. Repeated-prefix families are NOT indentation children.
4. Password hash type = trailing token; no token + not `$sha512$` = cleartext.
5. Cleartext secrets: snmp community, aaa key, ntp md5 key, tunnel-group PSK.
6. `no` forms only printed when non-default.
7. **Detect findings by ABSENCE** (logging enable, uRPF, threat-detection,
   banner, ssh version 2) — defaults are omitted from running-config.
8. `names` on → symbolic names replace IPs; resolve `name` map first.
9. object-group `group-object` nests — resolve recursively.
10. Two NAT shapes (indented object-NAT vs flat twice-NAT); two `webvpn`
    contexts (global vs group-policy) — disambiguate by parent.
11. Token drift: IKEv1 `hash`/bare `lifetime` vs IKEv2 `integrity`/`lifetime
    seconds`; proposal `sha-1` vs policy `sha`.
12. Multi-line banners repeat the prefix — reassemble.

### B6. Lower-confidence parser branches (prioritize fixture coverage)

`object-group service {tcp|udp|tcp-udp}` + `port-object`; `object-group protocol`
+ `protocol-object`; `nt-encrypted` value layout. `ike-peer` is NOT a valid ASA
token — never emit it.
