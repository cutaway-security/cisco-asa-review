#
# expected-findings.psd1
#
# The validation oracle for the MVP-15 checks (SUCCESS_CRITERIA TSC-02/03,
# REQUIREMENTS TR-02). Loaded with Import-PowerShellDataFile (data-only).
#
# This file fixes the canonical MVP-15 check IDs (which become the catalog IDs
# in Phase 4) and states, per fixture, which checks MUST fire (true positives)
# and which MUST NOT (true negatives). Authored 2026-06-24 alongside the
# fixtures; the checks do not exist yet (Phase 4), so this is the spec they are
# built and tested against, not a record of tool output.
#
# Absence-based checks carry EvidenceKind = 'absent' (the finding is the missing
# line); presence-based checks carry an EvidenceMatch substring that must appear
# in the cited config line.
#
@{
    SchemaVersion = 1

    # The 15 high-signal MVP checks (CHECK_CATALOG A8). Profile: all 'commercial'.
    Checks = @(
        @{ Id = 'MGMT-TELNET';          Category = 'management'; Severity = 'High';   Kind = 'presence'; Authority = 'CIS 1.6.5; STIG V-239911' }
        @{ Id = 'MGMT-SSH-VERSION';     Category = 'management'; Severity = 'High';   Kind = 'absence';  Authority = 'CIS 1.6.2' }
        @{ Id = 'MGMT-ANY-SOURCE';      Category = 'management'; Severity = 'Medium'; Kind = 'presence'; Authority = 'CIS 1.6.1; CIS 1.7.1' }
        @{ Id = 'MGMT-CONSOLE-TIMEOUT'; Category = 'management'; Severity = 'High';   Kind = 'presence'; Authority = 'CIS 1.8.1; STIG V-239920' }
        @{ Id = 'LOG-ENABLE';           Category = 'logging';    Severity = 'Medium'; Kind = 'absence';  Authority = 'CIS 1.10.1' }
        @{ Id = 'LOG-HOST';             Category = 'logging';    Severity = 'High';   Kind = 'absence';  Authority = 'CIS 1.10.3; STIG V-239943' }
        @{ Id = 'SNMP-COMMUNITY';       Category = 'logging';    Severity = 'Medium'; Kind = 'presence'; Authority = 'CIS 1.11.1; STIG V-239928' }
        @{ Id = 'CRYPTO-WEAK-VPN';      Category = 'crypto';     Severity = 'High';   Kind = 'presence'; Authority = 'STIG V-239952/957/979' }
        @{ Id = 'CRYPTO-SSL-TLS';       Category = 'crypto';     Severity = 'High';   Kind = 'presence'; Authority = 'CIS 1.7.2; STIG V-239975' }
        @{ Id = 'AUTH-PWRECOVERY';      Category = 'auth';       Severity = 'Medium'; Kind = 'absence';  Authority = 'CIS 1.1.4' }
        @{ Id = 'AUTH-PWPOLICY';        Category = 'auth';       Severity = 'Medium'; Kind = 'absence';  Authority = 'CIS 1.1.5; STIG V-239914' }
        @{ Id = 'NTP-AUTH';             Category = 'logging';    Severity = 'Medium'; Kind = 'conditional-absence'; Authority = 'CIS 1.9.1.1; STIG V-239929' }
        @{ Id = 'ACL-ANY-ANY';          Category = 'access';     Severity = 'High';   Kind = 'presence'; Authority = 'Cisco hardening guide' }
        @{ Id = 'AUTH-AAA-SSH';         Category = 'auth';       Severity = 'High';   Kind = 'absence';  Authority = 'CIS 1.4.3.5; STIG V-239940' }
        @{ Id = 'AUTH-BANNER';          Category = 'auth';       Severity = 'Low';    Kind = 'absence';  Authority = 'CIS 1.5.3' }
    )

    Fixtures = @{

        'asa-5515-insecure.txt' = @{
            Description = 'Known-bad ASA 5515 config. MUST trigger all 15 MVP findings. Construct-complete for parser tests (incl. B6 legacy object-group forms, nt-encrypted, 3-deep group-policy nesting, both NAT shapes, global webvpn).'
            # Each entry: the check MUST produce a finding. EvidenceMatch is a
            # substring expected in the cited line (presence) or 'absent'.
            MustFire = @(
                @{ Id = 'MGMT-TELNET';          EvidenceKind = 'presence'; EvidenceMatch = 'telnet 10.10.20.0 255.255.255.0 inside' }
                @{ Id = 'MGMT-SSH-VERSION';     EvidenceKind = 'absent';   EvidenceMatch = 'no ssh version 2 line present' }
                @{ Id = 'MGMT-ANY-SOURCE';      EvidenceKind = 'presence'; EvidenceMatch = 'ssh 0.0.0.0 0.0.0.0 outside' }
                @{ Id = 'MGMT-CONSOLE-TIMEOUT'; EvidenceKind = 'presence'; EvidenceMatch = 'console timeout 0' }
                @{ Id = 'LOG-ENABLE';           EvidenceKind = 'absent';   EvidenceMatch = 'no logging enable line present' }
                @{ Id = 'LOG-HOST';             EvidenceKind = 'absent';   EvidenceMatch = 'no logging host line present' }
                @{ Id = 'SNMP-COMMUNITY';       EvidenceKind = 'presence'; EvidenceMatch = 'snmp-server community publicstring' }
                @{ Id = 'CRYPTO-WEAK-VPN';      EvidenceKind = 'presence'; EvidenceMatch = 'esp-3des esp-md5-hmac' }
                @{ Id = 'CRYPTO-SSL-TLS';       EvidenceKind = 'presence'; EvidenceMatch = 'ssl server-version tlsv1' }
                @{ Id = 'AUTH-PWRECOVERY';      EvidenceKind = 'absent';   EvidenceMatch = 'no service password-recovery line present' }
                @{ Id = 'AUTH-PWPOLICY';        EvidenceKind = 'absent';   EvidenceMatch = 'no password-policy lines present' }
                @{ Id = 'NTP-AUTH';             EvidenceKind = 'conditional-absent'; EvidenceMatch = 'ntp server present without ntp authenticate' }
                @{ Id = 'ACL-ANY-ANY';          EvidenceKind = 'presence'; EvidenceMatch = 'access-list outside_in extended permit ip any any' }
                @{ Id = 'AUTH-AAA-SSH';         EvidenceKind = 'absent';   EvidenceMatch = 'no aaa authentication ssh console line present' }
                @{ Id = 'AUTH-BANNER';          EvidenceKind = 'absent';   EvidenceMatch = 'no banner login line present' }
            )
            # Secret-classification expectations (v0.1b-prep, FR-09/FR-10, TSC-05).
            Secrets = @(
                @{ Line = 'enable password 8Ry2YjIyt7RRXU24 encrypted'; Class = 'weak-encrypted' }
                @{ Line = 'username legacy password 0123456789abcdef nt-encrypted privilege 3'; Class = 'not-cleartext' }
                @{ Line = 'username backdoor password SuperSecret123 privilege 15'; Class = 'cleartext' }
                @{ Line = 'key cleartextradiuskey123'; Class = 'cleartext' }
                @{ Line = 'snmp-server community publicstring'; Class = 'cleartext' }
                @{ Line = 'ikev1 pre-shared-key cleartextpsk456'; Class = 'cleartext' }
                @{ Line = 'username admin password $sha512$'; Class = 'strong-pbkdf2' }
            )
            # Parser-construct coverage assertions (TR-03). Each must be present
            # and correctly modeled.
            ConstructsPresent = @(
                'header-metadata-colon', 'asa-version', 'interface-block',
                'interface-shutdown', 'names-and-name', 'object-network-host',
                'object-network-subnet', 'object-network-range', 'object-network-fqdn',
                'object-service', 'object-group-network', 'object-group-network-nested',
                'object-group-service-modern', 'object-group-service-legacy-tcp',
                'object-group-protocol', 'access-list-extended', 'access-list-remark',
                'access-list-standard', 'access-list-objgroup-ref', 'access-group-binding',
                'object-nat', 'twice-nat', 'aaa-server-block-with-key',
                'password-pbkdf2', 'password-encrypted', 'password-nt-encrypted',
                'password-cleartext', 'ssh-line', 'telnet-line', 'http-line',
                'snmp-community', 'crypto-ikev1-policy', 'crypto-ipsec-transform-set',
                'crypto-map', 'tunnel-group-ipsec', 'tunnel-group-remote-access',
                'group-policy-attributes', 'group-policy-webvpn-nested', 'webvpn-global'
            )
        }

        'asa-5515-hardened.txt' = @{
            Description = 'Known-good ASA 5515 config. MUST trigger NONE of the 15 MVP findings (true negatives). Includes multi-line banner for parser reassembly test, strong ikev2 crypto, SNMPv3, authenticated NTP, scoped management.'
            MustNotFire = @(
                'MGMT-TELNET', 'MGMT-SSH-VERSION', 'MGMT-ANY-SOURCE', 'MGMT-CONSOLE-TIMEOUT',
                'LOG-ENABLE', 'LOG-HOST', 'SNMP-COMMUNITY', 'CRYPTO-WEAK-VPN',
                'CRYPTO-SSL-TLS', 'AUTH-PWRECOVERY', 'AUTH-PWPOLICY', 'NTP-AUTH',
                'ACL-ANY-ANY', 'AUTH-AAA-SSH', 'AUTH-BANNER'
            )
            # Parser features this fixture specifically exercises.
            ConstructsPresent = @(
                'multiline-banner-login', 'ssh-version-2', 'urpf-interface',
                'snmp-v3-priv', 'ntp-authenticated', 'crypto-ikev2-policy',
                'crypto-ipsec-proposal-block', 'password-policy-lines',
                'no-service-password-recovery', 'tunnel-group-ikev2-psk'
            )
            Secrets = @(
                @{ Line = 'enable password $sha512$'; Class = 'strong-pbkdf2' }
                @{ Line = 'ntp authentication-key 1 md5 sharedntpkey'; Class = 'cleartext-ntp-key' }
            )
        }
    }
}
