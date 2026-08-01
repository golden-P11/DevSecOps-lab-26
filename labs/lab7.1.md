# Lab 7.1 — Trivy Image + Misconfig Scan

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Container%20Security-blue)
![points](https://img.shields.io/badge/points-6-orange)
![tech](https://img.shields.io/badge/tech-Trivy-informational)

> **Goal:** Scan Juice Shop image with Trivy (CVE + misconfig) and triage findings by fix availability; compare with Lab 4's Grype results.
> **Deliverable:** A PR from `feature/lab7.1` with `submissions/lab7.1.md` (severity tables + Grype comparison). Submit PR link via Moodle.

> **Part of Lab 7:** This is the first part of Lab 7. Complete **[Lab 7.2](lab7.2.md)** (Kubernetes hardening) and **[Lab 7.3](lab7.3.md)** (Conftest + CI) separately.

---

## Overview

In this lab you will practice:
- **Trivy v0.69.x** in `image` and `config` modes (Lecture 7 slide 8)
- Triage by fix availability — "fix available AND severity ≥ HIGH first" (Lecture 7 slide 9)
- Comparing scanner output across tools (Trivy vs Lab 4's Grype)

> Recall Lecture 7 slide 4 — "containers don't contain". Image scanning tells you what's inside the box before you deploy it.

---

## Project State

**You should have from Labs 1-6:**
- Juice Shop v20.0.0 image pulled (Lab 1)
- Sign-ready CycloneDX SBOM at `labs/lab4/juice-shop.cdx.json` (Lab 4 bonus)
- Grype scan results from Lab 4 for comparison
- Signed commits + pre-commit gitleaks (Lab 3)

**This lab adds:**
- Trivy image scan + Dockerfile misconfig scan of Juice Shop
- Top-10 CVE triage and Grype-vs-Trivy comparison

---

## Setup

You need:
- **Docker**
- **Trivy v0.69.x** — `brew install trivy` or [GitHub releases](https://github.com/aquasecurity/trivy/releases)
- **`jq`**

```bash
git switch main && git pull
git switch -c feature/lab7.1

# Verify
trivy --version && docker --version

mkdir -p labs/lab7/results
```

---

## Task 1 — Trivy Image + Misconfig Scan (6 pts)

**Objective:** Run Trivy in two modes against Juice Shop and analyze the findings.

### 7.1.1: Image vulnerability scan

```bash
trivy image bkimminich/juice-shop:v20.0.0 \
  --severity HIGH,CRITICAL \
  --format json --output labs/lab7/results/trivy-image.json

trivy image bkimminich/juice-shop:v20.0.0 \
  --severity HIGH,CRITICAL \
  --format table | tee labs/lab7/results/trivy-image.txt
```

### 7.1.2: Dockerfile misconfig scan

```bash
# We don't have Juice Shop's Dockerfile, but we WILL write our own K8s manifest
# in Lab 7.2. For now, scan a sample Dockerfile to learn the workflow.
cat > /tmp/Dockerfile-bad <<'EOF'
FROM node:latest                      # CKV_DOCKER_3: avoid :latest
USER root                             # CKV_DOCKER_8: USER non-root
EXPOSE 22                             # CKV_DOCKER_1: don't expose SSH
ADD https://example.com/app.tar /     # CKV_DOCKER_4: ADD URL is risky
EOF

trivy config /tmp/Dockerfile-bad --severity HIGH,CRITICAL --format table
```

### 7.1.3: Triage by fix availability

```bash
# Top 10 CVEs with fixes (Lecture 7 slide 9 — "fix available AND severity ≥ HIGH first")
jq '[.Results[].Vulnerabilities[]? | select(.FixedVersion != null) |
    {cve: .VulnerabilityID, severity: .Severity, pkg: .PkgName, installed: .InstalledVersion, fix: .FixedVersion}] |
    sort_by(.severity) | .[:10]' \
  labs/lab7/results/trivy-image.json
```

### 7.1.4: Document in `submissions/lab7.1.md`

```markdown
# Lab 7.1 — Submission

## Task 1: Trivy Image + Config Scan

### Image scan severity breakdown
| Severity | Total | With fix available |
|----------|------:|------------------:|
| Critical | <n> | <m> |
| High | <n> | <m> |
| **Total** | <n> | <m> |

### Top 10 CVEs with fixes
| CVE | Severity | Package | Installed | Fix |
|-----|----------|---------|-----------|-----|
| ... |

### Compared to Lab 4's Grype scan
Look back at your Lab 4 Grype results on the same image. Pick **two CVEs**:
1. One that BOTH Grype and Trivy found
2. One that ONE tool found and the OTHER missed
For each: explain why the tools differ (DB freshness? Different package matching?
EPSS scoring? Lecture 7 + Lecture 4 give context.) (2-3 sentences per CVE.)
```

---

## How to Submit

```bash
git add submissions/lab7.1.md
git commit -m "feat(lab7.1): trivy image + config scan + grype comparison"
git push -u origin feature/lab7.1
```

> **Do NOT commit** `labs/lab7/results/` — regeneratable.

PR checklist body:

```text
- [x] Task 1 — Trivy image + config scans + Grype comparison
```

---

## Acceptance Criteria

### Task 1 (6 pts)
- ✅ Trivy image scan completes; severity table populated
- ✅ Top-10 fixed CVE table with real CVE IDs + fix versions
- ✅ Two CVEs compared to Lab 4's Grype results (one tool-agreed, one tool-divergent)
- ✅ Tool-divergence explanation references DB freshness / package matching / EPSS

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — Trivy scans | **6** | Image + config scans + top-10 CVEs + Grype comparison |
| **Total** | **6** | |

---
