# Example output

These are real artifacts produced by running the tool against a synthesized,
deliberately-insecure ASA 9.x configuration — **not a live device.** No production
or client configuration is analyzed here. The sample triggers a broad set of
findings (39 risk + 5 informational). Secret values are masked, as in any default
run.

| File | What it is |
|------|------------|
| [`asa-9x-insecure_asa-review.md`](asa-9x-insecure_asa-review.md) | The Markdown findings report (also written to stdout) |
| [`asa-9x-insecure_asa-review.csv`](asa-9x-insecure_asa-review.csv) | The machine-readable findings, with remediation-tracking columns |
| [`asa-9x-insecure_asa-report.html`](asa-9x-insecure_asa-report.html) | The self-contained HTML deliverable (open in a browser; Print -> Save as PDF) |

The filenames here are stabilized for linking; a real run names each file with a
timestamp (`<config>_asa-review_<YYYYMMDD_HHMMSS>.md`, etc.). Regenerate from any
config with:

```powershell
.\Invoke-AsaReview.ps1 -ConfigPath .\your-config.txt -OutputDirectory .\examples
```
