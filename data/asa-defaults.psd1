#
# asa-defaults.psd1
#
# The ASA 9.x defaults model the absence-based MVP-15 checks consume
# (REQUIREMENTS FR-08b, DR-06). Loaded with Import-PowerShellDataFile (SR-08).
#
# Scoped to the MVP-15 absence / conditional-absence checks only (OQ-1). Each
# entry carries a Cisco documentation citation so the model has an EXTERNAL
# source of truth and is not a second fixture-circularity oracle (ARCHITECTURE
# section 5, second multi-AI pass). DefaultWhenAbsent states ASA platform
# behavior when the setting is omitted from running-config; FindingWhenAbsent is
# whether that absence is, by itself, a finding.
#
# Verified 2026-06-24 against the cited Cisco ASA configuration guides /
# release notes.
#
@{
    SchemaVersion = 1

    Defaults = @(
        @{
            CheckId           = 'MGMT-SSH-VERSION'
            Setting           = 'ssh version 2'
            DefaultWhenAbsent = 'not pinned (pre-9.16 the ssh version command exists and v2 is not explicitly enforced)'
            FindingWhenAbsent = $true
            VersionNote       = 'The ssh version command was removed in 9.16(1); from 9.16 only SSHv2 is supported, so this check is Not Applicable on 9.16+ and applies to 9.x < 9.16.'
            Rationale         = 'CIS recommends explicitly enforcing SSH version 2. On pre-9.16 ASA the version is not constrained unless pinned.'
            Authority         = 'CIS 1.6.2'
            DocCitation       = 'Cisco ASA 9.12 General Operations CLI Guide, Management Access (ssh version); ASA 9.16 Release Notes (ssh version command removed)'
            DocUrl            = 'https://www.cisco.com/c/en/us/td/docs/security/asa/asa912/configuration/general/asa-912-general-config/admin-management.html'
        }
        @{
            CheckId           = 'LOG-ENABLE'
            Setting           = 'logging enable'
            DefaultWhenAbsent = 'disabled (syslog logging is off by default)'
            FindingWhenAbsent = $true
            Rationale         = 'With logging disabled the device produces no syslog, defeating monitoring and incident response.'
            Authority         = 'CIS 1.10.1'
            DocCitation       = 'Cisco ASA 9.19 General Operations CLI Guide, Logging (logging enable)'
            DocUrl            = 'https://www.cisco.com/c/en/us/td/docs/security/asa/asa919/configuration/general/asa-919-general-config/monitor-syslog.html'
        }
        @{
            CheckId           = 'LOG-HOST'
            Setting           = 'logging host'
            DefaultWhenAbsent = 'no external syslog destination configured'
            FindingWhenAbsent = $true
            Rationale         = 'Without a syslog host, logs are not retained off-box and are lost on reload; STIG requires redundant hosts.'
            Authority         = 'CIS 1.10.3; STIG V-239943'
            DocCitation       = 'Cisco ASA 9.19 General Operations CLI Guide, Logging (logging host)'
            DocUrl            = 'https://www.cisco.com/c/en/us/td/docs/security/asa/asa919/configuration/general/asa-919-general-config/monitor-syslog.html'
        }
        @{
            CheckId           = 'AUTH-PWRECOVERY'
            Setting           = 'no service password-recovery'
            DefaultWhenAbsent = 'password recovery ENABLED (the no form must be present to disable it)'
            FindingWhenAbsent = $true
            Rationale         = 'With password recovery enabled, physical/console access permits credential reset; hardening disables it.'
            Authority         = 'CIS 1.1.4'
            DocCitation       = 'Cisco ASA 9.15 General Operations CLI Guide, Basic Settings (service password-recovery)'
            DocUrl            = 'https://www.cisco.com/c/en/us/td/docs/security/asa/asa915/configuration/general/asa-915-general-config/basic-hostname-pw.html'
        }
        @{
            CheckId           = 'AUTH-PWPOLICY'
            Setting           = 'password-policy minimum-length (and complexity)'
            DefaultWhenAbsent = 'no password policy enforced'
            FindingWhenAbsent = $true
            Rationale         = 'Without a password policy, weak local-account passwords are permitted; CIS/STIG require length and complexity.'
            Authority         = 'CIS 1.1.5; STIG V-239914'
            DocCitation       = 'Cisco ASA 9.15 General Operations CLI Guide, Basic Settings / AAA (password-policy)'
            DocUrl            = 'https://www.cisco.com/c/en/us/td/docs/security/asa/asa915/configuration/general/asa-915-general-config/basic-hostname-pw.html'
        }
        @{
            CheckId           = 'NTP-AUTH'
            Setting           = 'ntp authenticate'
            DefaultWhenAbsent = 'NTP authentication disabled'
            FindingWhenAbsent = $true
            Condition         = 'Only a finding when one or more ntp server lines are present (conditional absence).'
            Rationale         = 'Unauthenticated NTP can be spoofed, skewing time and undermining logs, certs, and tokens.'
            Authority         = 'CIS 1.9.1.1; STIG V-239929'
            DocCitation       = 'Cisco ASA 9.15 General Operations CLI Guide, Basic Settings (ntp authenticate)'
            DocUrl            = 'https://www.cisco.com/c/en/us/td/docs/security/asa/asa915/configuration/general/asa-915-general-config/basic-hostname-pw.html'
        }
        @{
            CheckId           = 'AUTH-AAA-SSH'
            Setting           = 'aaa authentication ssh console'
            DefaultWhenAbsent = 'SSH management uses the local line password, not AAA'
            FindingWhenAbsent = $true
            Rationale         = 'Without AAA on the SSH console, administrative access is not centrally authenticated/accounted.'
            Authority         = 'CIS 1.4.3.5; STIG V-239940'
            DocCitation       = 'Cisco ASA 9.19 General Operations CLI Guide, Management Access (aaa authentication ssh console)'
            DocUrl            = 'https://www.cisco.com/c/en/us/td/docs/security/asa/asa919/configuration/general/asa-919-general-config/admin-management.html'
        }
        @{
            CheckId           = 'AUTH-BANNER'
            Setting           = 'banner login'
            DefaultWhenAbsent = 'no login banner presented'
            FindingWhenAbsent = $true
            Rationale         = 'A login/consent banner is required for legal notice; absence is a common audit finding.'
            Authority         = 'CIS 1.5.3'
            DocCitation       = 'Cisco ASA 9.15 General Operations CLI Guide, Basic Settings (banner)'
            DocUrl            = 'https://www.cisco.com/c/en/us/td/docs/security/asa/asa915/configuration/general/asa-915-general-config/basic-hostname-pw.html'
        }
    )
}
