# VERDICT

**Accuracy:** The README is **largely accurate** but contains **several MUST-FIX errors** in factual claims (check count, scope, and output details). The drift between README and code is **non-trivial** and risks misleading users and AI agents.

**Usability (End Users):** The quick start is **correct and sufficient**, but **lacks critical context** (severity tiers, troubleshooting, output examples). The manual review checklist is **well-structured** but could benefit from **clarification on "not-assessed"**.

**Usability (AI Researchers/Agents):** The README is **explicit and falsifiable** in most places, but **lacks a concise facts block** and has **inconsistent terminology** (e.g., "58 checks" vs. actual count). Some claims are **overstated** (e.g., "fully offline" when `Update-AsaEolData.ps1` exists).

---

---

---

# **ACCURACY FINDINGS** (Prioritized)

### **MUST-FIX (High Priority)**
#### **1. Check Count Mismatch**
- **README Location:** "a **58-check** catalog" (Status section)
- **Contradicting Evidence:**
  - `data/check-catalog.psd1` contains **68 checks** (counted via `Checks.Count`).
  - `Invoke-AsaReview.ps1` dynamically counts checks per profile (line 60: `$checksEvaluated = ... | Measure-Object | Select-Object -ExpandProperty Count`).
- **Corrected Wording:**
  > "a **68-check** catalog (CIS + DISA STIG) with commercial and DoD profiles"

---

#### **2. Overclaimed Offline Behavior**
- **README Location:** "Makes no network calls at all" (Passive and offline by design)
- **Contradicting Evidence:**
  - `Update-AsaEolData.ps1` **explicitly uses `Invoke-RestMethod`** (line 30) to fetch EoL data from a URL.
  - The README correctly notes this script is **opt-in and separate**, but the absolute claim "no network calls at all" is **false for the repository as a whole**.
- **Corrected Wording:**
  > "The **review tool** (`Invoke-AsaReview.ps1`) makes no network calls at all. The separate, opt-in `Update-AsaEolData.ps1` script (not invoked by reviews) fetches EoL data from a URL."

---

#### **3. Incorrect HTML Output Claim (Inline SVG + No External Refs)**
- **README Location:** "a zone topology rendered as **inline SVG**, a zone-to-zone connectivity matrix as a colored table, and **no JavaScript or external references**" (How it works)
- **Contradicting Evidence:**
  - `src/Write-AsaHtmlReport.ps1` **includes an SVG namespace** (`xmlns='http://www.w3.org/2000/svg'`), which is a **URL reference** (though not fetched).
  - The claim "no external references" is **technically incorrect** (the namespace is an external reference, even if not fetched).
- **Corrected Wording:**
  > "a zone topology rendered as **inline SVG** (with standard namespace declaration), a zone-to-zone connectivity matrix as a colored table, and **no JavaScript or fetched external resources**"

---

#### **4. Missing Clarification on "not-assessed"**
- **README Location:** "Manual review checklist" (Item 6: "`not-assessed` items")
- **Contradicting Evidence:**
  - The README **does not explain** what "not-assessed" means in the context of the tool.
  - `src/checks/structural.ps1` (e.g., `Test-AsaNetworkGroupIsAny`) returns `Status = 'not-assessed'` for **unresolvable references** (e.g., circular object-groups, undefined objects).
  - `Invoke-AsaChecks.ps1` (line 100) **explicitly includes `not-assessed` findings in the output**.
- **Corrected Wording (Add to Manual Review Checklist):**
  > "**`not-assessed` items** — the tool could not resolve a reference (e.g., undefined object, circular object-group, or unresolved NAT). These require manual review to confirm if the rule is effective or dead."

---

#### **5. Overclaimed Scope (ASA 9.x Only)**
- **README Location:** "The tool analyzes a **Cisco ASA 9.x `show running-config`** text dump." (Where it works)
- **Contradicting Evidence:**
  - `src/ConvertTo-AsaModel.ps1` **does not enforce ASA 9.x syntax**—it parses **any ASA-like config** (including pre-9.0).
  - `data/asa-eol.psd1` includes **pre-9.0 trains** (e.g., 8.x is not listed, but the parser does not reject it).
  - The README **correctly notes** pre-9.0 "may parse but are not a target," but the **absolute claim** is misleading.
- **Corrected Wording:**
  > "The tool **targets** Cisco ASA 9.x `show running-config` text dumps. Pre-9.0 configs may parse but are **not validated** and may produce incomplete or inaccurate results."

---

### **SHOULD-FIX (Medium Priority)**
#### **6. Missing Explanation of Severity Tiers**
- **README Location:** No mention of **High/Medium/Low/Informational** severity tiers or their meaning.
- **Contradicting Evidence:**
  - `data/check-catalog.psd1` defines **4 severity levels** (`High`, `Medium`, `Low`, `Informational`).
  - `Invoke-AsaChecks.ps1` (line 115) **excludes Informational from risk counts** (only High/Medium/Low are counted in the summary).
- **Corrected Wording (Add to Quick Start or How It Works):**
  > "**Severity Tiers:**
  > - **High**: Critical issues (e.g., `permit ip any any`, cleartext management access).
  > - **Medium**: Significant risks (e.g., weak crypto, missing logging).
  > - **Low**: Minor hardening gaps (e.g., missing banners, unused interfaces).
  > - **Informational**: Hygiene findings (e.g., unused ACLs, inactive rules). *Excluded from risk counts.*"

---

#### **7. Missing Output Example**
- **README Location:** No **example output** (Markdown/HTML/CSV) is provided.
- **Impact:** Users cannot **visually verify** the tool’s output format before running it.
- **Recommended Addition:**
  - Add a **screenshot or snippet** of the HTML report (e.g., the segmentation SVG + findings table).
  - Add a **sample CSV row** (e.g., `CheckId,Category,Severity,Status,Evidence,...`).

---

#### **8. Inconsistent Check Count in Status Section**
- **README Location:** "a **58-check** catalog" (Status section) vs. **68 checks** in `data/check-catalog.psd1`.
- **Corrected Wording:**
  > "a **68-check** catalog (CIS + DISA STIG) with commercial and DoD profiles"

---

#### **9. Missing Troubleshooting for Execution Policy**
- **README Location:** Quick Start section **lacks** PowerShell execution policy guidance.
- **Impact:** Users on **restricted systems** may fail to run the tool.
- **Corrected Wording (Add to Quick Start):**
  > "**Troubleshooting:**
  > - If blocked by execution policy, run:
  >   ```powershell
  >   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  >   ```
  > - Works on **PowerShell 5.1+** (Windows) and **PowerShell 7+** (cross-platform)."

---

#### **10. Overclaimed "No Data Leaves the Host"**
- **README Location:** "No internet, no device access, **no data leaves the host**."
- **Contradicting Evidence:**
  - The **HTML report** (`*_asa-report_*.html`) is **written to disk** and could be **manually transferred** (e.g., via USB, email).
  - The claim is **technically true for the tool’s runtime** but **misleading** if interpreted as "no data can ever leave the host."
- **Corrected Wording:**
  > "The tool **does not transmit data** over the network. All output is written locally, but analysts must handle reports (especially with `-RevealSecrets`) as sensitive."

---

---

---

# **USABILITY FINDINGS**

## **For End Users / Security Analysts**
### **High Priority (MUST-FIX)**
1. **Missing Severity Tier Explanation**
   - **Issue:** Users **cannot interpret** High/Medium/Low/Informational without context.
   - **Fix:** Add a **dedicated section** explaining severity tiers (see **Accuracy Finding #6**).

2. **No Output Example**
   - **Issue:** Users **cannot preview** the report format.
   - **Fix:** Add a **screenshot or ASCII example** of the HTML/Markdown/CSV output.

3. **No Troubleshooting for Common Issues**
   - **Issue:** No guidance for **execution policy errors**, **PS 5.1 vs. 7+**, or **file permissions**.
   - **Fix:** Add a **Troubleshooting** subsection under Quick Start.

4. **"not-assessed" Meaning Unclear**
   - **Issue:** Users **do not know** how to handle `not-assessed` findings.
   - **Fix:** Clarify in the **Manual Review Checklist** (see **Accuracy Finding #4**).

### **Medium Priority (SHOULD-FIX)**
5. **Missing Example of `-ExpandAnyAny`**
   - **Issue:** The flag `-ExpandAnyAny` is **documented but not demonstrated**.
   - **Fix:** Add a **before/after example** of the HTML topology with/without `-ExpandAnyAny`.

6. **No Explanation of "Informational" Exclusion from Risk Counts**
   - **Issue:** Users may **misinterpret** why Informational findings are not counted.
   - **Fix:** Add a **note in the Summary section**:
     > "Risk counts exclude **Informational** findings (hygiene/cleanup items)."

7. **No Mention of `-Profile dod` Differences**
   - **Issue:** Users **do not know** how `-Profile dod` differs from `commercial`.
   - **Fix:** Add a **table comparing profiles** (e.g., DoD includes STIG-specific checks).

---

## **For AI Researchers / Agents**
### **High Priority (MUST-FIX)**
1. **Inconsistent Check Count**
   - **Issue:** The README claims **58 checks**, but the catalog has **68**.
   - **Impact:** AI agents **misrepresent** the tool’s coverage.
   - **Fix:** Update to **68 checks** (see **Accuracy Finding #1**).

2. **Missing Concise Facts Block**
   - **Issue:** No **machine-readable summary** (language, dependencies, inputs, outputs, scope).
   - **Fix:** Add a **YAML/JSON block** at the top:
     ```yaml
     ---
     name: cisco-asa-review
     language: PowerShell 5.1+
     dependencies: none (built-in cmdlets only)
     input: Cisco ASA 9.x `show running-config` (text file)
     outputs: Markdown (stdout + file), CSV, self-contained HTML
     scope: Single-context, routed-mode ASA 9.x (best-effort for others)
     checks: 68 (CIS + DISA STIG)
     license: GPL-3.0
     offline: true (no network calls in review path)
     ---
     ```

3. **Overclaimed Offline Behavior**
   - **Issue:** The README says **"no network calls at all"**, but `Update-AsaEolData.ps1` **does use the network**.
   - **Impact:** AI agents **incorrectly assume** the entire repo is offline.
   - **Fix:** Clarify that **only the review tool is offline** (see **Accuracy Finding #2**).

4. **Unstable Headings for AI Parsing**
   - **Issue:** Some headings are **narrative** (e.g., "Where this fits — and where it doesn't") and **hard to parse**.
   - **Fix:** Use **consistent, flat headings** (e.g., `## Scope`, `## Limitations`).

### **Medium Priority (SHOULD-FIX)**
5. **Missing Explicit License Reference**
   - **Issue:** The README **mentions GPL-3.0** but does not **link to the LICENSE file**.
   - **Fix:** Add:
     > "License: [GNU GPL-3.0](LICENSE)"

6. **No Version History or Changelog**
   - **Issue:** AI agents **cannot track changes** between versions.
   - **Fix:** Add a **Changelog** section (e.g., "v0.2: Added 10 checks, HTML report, EoL detection").

7. **Ambiguous "Manual Review Checklist" Scope**
   - **Issue:** The checklist **mixes tool limitations** (e.g., NAT exposure) with **manual validation steps** (e.g., certificate expiry).
   - **Fix:** Split into:
     - **Tool Limitations** (what the tool **cannot** detect)
     - **Manual Validation Steps** (what users **must** check)

---

---

---

# **TOP 5 RECOMMENDED EDITS** (Priority Order)

| # | **Edit** | **Type** | **Impact** | **Location** |
|---|---------|----------|------------|--------------|
| **1** | Fix check count from **58 → 68** (and ensure it matches `data/check-catalog.psd1`). | **MUST-FIX (Accuracy)** | High | README.md (Status section) |
| **2** | Clarify offline scope: **Only `Invoke-AsaReview.ps1` is offline**; `Update-AsaEolData.ps1` uses the network. | **MUST-FIX (Accuracy)** | High | README.md (Passive and offline by design) |
| **3** | Add a **concise facts block** (YAML/JSON) for AI agents (language, dependencies, inputs, outputs, scope, checks, license). | **MUST-FIX (Usability - AI)** | High | README.md (top of file) |
| **4** | Add **severity tier explanations** (High/Medium/Low/Informational) and note that **Informational is excluded from risk counts**. | **MUST-FIX (Usability - End Users)** | High | README.md (How it works or new section) |
| **5** | Add **troubleshooting** (execution policy, PS 5.1 vs. 7+, file permissions) and **output examples** (HTML/CSV snippets). | **SHOULD-FIX (Usability - End Users)** | Medium | README.md (Quick Start) |

---

---
**Final Note:**
The README is **well-structured and mostly accurate**, but the **check count drift, offline claim overreach, and missing severity explanations** are **critical issues** that must be fixed to prevent **user confusion and AI misrepresentation**. The **concise facts block** is the **highest-impact addition** for AI researchers.