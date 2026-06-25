#
# asa-eol.psd1
#
# Bundled Cisco ASA software/hardware End-of-Life reference (FR-15, DR-05).
# Loaded with Import-PowerShellDataFile (SR-08). Used OFFLINE during a review.
#
# This is a maintained SNAPSHOT as of ReferenceDate -- it is not authoritative.
# Verify against Cisco's ASA EoL/EoS notices and PSIRT advisories. Refresh it on
# a connected machine with Update-AsaEolData.ps1 (the review itself never reaches
# the network).
#
@{
    SchemaVersion = 1
    ReferenceDate = '2026-06-24'
    Source        = 'Bundled snapshot; verify against Cisco ASA EoL/EoS notices and PSIRT.'
    DocUrl        = 'https://www.cisco.com/c/en/us/products/security/asa-5500-series-next-generation-firewalls/eos-eol-notice-listing.html'

    # Hardware end-of-support (Informational; the platform itself is no longer maintained).
    Hardware = @(
        @{ Model = 'ASA5515'; Status = 'end-of-support'; Note = 'ASA 5515-X has reached last-day-of-support; the platform is no longer maintained -- plan migration.' }
    )

    # Software trains. Status: EoL | Supported | Unknown. Snapshot as of ReferenceDate.
    Trains = @(
        @{ Train = '9.1';  Status = 'EoL' }
        @{ Train = '9.2';  Status = 'EoL' }
        @{ Train = '9.4';  Status = 'EoL' }
        @{ Train = '9.6';  Status = 'EoL' }
        @{ Train = '9.8';  Status = 'EoL' }
        @{ Train = '9.10'; Status = 'EoL' }
        @{ Train = '9.12'; Status = 'EoL' }
        @{ Train = '9.14'; Status = 'EoL' }
        @{ Train = '9.16'; Status = 'Supported' }
        @{ Train = '9.18'; Status = 'Supported' }
        @{ Train = '9.19'; Status = 'Supported' }
        @{ Train = '9.20'; Status = 'Supported' }
        @{ Train = '9.22'; Status = 'Supported' }
    )
    DefaultStatusForUnlisted = 'Unknown'
}
