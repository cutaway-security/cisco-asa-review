# Cisco ASA Configuration Review

- Configuration: asa-9x-insecure.txt
- Profile: commercial
- Generated: 20260625_091359
- Tool: cisco-asa-review (passive, offline, read-only static analysis; no device contact)

## Summary

- Findings: 39 (High: 11, Medium: 16, Low: 12)
- Informational (hygiene/cleanup): 5
- Not assessed: 0
- Checks evaluated: 58
- Config lines parsed: 147

## Findings

### [HIGH] ACL-ANY-ANY

- Category: access | Severity: High | Confidence: heuristic
- Authority: Cisco hardening guide (verified: False)
- Evidence (line 80): `access-list outside_in extended permit ip any any`
- Additional evidence lines: 1
  - line 81: `access-list inside_in extended permit ip object-group any-net object-group any-net`
- Rationale: A permit ip any any rule allows unrestricted traffic; it may be overly broad.
- Remediation: Review each permit ip any any rule and scope it to required sources, destinations, and services.

### [HIGH] AUTH-AAA-SSH

- Category: auth | Severity: High | Confidence: deterministic
- Authority: CIS 1.4.3.5; STIG V-239940 (verified: True)
- Evidence: setting absent (absence)
- Rationale: Without AAA on the SSH console, administrative access is not centrally authenticated or accounted.
- Remediation: Configure aaa authentication ssh console <server-group> LOCAL.

### [HIGH] CRYPTO-SSL-TLS

- Category: crypto | Severity: High | Confidence: deterministic
- Authority: CIS 1.7.2; STIG V-239975 (verified: False)
- Evidence (line 128): `ssl server-version tlsv1`
- Rationale: SSL/TLS below TLS 1.2 (SSLv3, TLS 1.0/1.1) is deprecated and vulnerable.
- Remediation: Set ssl server-version tlsv1.2 (or higher) for WebVPN/management TLS.

### [HIGH] CRYPTO-WEAK-VPN

- Category: crypto | Severity: High | Confidence: deterministic
- Authority: STIG V-239952/957/979 (verified: False)
- Evidence (line 116): `crypto ipsec ikev1 transform-set legacy-ts esp-3des esp-md5-hmac`
- Additional evidence lines: 5
  - line 117: `crypto ikev1 policy 10`
  - line 119: `encryption 3des`
  - line 120: `hash md5`
  - line 121: `group 2`
  - line 127: `crypto ikev1 enable outside`
- Rationale: Deprecated IKE/IPsec crypto (DES/3DES, MD5, DH groups 1/2/5, IKEv1) is cryptographically weak.
- Remediation: Migrate to IKEv2 with AES-256, SHA-2 integrity, and DH group 16 or higher.

### [HIGH] LOG-HOST

- Category: logging | Severity: High | Confidence: deterministic
- Authority: CIS 1.10.3; STIG V-239943 (verified: True)
- Evidence: setting absent (absence)
- Rationale: Without an external syslog host, logs are lost on reload and unavailable for correlation.
- Remediation: Configure one or more logging host destinations (STIG requires two).

### [HIGH] MGMT-CONSOLE-TIMEOUT

- Category: management | Severity: High | Confidence: deterministic
- Authority: CIS 1.8.1; STIG V-239920 (verified: False)
- Evidence (line 107): `console timeout 0`
- Rationale: A console timeout of 0 (the default) or greater than 5 minutes leaves idle privileged sessions open.
- Remediation: Set console timeout to a value between 1 and 5 minutes.

### [HIGH] MGMT-HTTP-TIMEOUT

- Category: management | Severity: High | Confidence: deterministic
- Authority: CIS 1.8.3; STIG V-239920 (verified: False)
- Evidence (line 101): `http server enable`
- Rationale: With the HTTP/ASDM server enabled, a missing or >5-minute idle-timeout leaves idle admin sessions open.
- Remediation: Set http server idle-timeout to 5 minutes or less (or disable the http server if unused).

### [HIGH] MGMT-SSH-OUTSIDE

- Category: management | Severity: High | Confidence: deterministic
- Authority: CIS 1.6.1 (narrative) (verified: False)
- Evidence (line 105): `ssh 0.0.0.0 0.0.0.0 outside`
- Rationale: SSH management permitted on the outside (untrusted) interface exposes the control plane to the Internet.
- Remediation: Remove ssh access on the outside interface; restrict SSH to an internal management interface.

### [HIGH] MGMT-SSH-TIMEOUT

- Category: management | Severity: High | Confidence: deterministic
- Authority: CIS 1.8.2; STIG V-239920 (verified: False)
- Evidence (line 106): `ssh timeout 30`
- Rationale: An SSH idle timeout greater than 5 minutes leaves idle management sessions open.
- Remediation: Set ssh timeout to 5 minutes or less.

### [HIGH] MGMT-SSH-VERSION

- Category: management | Severity: High | Confidence: deterministic
- Authority: CIS 1.6.2 (verified: True)
- Evidence: setting absent (absence)
- Rationale: Without pinning SSH version 2 (pre-9.16), weaker SSHv1 negotiation is not excluded.
- Remediation: Configure: ssh version 2 (not applicable on ASA 9.16+, which is SSHv2-only).

### [HIGH] MGMT-TELNET

- Category: management | Severity: High | Confidence: deterministic
- Authority: CIS 1.6.5; STIG V-239911 (verified: False)
- Evidence (line 103): `telnet 10.10.20.0 255.255.255.0 inside`
- Rationale: Telnet transmits management traffic, including credentials, in cleartext.
- Remediation: Remove all telnet access lines and use SSHv2 for management.

### [MEDIUM] AUTH-AAA-SERIAL

- Category: auth | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.4.3.4; STIG V-239940 (verified: True)
- Evidence: setting absent (absence)
- Rationale: Without AAA on the serial console, console access is not centrally authenticated.
- Remediation: Configure aaa authentication serial console <server-group> LOCAL.

### [MEDIUM] AUTH-CMD-AUTHZ

- Category: auth | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.4.4.1 (verified: False)
- Evidence: setting absent (absence)
- Rationale: Without command authorization, administrators are not restricted to permitted commands.
- Remediation: Configure aaa authorization command <server-group> LOCAL.

### [MEDIUM] AUTH-PW-COMPLEXITY

- Category: auth | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.1.5; STIG V-239915/916/917/918 (verified: False)
- Evidence: setting absent (presence)
- Rationale: The password policy is missing one or more complexity requirements (uppercase/lowercase/numeric/special).
- Remediation: Configure password-policy minimum-uppercase/lowercase/numeric/special (>= 1 each).

### [MEDIUM] AUTH-PW-LOCKOUT

- Category: auth | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.4.1.1 (verified: False)
- Evidence: setting absent (absence)
- Rationale: No local lockout policy allows unlimited password-guessing against local accounts.
- Remediation: Configure aaa local authentication attempts max-fail 3 (or per policy).

### [MEDIUM] AUTH-PWPOLICY

- Category: auth | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.1.5; STIG V-239914 (verified: True)
- Evidence: setting absent (absence)
- Rationale: No password policy is enforced by default; local account passwords may be weak.
- Remediation: Configure password-policy minimum-length and complexity (uppercase/lowercase/numeric/special).

### [MEDIUM] AUTH-PWRECOVERY

- Category: auth | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.1.4 (verified: True)
- Evidence: setting absent (absence)
- Rationale: Password recovery is enabled by default, allowing credential reset via console access.
- Remediation: Configure: no service password-recovery (ensure documented break-glass procedures).

### [MEDIUM] CRYPTO-PFS

- Category: crypto | Severity: Medium | Confidence: heuristic
- Authority: STIG V-239954 (verified: False)
- Evidence (line 123): `crypto map outside_map 10 match address split_tunnel`
- Rationale: A crypto map without Perfect Forward Secrecy (set pfs) weakens the protection of session keys.
- Remediation: Configure set pfs (group 14 or higher) on the crypto map.

### [MEDIUM] CRYPTO-SSL-CIPHER

- Category: crypto | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.7.3 (verified: False)
- Evidence (line 129): `ssl encryption rc4-sha1 aes128-sha1`
- Rationale: Weak SSL/TLS ciphers (RC4, DES/3DES, NULL, or a low/medium cipher level) are configured for management/WebVPN TLS.
- Remediation: Set ssl cipher to a high/strong cipher set (e.g., ssl cipher tlsv1.2 high).

### [MEDIUM] ICMP-TO-DEVICE

- Category: access | Severity: Medium | Confidence: heuristic
- Authority: CIS 2.5; Cisco hardening guide (verified: False)
- Evidence: setting absent (absence)
- Rationale: No ICMP control (icmp permit/deny) is configured, so ICMP to the device interfaces is allowed.
- Remediation: Restrict ICMP to the device with icmp deny/permit statements (e.g., icmp deny any outside).

### [MEDIUM] IF-URPF

- Category: access | Severity: Medium | Confidence: heuristic
- Authority: CIS 3.7; Cisco hardening guide (verified: False)
- Evidence: setting absent (absence)
- Rationale: Without uRPF (ip verify reverse-path), the device does not drop spoofed source addresses.
- Remediation: Enable ip verify reverse-path interface <untrusted-interface>.

### [MEDIUM] LOG-ENABLE

- Category: logging | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.10.1 (verified: True)
- Evidence: setting absent (absence)
- Rationale: Syslog logging is disabled by default; without it there is no audit trail.
- Remediation: Configure: logging enable.

### [MEDIUM] LOG-TRAP

- Category: logging | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.10 (trap level) (verified: False)
- Evidence: setting absent (absence)
- Rationale: Without a logging trap level set, syslog severity sent to hosts is not controlled.
- Remediation: Configure logging trap (e.g., notifications or informational).

### [MEDIUM] MGMT-ANY-SOURCE

- Category: management | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.6.1; CIS 1.7.1 (verified: False)
- Evidence (line 102): `http 0.0.0.0 0.0.0.0 outside`
- Additional evidence lines: 1
  - line 105: `ssh 0.0.0.0 0.0.0.0 outside`
- Rationale: Management access permitted from any source (0.0.0.0/0) exposes the control plane broadly.
- Remediation: Restrict ssh/http access lines to specific management subnets on an internal interface.

### [MEDIUM] NTP-AUTH

- Category: logging | Severity: Medium | Confidence: context-sensitive
- Authority: CIS 1.9.1.1; STIG V-239929 (verified: True)
- Evidence (line 112): `ntp server 10.10.20.7`
- Additional evidence lines: 1
  - line 113: `ntp server 203.0.113.53`
- Rationale: NTP without authentication can be spoofed, skewing time and undermining logs and certificates.
- Remediation: Enable ntp authenticate with an authentication-key and trusted-key for each ntp server.

### [MEDIUM] SNMP-COMMUNITY

- Category: logging | Severity: Medium | Confidence: deterministic
- Authority: CIS 1.11.1; STIG V-239928 (verified: False)
- Evidence (line 108): `snmp-server host inside 10.10.20.50 community [REDACTED] version 2c`
- Additional evidence lines: 1
  - line 109: `snmp-server community [REDACTED]`
- Rationale: SNMP v1/v2c community strings are cleartext, reusable credentials.
- Remediation: Replace SNMP v1/v2c communities with SNMPv3 using auth (SHA) and priv (AES).

### [MEDIUM] VERSION-EOL

- Category: management | Severity: Medium | Confidence: heuristic
- Authority: STIG V-239944; Cisco EoL notices (verified: False)
- Evidence (line 6): `ASA Version 9.8(4)`
- Rationale: The ASA software train is end-of-life per the bundled reference; EoL software receives no security fixes.
- Remediation: Upgrade to a currently-supported ASA release; verify against Cisco EoL notices (refresh the reference with Update-AsaEolData.ps1).

### [LOW] ACL-IMPLICIT-DENY-LOG

- Category: access | Severity: Low | Confidence: heuristic
- Authority: Cisco hardening guide (verified: False)
- Evidence (line 86): `access-group outside_in in interface outside`
- Rationale: An interface-bound ACL has no explicit "deny ip any any log"; traffic dropped by the implicit deny is not logged.
- Remediation: Append an explicit "deny ip any any log" to the bound access-list.

### [LOW] ACL-IMPLICIT-DENY-LOG

- Category: access | Severity: Low | Confidence: heuristic
- Authority: Cisco hardening guide (verified: False)
- Evidence (line 87): `access-group inside_in in interface inside`
- Rationale: An interface-bound ACL has no explicit "deny ip any any log"; traffic dropped by the implicit deny is not logged.
- Remediation: Append an explicit "deny ip any any log" to the bound access-list.

### [LOW] ACL-IMPLICIT-DENY-LOG

- Category: access | Severity: Low | Confidence: heuristic
- Authority: Cisco hardening guide (verified: False)
- Evidence (line 88): `access-group dmz_in in interface dmz`
- Rationale: An interface-bound ACL has no explicit "deny ip any any log"; traffic dropped by the implicit deny is not logged.
- Remediation: Append an explicit "deny ip any any log" to the bound access-list.

### [LOW] AUTH-BANNER

- Category: auth | Severity: Low | Confidence: deterministic
- Authority: CIS 1.5.3 (verified: True)
- Evidence: setting absent (absence)
- Rationale: No login banner is presented; a legal/consent notice is commonly required.
- Remediation: Configure a banner login with the organization-approved notice text.

### [LOW] AUTH-BANNER-MOTD

- Category: auth | Severity: Low | Confidence: deterministic
- Authority: CIS 1.5.1 (verified: False)
- Evidence: setting absent (absence)
- Rationale: No message-of-the-day banner is configured.
- Remediation: Configure a banner motd with the organization-approved text.

### [LOW] AUTH-CMD-ACCT

- Category: auth | Severity: Low | Confidence: deterministic
- Authority: CIS 1.4.5.1 (verified: False)
- Evidence: setting absent (absence)
- Rationale: Without command accounting, administrative actions are not audited.
- Remediation: Configure aaa accounting command <server-group>.

### [LOW] AUTH-PW-LIFETIME

- Category: auth | Severity: Low | Confidence: deterministic
- Authority: CIS 1.1.5 (verified: False)
- Evidence: setting absent (absence)
- Rationale: No password lifetime is enforced; local-account passwords never expire.
- Remediation: Configure password-policy lifetime (e.g., 90 days, per policy).

### [LOW] DNS-LOOKUP

- Category: logging | Severity: Low | Confidence: heuristic
- Authority: CIS 3.1 (verified: False)
- Evidence: setting absent (absence)
- Rationale: No DNS name-server is configured; the device cannot resolve FQDN objects, NTP names, or validate certificates by name.
- Remediation: Configure a dns server-group with one or more name-server entries.

### [LOW] IF-SCANNING-THREAT

- Category: access | Severity: Low | Confidence: deterministic
- Authority: STIG V-239864 (verified: False)
- Evidence: setting absent (absence)
- Rationale: Scanning threat detection is not enabled; host/port scans against the device are not detected.
- Remediation: Configure threat-detection scanning-threat (optionally with shun).

### [LOW] IF-THREAT-STATS

- Category: access | Severity: Low | Confidence: deterministic
- Authority: CIS 3.6 (verified: False)
- Evidence: setting absent (absence)
- Rationale: Threat-detection statistics are not collected, reducing visibility into attack patterns.
- Remediation: Configure threat-detection statistics (e.g., tcp-intercept).

### [LOW] LOG-BUFFER-SIZE

- Category: logging | Severity: Low | Confidence: deterministic
- Authority: CIS 1.10.9 (verified: False)
- Evidence (line 114): `logging buffered debugging`
- Rationale: Buffered logging is enabled with a small (or default 4 KB) buffer; CIS recommends at least 512 KB.
- Remediation: Set logging buffer-size to 524288 (512 KB) or larger.

### [LOW] LOG-TIMESTAMP

- Category: logging | Severity: Low | Confidence: deterministic
- Authority: CIS 1.10 (timestamps) (verified: False)
- Evidence: setting absent (absence)
- Rationale: Without logging timestamps, syslog correlation and incident timelines are unreliable.
- Remediation: Configure logging timestamp.

### [INFORMATIONAL] HYGIENE-UNUSED-ACL

- Category: hygiene | Severity: Informational | Confidence: heuristic
- Authority: tool heuristic (verified: False)
- Evidence (line 84): `access-list unused_acl extended permit udp any any eq domain`
- Rationale: An access-list defined but not referenced anywhere (access-group, crypto map, NAT, VPN filter) is dead configuration.
- Remediation: Review and remove the unused access-list if it is genuinely not needed.

### [INFORMATIONAL] HYGIENE-UNUSED-OBJECT

- Category: hygiene | Severity: Informational | Confidence: heuristic
- Authority: tool heuristic (verified: False)
- Evidence (line 54): `object network partner-fqdn`
- Rationale: An object or object-group defined but never referenced is dead configuration.
- Remediation: Review and remove the unused object or object-group if it is genuinely not needed.

### [INFORMATIONAL] HYGIENE-UNUSED-OBJECT

- Category: hygiene | Severity: Informational | Confidence: heuristic
- Authority: tool heuristic (verified: False)
- Evidence (line 65): `object-group network nested-admins`
- Rationale: An object or object-group defined but never referenced is dead configuration.
- Remediation: Review and remove the unused object or object-group if it is genuinely not needed.

### [INFORMATIONAL] HYGIENE-UNUSED-OBJECT

- Category: hygiene | Severity: Informational | Confidence: heuristic
- Authority: tool heuristic (verified: False)
- Evidence (line 72): `object-group service legacy-ports tcp`
- Rationale: An object or object-group defined but never referenced is dead configuration.
- Remediation: Review and remove the unused object or object-group if it is genuinely not needed.

### [INFORMATIONAL] HYGIENE-UNUSED-OBJECT

- Category: hygiene | Severity: Informational | Confidence: heuristic
- Authority: tool heuristic (verified: False)
- Evidence (line 75): `object-group protocol routing-protos`
- Rationale: An object or object-group defined but never referenced is dead configuration.
- Remediation: Review and remove the unused object or object-group if it is genuinely not needed.

