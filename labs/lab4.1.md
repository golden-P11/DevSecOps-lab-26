# Lab 4.1 — SBOM Generation & SCA with Syft + Grype

![difficulty](https://img.shields.io/badge/difficulty-beginner-success)
![topic](https://img.shields.io/badge/topic-SBOM%20%2B%20SCA-blue)
![points](https://img.shields.io/badge/points-6-orange)
![tech](https://img.shields.io/badge/tech-Syft%20%2B%20Grype-informational)

> **Goal:** Generate CycloneDX and SPDX SBOMs of the Juice Shop image with Syft, scan the CycloneDX SBOM with Grype, and analyze the CVE findings.
> **Deliverable:** A PR from `feature/lab4.1` with `submissions/lab4.1.md` + `labs/lab4/juice-shop.cdx.json` and `labs/lab4/juice-shop.spdx.json` committed to your fork. Submit PR link via Moodle.

> **Part of Lab 4:** This is the first half of Lab 4. Complete **[Lab 4.2](lab4.2.md)** separately for Trivy comparison, sign-ready attestation, and the GitHub Actions pipeline.

---

## Overview

In this lab you will practice:
- Generating **CycloneDX** + **SPDX** SBOMs from a container image with **Syft**
- Scanning the same SBOM with **Grype** for CVEs (decoupled SCA)
- Analyzing severity breakdown and top CVE findings

> Recall Lecture 4 slide 11: *"the SBOM is the answer to the next Log4Shell question — do my services depend on this library?"* The artifact you produce today is the operational instrument for incident response.

---

## Project State

**You should have from Labs 1-3:**
- Juice Shop v20.0.0 image pulled locally (Lab 1)
- A working `feature/labN` workflow with signed commits (Labs 1, 3)
- A pre-commit hook blocking secret leaks (Lab 3)

**This lab adds:**
- A CycloneDX SBOM of the Juice Shop image, committed to your fork (becomes Lab 8 input)
- A reproducible Grype CVE scan

---

## Setup

You need:
- **Docker** (Juice Shop image already pulled from Lab 1; if not: `docker pull bkimminich/juice-shop:v20.0.0`)
- **`syft`** — (course pins Syft 1.x latest stable)
- **`grype`** —  (course pins Grype 0.x latest stable)
- **`jq`** — for JSON inspection

```bash
git switch main && git pull
git switch -c feature/lab4.1

# Verify tools are installed
syft version && grype version && jq --version

# Make a working dir for output (gitignored)
mkdir -p labs/lab4
```

---

## Task 1 — SBOM Generation & SCA with Syft + Grype (6 pts)

**Objective:** Generate two SBOM formats with Syft, run Grype against the CycloneDX SBOM, analyze the CVE findings.

### 4.1: Generate SBOMs with Syft

```bash
# CycloneDX JSON (the format Lab 8 will sign)
syft bkimminich/juice-shop:v20.0.0 \
  -o cyclonedx-json=labs/lab4/juice-shop.cdx.json

# SPDX JSON (for compliance contexts — covered in Lecture 4 slide 11)
syft bkimminich/juice-shop:v20.0.0 \
  -o spdx-json=labs/lab4/juice-shop.spdx.json

# Sanity check — both files exist and have content
ls -la labs/lab4/juice-shop.*.json
jq '.components | length' labs/lab4/juice-shop.cdx.json
# Should print a number like 200-500 (depends on Juice Shop v20 image contents)
```

### 4.2: Run Grype against the CycloneDX SBOM

> **Why scan the SBOM, not the image?** Decoupling the inventory (Syft) from the scanning (Grype) means: one SBOM → many scans over time. When a new CVE drops next month, re-running Grype on the same SBOM tells you instantly whether you're affected — no re-pulling the image.

```bash
# Scan via SBOM (the modern decoupled pattern)
grype sbom:labs/lab4/juice-shop.cdx.json \
  -o json --file labs/lab4/grype-from-sbom.json
grype sbom:labs/lab4/juice-shop.cdx.json \
  -o table | tee labs/lab4/grype-from-sbom.txt

# Severity breakdown
jq '[.matches[].vulnerability.severity] | group_by(.) | map({severity: .[0], count: length})' \
  labs/lab4/grype-from-sbom.json
```

### 4.3: Analyze the top findings

```bash
# Top 10 CVEs by severity, with fix availability
jq '[.matches[] | {cve: .vulnerability.id, severity: .vulnerability.severity,
                    package: .artifact.name, version: .artifact.version,
                    fix: (.vulnerability.fix.versions // [] | join(","))}] |
    sort_by(.severity) | .[:10]' \
  labs/lab4/grype-from-sbom.json
```

### 4.4: Document in `submissions/lab4.1.md`

```markdown
# Lab 4.1 — Submission

## Task 1: Syft + Grype on Juice Shop

### SBOM stats
- `juice-shop.cdx.json` component count: <jq '.components | length' output>
- `juice-shop.cdx.json` size: <ls output>
- `juice-shop.spdx.json` component count: <jq '.packages | length' output>

### Grype severity breakdown (paste table or JSON)
| Severity | Count |
|----------|------:|
| Critical | <n> |
| High | <n> |
| Medium | <n> |
| Low | <n> |
| Negligible | <n> |
| **Total** | <n> |

### Top 10 CVEs (paste from jq output)
| CVE | Severity | Package | Installed | Fix |
|-----|----------|---------|-----------|-----|
| <CVE-id> | <Sev> | <pkg> | <ver> | <fix or empty> |
| ... |

### Fix-available rate
Out of the top 10 CVEs, how many have a fix available? What does that say about your
patch cadence priorities? (2-3 sentences. Reference Lecture 4's triage shortcut:
*sort by fix-available AND severity ≥ HIGH first*.)
```

---

## How to Submit

```bash
# Commit the SBOM files (so Lab 8 can use them) but NOT the scan output files (too large, regenerable)
git add labs/lab4/juice-shop.cdx.json
git add labs/lab4/juice-shop.spdx.json
git add submissions/lab4.1.md
git commit -m "feat(lab4.1): juice-shop SBOMs + Grype CVE analysis"
git push -u origin feature/lab4.1
```

> **Do NOT commit** `labs/lab4/grype-from-sbom.*` — they're regeneratable and large. Add them to your fork's `.gitignore` if helpful. The submission paste-in is the evidence.

PR checklist body:

```text
- [x] Task 1 — Syft SBOMs + Grype scan + top-10 CVE analysis
```

---

## Acceptance Criteria

### Task 1 (6 pts)
- ✅ `labs/lab4/juice-shop.cdx.json` and `juice-shop.spdx.json` exist in the PR
- ✅ Grype scan completes; severity breakdown table in submission matches actual JSON
- ✅ Top-10 CVE table populated with real CVE IDs (no placeholders); fix-availability shown
- ✅ Fix-available analysis (2-3 sentences) references Lecture 4's triage shortcut

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — Syft + Grype | **6** | Both SBOM formats + Grype severity table + top-10 CVE table + fix-availability triage analysis |
| **Total** | **6** | |

---
