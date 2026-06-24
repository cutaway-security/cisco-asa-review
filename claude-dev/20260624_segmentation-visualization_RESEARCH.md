# Segmentation & Data-Flow Visualization — Representation Research

**Project:** cisco-asa-review
**Date:** 2026-06-24
**Status:** Research complete; decision recorded; feeds a planned visualization output (PLAN Phase 5)
**Scope of this doc:** how to represent ASA network segmentation + data flow visually, offline, for use in conversations and reports.

---

## 1. Question

Add a NEW output that visualizes (a) network segmentation and (b) data flow
between segments, derived purely from the static ASA running-config, highlighting
risk conditions (especially `permit ip any any`). Used live in client
conversations AND embedded in written assessment reports. Must remain offline and
sensitive-data-safe (no online rendering services).

## 2. Findings — representation

- **Aggregate to the security ZONE, not the host.** Derive zones from `nameif` +
  `security-level`; optionally group zones into trust tiers (untrusted sl0 / dmz /
  trusted high). Zone aggregation is the single biggest readability win and
  matches how segmentation is discussed (IEC 62443 zones-and-conduits / Purdue).
  Per-host rendering produces an unreadable hairball.
- **No single view serves both use cases.** A **node-link topology** wins for
  *live conversation* (path-following: you point at the route). A **zone-to-zone
  matrix** wins for the *written report* (compact, exhaustive, deterministic
  layout, nothing hides). Established infovis result: matrices beat node-link for
  dense graphs / >~20 nodes; node-link wins for path-following.
- **The mature tools ship BOTH plus a path trace** that names the offending rule:
  Tufin (Topology Map + Unified Security Policy zone matrix + Path Analysis),
  FireMon (Map + literal Zone Matrix + flow analysis flagging broad "Any" rules),
  RedSeal (topology + tri-color Zones & Policies matrix + path query). Consistent
  color language: green/red/amber = allowed/blocked/partial.
- **Differentiation:** the two tools closest to this project's niche — **Titania
  Nipper and Cisco Defense Orchestrator — do NOT visualize segmentation at all**
  (findings tables only). Adding a map + matrix is genuinely additive.
- **Academic grounding:** src×dst reachability matrices (Fang/Lumeta, Quarnet) and
  packet-space grids (FAME, PolicyVis) are the established matrix idioms; Wool's
  studies show permissive "Any" rules are a top real-world error class — evidence
  for prominently flagging `permit ip any any`.

## 3. Findings — risk highlighting

- **Never color alone (WCAG 1.4.1).** Pair every risk color with a redundant cue
  (severity label / badge / icon) so it survives grayscale printing and
  color-vision deficiency. Red-green is the worst pairing.
- Prefer a **sequential severity scale** (light→dark) with documented bands;
  colorblind/photocopy-safe palette (ColorBrewer/viridis). A `permit ip any any`
  is the darkest band by construction.
- Use **preattentive cues sparingly**: thick + highest-severity color + badge on
  the top-N risky flows only (not everything) — emphasis works because it's the
  exception.
- **Name the offending rule** on the risky edge/cell (the practitioner-valued
  pattern). Reuse the tool's existing finding `severity` + evidence (config line +
  finding id) so the map, the matrix, the findings report, and the CSV speak one
  risk language.

## 4. Findings — offline diagram-as-code format

The tool emits TEXT only; rendering must be local/offline (no mermaid.live, no
SaaS). Comparison for THIS constraint set (offline, PS 5.1+, sensitive):

| Format | Offline render on Windows | PS-gen ease | Risk styling | Embeds in MD | Install footprint |
|---|---|---|---|---|---|
| **Connectivity matrix (MD/HTML table)** | Native, no render step | Trivial | Colored cells + labels | It IS the MD/HTML | **Zero** |
| **Mermaid (flowchart)** | Native in VS Code / GitLab / GitHub; image export needs mermaid-cli (heavy) | Easy | classDef + linkStyle (red edges) | Native ```mermaid block | **Zero** in those viewers |
| **Graphviz DOT** | `dot` binary → SVG/PNG | Easy | Excellent (cluster zones, edge colors) | Embed rendered SVG | One native binary |
| D2 | single Go binary → SVG | Easy | Themes/styles | Embed SVG | One binary (+ disable update check) |
| PlantUML | JAR + JRE | Medium | Yes | Embed PNG | Heaviest (Java) |
| Hand-emitted SVG | Native (browser) | Hard (manual layout) | Full | `<img>`/inline | Zero, but you own layout |

**Format conclusion:** emit a **zero-install connectivity matrix** (Markdown/HTML)
+ **Mermaid topology source** (renders in VS Code/GitLab/GitHub with nothing
installed; `classDef`/`linkStyle` give red ANY/ANY edges). Optional Graphviz DOT
emitter for a heavyweight standalone SVG when `dot` is available. The matrix needs
no rendering at all; Mermaid rendering is the analyst's local step — **no online
tool is ever used**, consistent with the tool's offline guard.

## 5. Decision (recorded 2026-06-24)

- **Package B:** zone-level **Mermaid topology** (risky flows as thick red edges,
  labeled with the ACL line) **+ severity-colored zone-to-zone matrix**.
- **Delivery:** a **separate output file** written next to the config (distinct
  from the findings MD/CSV).
- **Invocation:** **always produced** on every run (no flag).
- Zones derived from `nameif` + `security-level` (reusing the interface-role
  model); flows derived from `access-group`-bound ACL permit ACEs; ANY/ANY and
  high-severity flows highlighted; each tied to the offending ACL line + finding.

## 6. Important boundary (carried into VISION / ARCHITECTURE)

This visualization shows **configured/allowed flows per the ruleset** (what the
ACLs, as bound by access-group, permit), **NOT computed end-to-end dataplane
reachability** (which would require modeling routing, NAT translation, and
rule-order/shadowing across the whole path — Batfish territory, OOS-02). A
segmentation MAP from config is not a reachability proof; the output must say so
to avoid overclaiming. Addresses that cannot be mapped to a configured interface
zone are shown as an explicit "external/unknown" zone, never silently dropped.

## 7. References (selected, from the two research passes)

- IEC 62443 zones & conduits; Microsoft STRIDE / OWASP trust boundary (DFD).
- Tufin USP zone matrix — https://forum.tufin.com/support/kc/latest/Content/Suite/ST2/USP/USP.htm
- FireMon Zone Matrix — https://docs.firemon.com/ (Zone Matrix / Map)
- RedSeal zones & policies — https://redseal.net/platform/
- Nipper (no diagrams) — https://www.titania.com/products/nipper ; Cisco CDO — https://docs.defenseorchestrator.com/
- Batfish reachability (data, not pictures) — https://batfish.readthedocs.io/
- Ghoniem/Fekete/Castagliola (matrix vs node-link crossover); Wool firewall-error studies — https://arxiv.org/pdf/0911.1240 ; FAME/PolicyVis/Quarnet (matrix idioms).
- Mermaid flowchart (classDef/linkStyle) — https://mermaid.js.org/syntax/flowchart.html ; GitHub native render — https://github.blog/developer-skills/github/include-diagrams-markdown-files-mermaid/ ; GitLab — https://docs.gitlab.com/ee/user/markdown.html
- Graphviz clusters/colors — https://graphviz.org/doc/info/attrs.html ; download — https://graphviz.org/download/
- WCAG 1.4.1 use-of-color; ColorBrewer (colorblind/photocopy-safe).

(Full per-claim citations and confidence flags are preserved in the two research-agent transcripts referenced from this session.)
