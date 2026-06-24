#
# check-catalog.psd1
#
# The MVP-15 security checks as declarative data (REQUIREMENTS DR-04, AR-05).
# Loaded with Import-PowerShellDataFile (SR-08). Metadata (severity, authority,
# profile, confidence, dependency, rationale, remediation) is data so benchmark
# revisions are absorbed without engine changes. Detector logic is split:
#   Type 'present'  -- finding when any Pattern matches a config line (data-driven)
#   Type 'absent'   -- finding when NO line matches Pattern (data-driven; the
#                      ASA default is in data/asa-defaults.psd1)
#   Type 'code'     -- a structural detector in src/checks/structural.ps1 that
#                      needs the support models (numeric, conditional, resolution)
#
# Profiles: every MVP check applies to both 'commercial' and 'dod'. DoD-specific
# checks (FIPS, exact banner text, etc.) are added under the dod profile later.
#
@{
    SchemaVersion = 1

    Checks = @(
        @{
            Id = 'MGMT-TELNET'; Category = 'management'; Severity = 'High'
            Profile = @('commercial','dod'); Authority = 'CIS 1.6.5; STIG V-239911'; Verified = $false
            Confidence = 'deterministic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'present'; Patterns = @('^telnet\s+\d') }
            Rationale = 'Telnet transmits management traffic, including credentials, in cleartext.'
            Remediation = 'Remove all telnet access lines and use SSHv2 for management.'
        }
        @{
            Id = 'MGMT-SSH-VERSION'; Category = 'management'; Severity = 'High'
            Profile = @('commercial','dod'); Authority = 'CIS 1.6.2'; Verified = $true
            Confidence = 'deterministic'; Dependency = @('defaults'); Kind = 'absence'
            Detector = @{ Type = 'absent'; Pattern = '^ssh version 2\b' }
            Rationale = 'Without pinning SSH version 2 (pre-9.16), weaker SSHv1 negotiation is not excluded.'
            Remediation = 'Configure: ssh version 2 (not applicable on ASA 9.16+, which is SSHv2-only).'
        }
        @{
            Id = 'MGMT-ANY-SOURCE'; Category = 'management'; Severity = 'Medium'
            Profile = @('commercial','dod'); Authority = 'CIS 1.6.1; CIS 1.7.1'; Verified = $false
            Confidence = 'deterministic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'present'; Patterns = @('^(ssh|http)\s+0\.0\.0\.0\s+0\.0\.0\.0\b') }
            Rationale = 'Management access permitted from any source (0.0.0.0/0) exposes the control plane broadly.'
            Remediation = 'Restrict ssh/http access lines to specific management subnets on an internal interface.'
        }
        @{
            Id = 'MGMT-CONSOLE-TIMEOUT'; Category = 'management'; Severity = 'High'
            Profile = @('commercial','dod'); Authority = 'CIS 1.8.1; STIG V-239920'; Verified = $false
            Confidence = 'deterministic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaConsoleTimeout' }
            Rationale = 'A console timeout of 0 (the default) or greater than 5 minutes leaves idle privileged sessions open.'
            Remediation = 'Set console timeout to a value between 1 and 5 minutes.'
        }
        @{
            Id = 'LOG-ENABLE'; Category = 'logging'; Severity = 'Medium'
            Profile = @('commercial','dod'); Authority = 'CIS 1.10.1'; Verified = $true
            Confidence = 'deterministic'; Dependency = @('defaults'); Kind = 'absence'
            Detector = @{ Type = 'absent'; Pattern = '^logging enable\b' }
            Rationale = 'Syslog logging is disabled by default; without it there is no audit trail.'
            Remediation = 'Configure: logging enable.'
        }
        @{
            Id = 'LOG-HOST'; Category = 'logging'; Severity = 'High'
            Profile = @('commercial','dod'); Authority = 'CIS 1.10.3; STIG V-239943'; Verified = $true
            Confidence = 'deterministic'; Dependency = @('defaults'); Kind = 'absence'
            Detector = @{ Type = 'absent'; Pattern = '^logging host\b' }
            Rationale = 'Without an external syslog host, logs are lost on reload and unavailable for correlation.'
            Remediation = 'Configure one or more logging host destinations (STIG requires two).'
        }
        @{
            Id = 'SNMP-COMMUNITY'; Category = 'logging'; Severity = 'Medium'
            Profile = @('commercial','dod'); Authority = 'CIS 1.11.1; STIG V-239928'; Verified = $false
            Confidence = 'deterministic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaSnmpCommunity' }
            Rationale = 'SNMP v1/v2c community strings are cleartext, reusable credentials.'
            Remediation = 'Replace SNMP v1/v2c communities with SNMPv3 using auth (SHA) and priv (AES).'
        }
        @{
            Id = 'CRYPTO-WEAK-VPN'; Category = 'crypto'; Severity = 'High'
            Profile = @('commercial','dod'); Authority = 'STIG V-239952/957/979'; Verified = $false
            Confidence = 'deterministic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'present'; Patterns = @(
                'esp-des\b','esp-3des\b','esp-md5-hmac\b','^crypto ikev1 ','^isakmp ',
                '^hash md5\b','^encryption (des|3des)\b','^group (1|2|5)\b'
            ) }
            Rationale = 'Deprecated IKE/IPsec crypto (DES/3DES, MD5, DH groups 1/2/5, IKEv1) is cryptographically weak.'
            Remediation = 'Migrate to IKEv2 with AES-256, SHA-2 integrity, and DH group 16 or higher.'
        }
        @{
            Id = 'CRYPTO-SSL-TLS'; Category = 'crypto'; Severity = 'High'
            Profile = @('commercial','dod'); Authority = 'CIS 1.7.2; STIG V-239975'; Verified = $false
            Confidence = 'deterministic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'present'; Patterns = @('^ssl server-version\s+(sslv3|tlsv1|tlsv1\.1)(\s|$)') }
            Rationale = 'SSL/TLS below TLS 1.2 (SSLv3, TLS 1.0/1.1) is deprecated and vulnerable.'
            Remediation = 'Set ssl server-version tlsv1.2 (or higher) for WebVPN/management TLS.'
        }
        @{
            Id = 'AUTH-PWRECOVERY'; Category = 'auth'; Severity = 'Medium'
            Profile = @('commercial','dod'); Authority = 'CIS 1.1.4'; Verified = $true
            Confidence = 'deterministic'; Dependency = @('defaults'); Kind = 'absence'
            Detector = @{ Type = 'absent'; Pattern = '^no service password-recovery\b' }
            Rationale = 'Password recovery is enabled by default, allowing credential reset via console access.'
            Remediation = 'Configure: no service password-recovery (ensure documented break-glass procedures).'
        }
        @{
            Id = 'AUTH-PWPOLICY'; Category = 'auth'; Severity = 'Medium'
            Profile = @('commercial','dod'); Authority = 'CIS 1.1.5; STIG V-239914'; Verified = $true
            Confidence = 'deterministic'; Dependency = @('defaults'); Kind = 'absence'
            Detector = @{ Type = 'absent'; Pattern = '^password-policy minimum-length\b' }
            Rationale = 'No password policy is enforced by default; local account passwords may be weak.'
            Remediation = 'Configure password-policy minimum-length and complexity (uppercase/lowercase/numeric/special).'
        }
        @{
            Id = 'NTP-AUTH'; Category = 'logging'; Severity = 'Medium'
            Profile = @('commercial','dod'); Authority = 'CIS 1.9.1.1; STIG V-239929'; Verified = $true
            Confidence = 'context-sensitive'; Dependency = @('defaults'); Kind = 'conditional-absence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaNtpAuth' }
            Rationale = 'NTP without authentication can be spoofed, skewing time and undermining logs and certificates.'
            Remediation = 'Enable ntp authenticate with an authentication-key and trusted-key for each ntp server.'
        }
        @{
            Id = 'ACL-ANY-ANY'; Category = 'access'; Severity = 'High'
            Profile = @('commercial','dod'); Authority = 'Cisco hardening guide'; Verified = $false
            Confidence = 'heuristic'; Dependency = @('resolved'); Kind = 'presence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaAclAnyAny' }
            Rationale = 'A permit ip any any rule allows unrestricted traffic; it may be overly broad.'
            Remediation = 'Review each permit ip any any rule and scope it to required sources, destinations, and services.'
        }
        @{
            Id = 'AUTH-AAA-SSH'; Category = 'auth'; Severity = 'High'
            Profile = @('commercial','dod'); Authority = 'CIS 1.4.3.5; STIG V-239940'; Verified = $true
            Confidence = 'deterministic'; Dependency = @('defaults'); Kind = 'absence'
            Detector = @{ Type = 'absent'; Pattern = '^aaa authentication ssh console\b' }
            Rationale = 'Without AAA on the SSH console, administrative access is not centrally authenticated or accounted.'
            Remediation = 'Configure aaa authentication ssh console <server-group> LOCAL.'
        }
        @{
            Id = 'AUTH-BANNER'; Category = 'auth'; Severity = 'Low'
            Profile = @('commercial','dod'); Authority = 'CIS 1.5.3'; Verified = $true
            Confidence = 'deterministic'; Dependency = @('defaults'); Kind = 'absence'
            Detector = @{ Type = 'absent'; Pattern = '^banner login\b' }
            Rationale = 'No login banner is presented; a legal/consent notice is commonly required.'
            Remediation = 'Configure a banner login with the organization-approved notice text.'
        }

        # --- Phase 6 / issue #1 hygiene checks (Informational) ---
        @{
            Id = 'HYGIENE-UNUSED-ACL'; Category = 'hygiene'; Severity = 'Informational'
            Profile = @('commercial','dod'); Authority = 'tool heuristic'; Verified = $false
            Confidence = 'heuristic'; Dependency = @('reference-index'); Kind = 'presence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaUnusedAcl' }
            Rationale = 'An access-list defined but not referenced anywhere (access-group, crypto map, NAT, VPN filter) is dead configuration.'
            Remediation = 'Review and remove the unused access-list if it is genuinely not needed.'
        }
        @{
            Id = 'HYGIENE-UNUSED-OBJECT'; Category = 'hygiene'; Severity = 'Informational'
            Profile = @('commercial','dod'); Authority = 'tool heuristic'; Verified = $false
            Confidence = 'heuristic'; Dependency = @('reference-index'); Kind = 'presence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaUnusedObject' }
            Rationale = 'An object or object-group defined but never referenced is dead configuration.'
            Remediation = 'Review and remove the unused object or object-group if it is genuinely not needed.'
        }
        @{
            Id = 'HYGIENE-INACTIVE-RULE'; Category = 'hygiene'; Severity = 'Informational'
            Profile = @('commercial','dod'); Authority = 'tool heuristic'; Verified = $false
            Confidence = 'deterministic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaInactiveRules' }
            Rationale = 'An ACE marked inactive, or referencing an expired time-range, is not enforced; review whether it should be removed or re-enabled.'
            Remediation = 'Review the inactive/expired rule and remove it or re-enable it as appropriate.'
        }
        @{
            Id = 'HYGIENE-IF-NOIP'; Category = 'hygiene'; Severity = 'Informational'
            Profile = @('commercial','dod'); Authority = 'tool heuristic'; Verified = $false
            Confidence = 'heuristic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaInterfaceNoIp' }
            Rationale = 'An interface with no IP address that is not shut down may be unused; an unused interface should be shut down.'
            Remediation = 'Review the interface; if unused, configure shutdown.'
        }
        @{
            Id = 'HYGIENE-BVI-UNUSED'; Category = 'hygiene'; Severity = 'Informational'
            Profile = @('commercial','dod'); Authority = 'tool heuristic'; Verified = $false
            Confidence = 'heuristic'; Dependency = @('raw'); Kind = 'presence'
            Detector = @{ Type = 'code'; Function = 'Test-AsaBvi' }
            Rationale = 'A BVI interface with no member interface in its bridge-group is unused.'
            Remediation = 'Configure shutdown on the unused BVI, or remove it (no interface BVIn).'
        }
    )
}
