# TEST_ENVIRONMENT.md

Where this project is tested. This is the durable record that makes the
success-claim guardrail enforceable: nothing is "shipped" until a real call
against a real service or device, in a defined environment, has returned data.

For this project there is no live device in the loop (the tool is offline, static
analysis). The "real call returns data" gate is therefore redefined, honestly: a
real parse of a real ASA `running-config`-format input that returns the correct
findings. The environment below is the analyst workstation plus the test corpus.

## Baseline (Cutaway development)

The tool runs and is tested on a standard analyst workstation, not on Proxmox
target VMs (there is no device to reach). The Proxmox baseline applies only if a
real ASA is ever introduced for end-to-end validation (not currently available).

| Element | Value |
|---------|-------|
| Hypervisor | Not required for the tool itself (no device interaction) |
| Test host | Windows workstation with Windows PowerShell 5.1 AND PowerShell 7+ |
| Network / segmentation | None — tool and tests run fully offline (SR-01) |
| Target devices / services | None — input is a static config text file (IR-01) |
| Test corpus | Synthesized ASA 9.x fixtures + 2 real sanitized configs (local) |
| Access path | Local filesystem only |

## Test corpus

1. **Synthesized fixture** (`tests/fixtures/`): syntactically faithful ASA 9.x
   config covering every CHECK_CATALOG Part B construct (incl. B6 lower-confidence
   branches), with seeded known-good and known-bad instances per MVP-15 check.
   Authored by the team — the primary functional oracle.
2. **Real sanitized configs** (`tests/fixtures/real/`, gitignored): at least two,
   sourced independently of the team (RESEARCH refs: HQ-FW2.txt, ASABuzzNick),
   obtained and stored locally as a one-time manual step. NEVER fetched over the
   network at dev time (that would contradict the offline posture, SR-01/OP-03).
   These break the fixture-as-oracle circularity (TR-07).

## Per-location deltas

| Location | Differences from baseline |
|----------|---------------------------|
| Windows PowerShell 5.1 | Feature floor; weaker regex (no `\K`/atomic groups); slower. Determinism (NFR-06) must be verified here. |
| PowerShell 7+ | Newer engine; results MUST match 5.1 as an identical finding set (TSC-09). |
| Air-gapped analyst host | Production posture — confirms zero egress and no dependency on installed modules (OP-03, NFR-05). |

## Provisioning

No infrastructure to provision. Setup is: install/confirm both PowerShell
runtimes, `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, install
Pester (dev only), and place the test corpus. Phase 1 in PLAN.md provisions the
corpus.

## Verification

The environment is ready when:

- `Invoke-Pester .\tests` runs (offline, no errors from missing modules).
- Both PowerShell runtimes are present and the entry script runs on each.
- The synthesized fixture and both real sanitized configs are present locally.
- A process monitor confirms zero network connections during a tool run (TSC-11),
  and the input file hash is unchanged after a run (read-only, SR-02).
