# Lab 5.3 — SAST + DAST CI Pipeline with GitHub Actions

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-SAST%20%2B%20DAST-blue)
![points](https://img.shields.io/badge/points-4-orange)
![tech](https://img.shields.io/badge/tech-GitHub%20Actions%20%2B%20Semgrep%20%2B%20ZAP-informational)

> **Goal:** Automate the Lab 5 SAST and DAST scans in a GitHub Actions workflow — Semgrep against Juice Shop source and OWASP ZAP (baseline + authenticated) against the running container.
> **Deliverable:** A PR from `feature/lab5-3` with `.github/workflows/lab5-sast-dast.yml` and `submissions/lab5-3.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 5.1](lab5-1.md) and [Lab 5.2](lab5-2.md) recommended — you should already understand the local Semgrep and ZAP steps this workflow automates.

> **Part of Lab 5:** This is the CI half of Lab 5. Complete **Lab 5.1 (SAST)** and **Lab 5.2 (DAST)** first for the scanner analysis; this lab wires the same steps into GitHub Actions.

---

## Overview

In Lab 5.1 and 5.2 you ran Semgrep and ZAP **locally**. Those controls only run when a developer remembers to execute them — findings can slip through if the scans aren't part of every push.

This lab adds a **repeatable CI pipeline**:
- **SAST job** — clones Juice Shop `v20.0.0`, runs Semgrep with the same rulesets as Lab 5.1
- **DAST job** — starts Juice Shop in Docker, runs ZAP baseline + authenticated scans (using the provided `zap-auth.yaml`), compares reports
- **Defense in depth** — local scans catch issues early during development; CI enforces the same checks on every push and pull request

Reference workflow: [`.github/workflows/lab5-sast-dast.yml`](../.github/workflows/lab5-sast-dast.yml)

---

## Project State

**You should have from Lab 5.1 and 5.2:**
- Familiarity with Semgrep rulesets (`p/owasp-top-ten`, `p/javascript`, `p/secrets`)
- Familiarity with ZAP baseline vs authenticated scan gap
- The provided scripts in `labs/lab5/scripts/` (especially `zap-auth.yaml` and `compare_zap.sh`)

**This lab adds:**
- A reusable CI pipeline that runs SAST + DAST on GitHub-hosted runners
- Artifact uploads for Semgrep and ZAP reports (retained 30 days)

---

## Setup

You need:
- A fork of the course repo with **Actions enabled** (GitHub → Settings → Actions → General → Allow all actions)
- Lab 5.1 and 5.2 completed (recommended, not strictly required)

```bash
git switch main && git pull
git switch -c feature/lab5-3
```

---

## Task 1 — GitHub Actions: SAST + DAST Pipeline (4 pts)

**Objective:** Copy the reference workflow into your fork, push it, trigger a successful run, and document what each job and step does.

### 5.3.1: Create the workflow file

Create the directory and file:

```bash
mkdir -p .github/workflows
nano .github/workflows/lab5-sast-dast.yml
```

Paste the following content (matches the [course reference workflow](../.github/workflows/lab5-sast-dast.yml)):

```yaml
name: SAST and DAST

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
  JUICE_SHOP_TAG: v20.0.0
  ZAP_IMAGE: ghcr.io/zaproxy/zaproxy:stable
  RESULTS_DIR: labs/lab5/results
  DOCKER_NETWORK: lab5-net

jobs:
  sast:
    name: SAST — Semgrep
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}"

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install Semgrep
        run: pip install semgrep

      - name: Clone Juice Shop source (pinned to v20.0.0)
        run: |
          git clone --depth 1 \
            https://github.com/juice-shop/juice-shop.git \
            labs/lab5/semgrep/juice-shop
          cd labs/lab5/semgrep/juice-shop
          git fetch --depth 1 origin tag "${JUICE_SHOP_TAG}" || true
          git checkout "${JUICE_SHOP_TAG}"

      - name: Run Semgrep (JSON report)
        run: |
          semgrep scan \
            --config=p/owasp-top-ten \
            --config=p/javascript \
            --config=p/secrets \
            labs/lab5/semgrep/juice-shop \
            --json -o "${RESULTS_DIR}/semgrep.json" \
            --severity ERROR --severity WARNING

      - name: Run Semgrep (human-readable summary)
        run: |
          semgrep scan \
            --config=p/owasp-top-ten \
            --config=p/javascript \
            labs/lab5/semgrep/juice-shop \
            --severity ERROR | tee "${RESULTS_DIR}/semgrep.txt"

      - name: Upload SAST reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab5-sast-reports
          path: |
            ${{ env.RESULTS_DIR }}/semgrep.json
            ${{ env.RESULTS_DIR }}/semgrep.txt
          retention-days: 30

  dast:
    name: DAST — OWASP ZAP
    runs-on: ubuntu-latest
    timeout-minutes: 45

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}"

      - name: Create Docker network
        run: docker network create "${DOCKER_NETWORK}" 2>/dev/null || true

      - name: Start Juice Shop
        run: |
          docker run -d --name juice-shop --network "${DOCKER_NETWORK}" \
            -p 127.0.0.1:3000:3000 \
            "${IMAGE}"

      - name: Wait for Juice Shop to be ready
        run: |
          for i in $(seq 1 60); do
            if curl -sf -o /dev/null http://127.0.0.1:3000/rest/admin/application-version; then
              echo "Juice Shop ready"
              exit 0
            fi
            sleep 2
          done
          echo "Juice Shop failed to start"
          docker logs juice-shop
          exit 1

      - name: Run ZAP baseline (unauthenticated) scan
        run: |
          set +e
          docker run --rm --network "${DOCKER_NETWORK}" \
            -v "${{ github.workspace }}/${RESULTS_DIR}:/zap/wrk" \
            "${ZAP_IMAGE}" \
            zap-baseline.py -t http://juice-shop:3000 \
            -r baseline-report.html -J baseline-report.json
          exit_code=$?
          set -e
          # Exit 2 = issues found (expected for Juice Shop); 1 = scan error
          if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
            exit "$exit_code"
          fi
          echo "ZAP baseline scan finished (exit code: ${exit_code})"

      - name: Run ZAP authenticated scan
        run: |
          docker run --rm --network "${DOCKER_NETWORK}" \
            --user root \
            -e _JAVA_OPTIONS="-Xmx512m" \
            -v "${{ github.workspace }}/labs/lab5:/zap/wrk" \
            "${ZAP_IMAGE}" \
            zap.sh -cmd -autorun /zap/wrk/scripts/zap-auth.yaml -port 8090

      - name: Compare baseline vs authenticated reports
        run: |
          bash labs/lab5/scripts/compare_zap.sh \
            "${RESULTS_DIR}/baseline-report.json" \
            "${RESULTS_DIR}/auth-report.json" \
            "${RESULTS_DIR}/zap-comparison.txt"

      - name: Stop Juice Shop
        if: always()
        run: |
          docker stop juice-shop 2>/dev/null || true
          docker rm juice-shop 2>/dev/null || true
          docker network rm "${DOCKER_NETWORK}" 2>/dev/null || true

      - name: Upload DAST reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab5-dast-reports
          path: |
            ${{ env.RESULTS_DIR }}/baseline-report.json
            ${{ env.RESULTS_DIR }}/baseline-report.html
            ${{ env.RESULTS_DIR }}/auth-report.json
            ${{ env.RESULTS_DIR }}/auth-report.html
            ${{ env.RESULTS_DIR }}/zap-comparison.txt
          retention-days: 30
```

Commit and push:

```bash
git add .github/workflows/lab5-sast-dast.yml
git commit -m "feat(lab5-3): add SAST + DAST GitHub Actions workflow"
git push -u origin feature/lab5-3
```

### 5.3.2: Trigger and verify the workflow

The workflow runs automatically when you:
- **Push** this branch and open a **pull request** to `main`, or
- **Merge/push to `main`**, or
- Manually trigger it: **Actions** tab → **Lab 5 - SAST and DAST** → **Run workflow**

1. Open your fork on GitHub → **Actions** tab
2. Find the **Lab 5 - SAST and DAST** workflow run triggered by your push or PR
3. Confirm **both jobs** (`SAST — Semgrep` and `DAST — OWASP ZAP`) show **green checkmarks** (status: **Success**)
4. Download the `lab5-sast-reports` and `lab5-dast-reports` artifacts and verify they contain the expected JSON/HTML files

> **Note:** The DAST job takes 10–15 minutes (authenticated ZAP scan is slow). If it fails, check: (1) Juice Shop startup timeout, (2) ZAP OOM without `_JAVA_OPTIONS`, (3) `zap-auth.yaml` path mismatch. Findings in the reports do **not** fail the workflow — only scan errors do.

### 5.3.3: Document in `submissions/lab5-3.md`

```markdown
# Lab 5.3 — Submission

## Task 1: GitHub Actions SAST + DAST Pipeline

### Workflow file
Paste the full content of `.github/workflows/lab5-sast-dast.yml`:

### Successful workflow run
- Direct link to a **green (Success)** workflow run (both jobs must pass): <URL>

### Job: `sast` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Triggers (`on:`)
What events start this workflow, and why run SAST + DAST on both `push` and `pull_request`?

#### Step: Clone Juice Shop source (pinned to v20.0.0)
Why pin to `v20.0.0` instead of scanning `main`? How does this match Lab 5.1?

#### Step: Run Semgrep (JSON report)
What rulesets are used? What does `--no-error-on-findings` do and why is it set here?

#### Step: Upload SAST reports
What artifact is uploaded, and why use `if: always()`?

### Job: `dast` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Step: Start Juice Shop / Wait for Juice Shop to be ready
Why start the app in Docker before ZAP runs? What does the health-check loop do?

#### Step: Run ZAP baseline (unauthenticated) scan
What is `zap-baseline.py`? Why accept exit code `2` but not `1`?

#### Step: Run ZAP authenticated scan
What does `zap-auth.yaml` configure? Why is `_JAVA_OPTIONS="-Xmx512m"` required?

#### Step: Compare baseline vs authenticated reports
What does `compare_zap.sh` produce, and how does it relate to Lab 5.2's analysis?

#### Step: Stop Juice Shop
Why run cleanup with `if: always()`?

### One-paragraph reflection (2-3 sentences)
How does this CI pipeline complement the local Semgrep and ZAP scans from Lab 5.1 and 5.2?
When would you still run scans locally instead of (or in addition to) CI?
```

---

## How to Submit

```bash
git add .github/workflows/lab5-sast-dast.yml
git add submissions/lab5-3.md
git commit -m "feat(lab5-3): SAST + DAST CI workflow + submission"
git push -u origin feature/lab5-3
```

Open a PR to `main` and confirm the **Lab 5 - SAST and DAST** check appears on the PR with both jobs green.

> **Do NOT commit** `labs/lab5/results/` or `labs/lab5/semgrep/juice-shop/` — CI generates these on the runner and uploads them as artifacts. The submission paste-in and workflow URL are the evidence.

PR checklist body:

```text
- [ ] Task 1 — lab5-sast-dast.yml committed
- [ ] Lab 5 - SAST and DAST workflow run is green (both sast + dast jobs Success)
- [ ] Submission explains each job step + CI vs local scan reflection
```

---

## Acceptance Criteria

### Task 1 (4 pts)
- ✅ `.github/workflows/lab5-sast-dast.yml` exists and matches the reference structure (two jobs: `sast`, `dast`)
- ✅ Submission includes a direct link to a **successful (green)** GitHub Actions run with both jobs passing
- ✅ SAST job steps explained accurately (clone pin, Semgrep rulesets, `--no-error-on-findings`, artifact upload)
- ✅ DAST job steps explained accurately (Juice Shop startup, ZAP baseline exit codes, auth scan + `_JAVA_OPTIONS`, compare script, cleanup)
- ✅ Reflection addresses how CI complements local Lab 5.1/5.2 scans

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — SAST + DAST CI workflow | **4** | Workflow committed + green run URL (both jobs) + step explanations + reflection |
| **Total** | **4** | |

> Combined with **Lab 5.1 (4 pts)** and **Lab 5.2 (8 pts)**, the full Lab 5 series totals **16 points**.

---
