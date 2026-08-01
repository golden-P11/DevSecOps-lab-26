# Lab 4.2 — Trivy Comparison, CI Pipeline & Sign-Ready Attestation

![difficulty](https://img.shields.io/badge/difficulty-beginner-success)
![topic](https://img.shields.io/badge/topic-SBOM%20%2B%20SCA-blue)
![points](https://img.shields.io/badge/points-8%2B2%2B4-orange)
![tech](https://img.shields.io/badge/tech-Trivy%20%2B%20GitHub%20Actions-informational)

> **Goal:** Compare Grype vs Trivy on Juice Shop, automate SBOM + SCA in GitHub Actions, and produce a signed-ready CycloneDX attestation for Lab 8.
> **Deliverable:** A PR from `feature/lab4.2` with `submissions/lab4.2.md`, `.github/workflows/lab4-sbom-sca.yml`, and (bonus) `labs/lab4/juice-shop-attestation.json`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 4.1](lab4.1.md) — CycloneDX SBOM and Grype scan results should already exist locally.

> **Part of Lab 4:** This is the second half of Lab 4. Complete **[Lab 4.1](lab4.1.md)** first.

---

## Overview

In this lab you will practice:
- Running **Trivy** as an all-in-one alternative and comparing the result to Grype
- Automating **SBOM generation + SCA** in a **GitHub Actions** pipeline
- Producing a **CycloneDX SBOM attestation** that Lab 8 will sign with Cosign

> Recall Lecture 4 slide 11: every DevSecOps engineer is asked *"Syft+Grype or Trivy?"* at some point. This lab gives you the data to answer that question.

---

## Project State

**You should have from Lab 4.1:**
- `labs/lab4/juice-shop.cdx.json` and `labs/lab4/juice-shop.spdx.json` committed to your fork
- Grype scan output locally (`labs/lab4/grype-from-sbom.json`)
- Juice Shop v20.0.0 image pulled locally (Lab 1)

**This lab adds:**
- A side-by-side comparison report Syft+Grype vs Trivy
- A reusable CI pipeline for SBOM + SCA on GitHub-hosted runners
- A sign-ready CycloneDX attestation predicate for Lab 8

---

## Setup

You need:
- **Docker** (Juice Shop image already pulled from Lab 1; if not: `docker pull bkimminich/juice-shop:v20.0.0`)
- **`trivy`** —  (course pins **Trivy v0.69.x** as of April 2026)
- **`syft`** — for bonus attestation re-generation if needed
- **`jq`** — for JSON inspection
- A fork of the course repo with **Actions enabled** (GitHub → Settings → Actions → General → Allow all actions)

```bash
git switch main && git pull
git switch -c feature/lab4.2

# Verify tools are installed
trivy --version && jq --version

mkdir -p labs/lab4
```

---

## Task 1 — Trivy All-in-One Comparison (4 pts)

> ⏭️ Optional. Skipping won't affect future labs, but the comparison is interview-relevant: every DevSecOps engineer is asked "Syft+Grype or Trivy?" at some point.

**Objective:** Run Trivy directly against the image (not via SBOM), compare CVE counts to Grype, explain the differences.

### 4.5: Trivy image scan

```bash
# Direct image scan — Trivy's all-in-one mode
trivy image bkimminich/juice-shop:v20.0.0 \
  --severity LOW,MEDIUM,HIGH,CRITICAL \
  --format json --output labs/lab4/trivy.json

trivy image bkimminich/juice-shop:v20.0.0 \
  --severity HIGH,CRITICAL \
  --format table | tee labs/lab4/trivy.txt
```

### 4.6: Comparison table

```bash
# Trivy severity breakdown
jq '[.Results[].Vulnerabilities[]? | .Severity] | group_by(.) | map({severity: .[0], count: length})' \
  labs/lab4/trivy.json
```

### 4.7: Document in `submissions/lab4.2.md`

```markdown
# Lab 4.2 — Submission

## Task 1: Trivy Comparison

### Side-by-side counts
| Severity | Grype | Trivy | Δ |
|----------|------:|------:|--:|
| Critical | <a> | <b> | <b-a> |
| High | <a> | <b> | <b-a> |
| Medium | <a> | <b> | <b-a> |
| Low | <a> | <b> | <b-a> |
| **Total** | <a> | <b> | <b-a> |

### Why the difference?
Pick **two specific CVEs** that ONE tool found and the other didn't. For each:
1. CVE ID + tool that found it + tool that missed it
2. Why (likely): different CVE database refresh cadence? Different package matching rules? Different fix-version awareness?

(Lecture 4 mentioned that Grype and Trivy use slightly different DBs; this is where you see it.)

### When would you pick each?
2-3 sentences each:
- When does Syft+Grype's **decoupled** model win? (hint: SBOM-as-an-attestation, Lecture 4 + Lab 8)
- When does Trivy's **all-in-one** win? (hint: simpler CI step, broader scope including IaC + secrets + misconfig)
```

---

## Task 2 — GitHub Actions: SBOM + SCA Pipeline (4 pts)

**Objective:** Add the course reference workflow to your fork, trigger a successful run, and document what each step does.

Reference workflow: [`.github/workflows/lab4-sbom-sca.yml`](../.github/workflows/lab4-sbom-sca.yml)

### 4.8: Create the workflow file

Create the directory and file:

```bash
mkdir -p .github/workflows
nano .github/workflows/lab4-sbom-sca.yml
```

Paste the following content (matches the course reference workflow):

```yaml
name: Lab 4 - SBOM and SCA

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

env:
  IMAGE: bkimminich/juice-shop:v20.0.0
  REPORT_DIR: labs/lab4/reports

jobs:
  sbom-and-sca:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create report directory
        run: mkdir -p "${REPORT_DIR}"

      - name: Pull container image
        run: docker pull "${IMAGE}"

      - name: Generate CycloneDX SBOM with Syft
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.IMAGE }}
          format: cyclonedx-json
          output-file: labs/lab4/reports/juice-shop.cdx.json
          upload-artifact: false

      - name: Generate SPDX SBOM with Syft
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.IMAGE }}
          format: spdx-json
          output-file: labs/lab4/reports/juice-shop.spdx.json
          upload-artifact: false

      - name: Scan SBOM with Grype
        uses: anchore/scan-action@v7
        with:
          sbom: labs/lab4/reports/juice-shop.cdx.json
          output-format: json
          output-file: labs/lab4/reports/grype-report.json
          fail-build: false

      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@v0.36.0
        with:
          scan-type: image
          image-ref: ${{ env.IMAGE }}
          scanners: vuln
          severity: LOW,MEDIUM,HIGH,CRITICAL
          format: json
          output: labs/lab4/reports/trivy-report.json
          exit-code: "0"

      - name: Upload security reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab4-sbom-sca-reports
          path: labs/lab4/reports/
          retention-days: 30
```

Commit and push:

```bash
git add .github/workflows/lab4-sbom-sca.yml
git commit -m "feat(lab4.2): add SBOM + SCA GitHub Actions workflow"
git push -u origin feature/lab4.2
```

### 4.9: Trigger and verify the workflow

The workflow runs automatically when you:
- **Push** this branch and open a **pull request** to `main`, or
- **Merge/push to `main`**, or
- Manually trigger it: **Actions** tab → **Lab 4 - SBOM and SCA** → **Run workflow**

1. Open your fork on GitHub → **Actions** tab
2. Find the **Lab 4 - SBOM and SCA** workflow run triggered by your push or PR
3. Confirm the run shows a **green checkmark** (status: **Success**)
4. Download the `lab4-sbom-sca-reports` artifact and verify it contains SBOM + scan reports

> If the workflow fails, click the failed job to read the step output. Common causes: Docker pull timeout, action version mismatch, or missing permissions.

### 4.10: Document in `submissions/lab4.2.md`

Add to your submission file:

```markdown
## Task 2: GitHub Actions SBOM + SCA Pipeline

### Workflow file
Paste the full content of `.github/workflows/lab4-sbom-sca.yml`:

### Successful workflow run
- Direct link to a **green (Success)** workflow run: <URL>

### Job step explanation
Explain the purpose of each part of the `sbom-and-sca` job (2-3 sentences each):

#### Triggers (`on:`)
What events start this workflow, and why run SBOM + SCA on both `push` and `pull_request`?

#### Job: `sbom-and-sca` / `runs-on: ubuntu-latest`
What is this job, and why does it run on a GitHub-hosted Ubuntu runner?

#### Step: Pull container image
Why does the workflow pull the image explicitly before Syft runs?

#### Step: Generate CycloneDX SBOM with Syft
What does `anchore/sbom-action@v0` do? What is the output file used for?

#### Step: Scan SBOM with Grype
What does `anchore/scan-action@v7` do with the SBOM? Why is `fail-build: false` set here?

#### Step: Scan image with Trivy
How does this step differ from the Grype step? Why run both in the same pipeline?

#### Step: Upload security reports
What artifact is uploaded, and why use `if: always()`?

### One-paragraph reflection (2-3 sentences)
How does this CI pipeline complement the local Syft + Grype workflow from Lab 4.1?
```

---

## Bonus Task — Sign-Ready SBOM for Lab 8 (2 pts)

> 🌟 **Genuinely useful.** Lab 8 will sign this SBOM as a Cosign attestation. Whatever you produce here goes directly into your Lab 8 work — get the format right.

**Objective:** Produce a CycloneDX SBOM that conforms to Cosign's expected predicate format and verify it's importable into DefectDojo (preview for Lab 10).

### B.1: Verify CycloneDX schema compliance

```bash
# CycloneDX spec version (Lab 8 + Cosign expect 1.5 or 1.6 in 2026)
jq '.specVersion, .bomFormat' labs/lab4/juice-shop.cdx.json
# Should print:
# "1.5" (or "1.6")
# "CycloneDX"

# CycloneDX requires a metadata.timestamp and metadata.tools section — verify
jq '.metadata.timestamp, .metadata.tools' labs/lab4/juice-shop.cdx.json
```

### B.2: Re-run Syft if needed

If `specVersion` came back below 1.5 (older Syft versions defaulted to 1.4), force a newer version:

```bash
syft bkimminich/juice-shop:v20.0.0 \
  -o "cyclonedx-json@1.5=labs/lab4/juice-shop.cdx.json"
```

### B.3: Validate the attestation predicate shape

```bash
# YOUR TASK: Produce labs/lab4/juice-shop-attestation.json
# Shape required by Cosign (in-toto v1 envelope, see Lecture 8 slide 9):
#
# {
#   "_type": "https://in-toto.io/Statement/v1",
#   "subject": [
#     { "name": "<your image ref>",
#       "digest": { "sha256": "<digest of juice-shop:v20.0.0>" } }
#   ],
#   "predicateType": "https://cyclonedx.org/bom/v1.5",
#   "predicate": <the FULL contents of juice-shop.cdx.json>
# }
#
# Hints:
#   - Get the image digest: docker inspect bkimminich/juice-shop:v20.0.0 \
#       --format '{{index .RepoDigests 0}}'  → returns sha256:abc...
#   - You can build this with `jq` in a one-liner; no need for python
#   - This file is what Lab 8 Task 2 will feed into `cosign attest --predicate ...`
```

### B.4: Document in `submissions/lab4.2.md`

```markdown
## Bonus: Sign-Ready SBOM for Lab 8

### CycloneDX schema version
- `specVersion`: <output>
- `bomFormat`: <output>

### Image digest captured
- `docker inspect ... RepoDigests`: <output — should be sha256:...>

### Attestation predicate (paste first 30 lines of juice-shop-attestation.json)
```
<paste — must show _type, subject (with digest), predicateType, predicate (truncated)>
```

### What this enables in Lab 8
1 paragraph: when Lab 8 runs `cosign attest --type cyclonedx --predicate juice-shop-attestation.json ...`,
what specifically is being signed and what claim does it prove? (Reference Lecture 8 slide 9.)
```

---

## How to Submit

```bash
git add .github/workflows/lab4-sbom-sca.yml
git add labs/lab4/juice-shop-attestation.json  # Bonus only
git add submissions/lab4.2.md
git commit -m "feat(lab4.2): Trivy comparison + SBOM/SCA CI workflow + sign-ready attestation"
git push -u origin feature/lab4.2
```

> **Do NOT commit** `labs/lab4/trivy.*` or `labs/lab4/reports/` — they're regeneratable and large. The submission paste-in and the workflow artifact are the evidence.

PR checklist body:

```text
- [ ] Task 1 — Trivy comparison + when-to-pick-each tradeoff
- [ ] Task 2 — lab4-sbom-sca.yml committed + workflow run is green (Success)
- [ ] Bonus — sign-ready CycloneDX attestation for Lab 8
```

---

## Acceptance Criteria

### Task 1 (4 pts)
- ✅ Trivy scan output present in submission
- ✅ Side-by-side count table with deltas
- ✅ Two specific CVEs identified as tool-divergent; explained with 1-2 sentence reasoning each
- ✅ When-to-pick-each discussion shows understanding of decoupled vs all-in-one trade-offs

### Task 2 (4 pts)
- ✅ `.github/workflows/lab4-sbom-sca.yml` exists and matches the reference structure
- ✅ Submission includes a direct link to a **successful (green)** GitHub Actions workflow run
- ✅ Each workflow trigger, job setting, and step is explained accurately
- ✅ Reflection addresses how CI pipeline complements local SBOM + SCA workflow

### Bonus Task (2 pts)
- ✅ `labs/lab4/juice-shop-attestation.json` exists in PR
- ✅ File has correct `_type`, `subject.digest`, `predicateType: cyclonedx`, `predicate` shape
- ✅ Image digest matches actual `docker inspect` output for the v20.0.0 tag
- ✅ Lab 8 paragraph correctly identifies *what's being signed* and *what claim is being made*

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — Trivy comparison | **4** | Diff table + 2 tool-divergent CVEs explained + when-to-pick-each tradeoff |
| **Task 2** — GitHub Actions SBOM + SCA | **4** | Workflow committed + green run URL + step explanations + reflection |
| **Bonus Task** — Sign-ready attestation | **2** | Correct in-toto v1 shape + image digest captured + Lab 8 connection articulated |
| **Total** | **10** | 8 main + 2 bonus |

---
