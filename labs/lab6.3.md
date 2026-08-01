# Lab 6.3 — KICS + IaC Scanning CI Pipeline

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-IaC%20Security-blue)
![points](https://img.shields.io/badge/points-4%2B4-orange)
![tech](https://img.shields.io/badge/tech-KICS%20%2B%20GitHub%20Actions-informational)

> **Goal:** Run KICS against vulnerable Ansible + Pulumi samples, compare with Checkov from Lab 6.1, then automate Checkov + KICS scans in a GitHub Actions workflow.
> **Deliverable:** A PR from `feature/lab6.3` with `.github/workflows/lab6-iac-scanning.yml` and `submissions/lab6.3.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 6.1](lab6.1.md) recommended — you should already understand Checkov's Terraform findings for the Checkov-vs-KICS comparison.

> **Part of Lab 6:** This is the KICS + CI half of Lab 6. Complete **Lab 6.1 (Checkov)** first; Lab 6.2 (custom policy) is independent.

---

## Overview

In this lab you will practice:
- **KICS** on Ansible + Pulumi (~2,400 Rego-based queries) — Lecture 6
- **Tool comparison** — when Checkov vs KICS is the better fit (Lecture 6 slide 10)
- **CI automation** — repeatable IaC scanning on every push and pull request

Reference workflow: [`.github/workflows/lab6-iac-scanning.yml`](../.github/workflows/lab6-iac-scanning.yml)

---

## Project State

**You should have from Lab 6.1:**
- Checkov Terraform scan results locally (for the comparison in Task 3)
- Familiarity with the vulnerable IaC in `labs/lab6/vulnerable-iac/`

**This lab adds:**
- KICS scan reports for Ansible and Pulumi
- A reusable CI pipeline that runs Checkov + KICS on GitHub-hosted runners

---

## Setup

You need:
- **Docker** (for KICS)
- **`jq`**
- A fork of the course repo with **Actions enabled** (GitHub → Settings → Actions → General → Allow all actions)

```bash
git switch main && git pull
git switch -c feature/lab6.3

docker --version

mkdir -p labs/lab6/results
```

> **Plumbing provided** (in `labs/lab6/vulnerable-iac/`):
> - `ansible/` — deliberately misconfigured Linux hardening playbook
> - `pulumi/` — deliberately misconfigured AWS resources (Python + YAML)
> - `README.md` — documents the vulnerability classes each file targets

---

## Task 3 — KICS on Ansible + Pulumi (4 pts)

> ⏭️ Optional. Skipping won't affect future labs.

**Objective:** Run KICS against the Ansible playbook AND the Pulumi source; see how Rego-based queries surface different findings than Checkov, and demonstrate KICS's broader format coverage.

### 6.3.1: Run KICS on Ansible

```bash
docker run --rm \
  -v "$(pwd)/labs/lab6:/path" \
  checkmarx/kics:latest \
  scan -p /path/vulnerable-iac/ansible/ \
       -o /path/results/kics-ansible/ \
       --report-formats json,sarif
```

### 6.3.2: Run KICS on Pulumi (natively supported)

```bash
docker run --rm \
  -v "$(pwd)/labs/lab6:/path" \
  checkmarx/kics:latest \
  scan -p /path/vulnerable-iac/pulumi/ \
       -o /path/results/kics-pulumi/ \
       --report-formats json,sarif
```

### 6.3.3: Analyze

Each scan wrote its own `results.json` (`kics-ansible/` and `kics-pulumi/`). KICS reports a single
JSON object with a `.queries` array, and — unlike Checkov — it assigns severities, so here you can
triage by severity as well as frequency.

```bash
# Severity breakdown — for each scan
for scan in kics-ansible kics-pulumi; do
  echo "== $scan =="
  jq '[.queries[].severity] | group_by(.) | map({severity: .[0], count: length})' \
    labs/lab6/results/$scan/results.json
done

# Top queries by impact (Ansible shown; repeat for kics-pulumi)
jq '[.queries[] | {query: .query_name, severity, count: (.files | length)}]
    | sort_by(-.count) | .[:5]' \
  labs/lab6/results/kics-ansible/results.json
```

### 6.3.4: Document in `submissions/lab6.3.md`

```markdown
# Lab 6.3 — Submission

## Task 3: KICS on Ansible + Pulumi

### Ansible — severity breakdown
| Severity | Count |
|----------|------:|
| HIGH | <n> |
| MEDIUM | <n> |
| LOW | <n> |
| INFO | <n> |

### Pulumi — severity breakdown
| Severity | Count |
|----------|------:|
| CRITICAL | <n> |
| HIGH | <n> |
| MEDIUM | <n> |
| LOW | <n> |
| INFO | <n> |

### Top 5 KICS queries — Ansible (by frequency)
| Query | Severity | Files |
|-------|----------|------:|
| <name> | <sev> | <n> |

### Checkov vs KICS — when to use which? (Lecture 6 slide 10)
2-3 sentences each:
- One thing Checkov did **better** for the Terraform sample
- One thing KICS did **better** for the Ansible sample
- (Optional) An example of a finding only ONE of them caught for the same resource type
```

---

## Task 4 — GitHub Actions: IaC Scanning Pipeline (4 pts)

**Objective:** Copy the reference workflow into your fork, push it, trigger a successful run, and document what each job and step does.

### 6.3.5: Create the workflow file

Create the directory and file:

```bash
mkdir -p .github/workflows
nano .github/workflows/lab6-iac-scanning.yml
```

Paste the following content (matches the [course reference workflow](../.github/workflows/lab6-iac-scanning.yml)):

```yaml
name: IaC Scanning

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

env:
  RESULTS_DIR: labs/lab6/results
  KICS_IMAGE: checkmarx/kics:latest

jobs:
  checkov:
    name: Checkov — Terraform
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}/checkov-terraform"

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install Checkov
        run: pip install checkov

      - name: Run Checkov on Terraform
        run: |
          checkov -d labs/lab6/vulnerable-iac/terraform \
            --output cli --output json \
            --output-file-path "${RESULTS_DIR}/checkov-terraform/" \
            --soft-fail

      - name: Upload Checkov reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab6-checkov-reports
          path: |
            ${{ env.RESULTS_DIR }}/checkov-terraform/
          retention-days: 30

  kics-ansible:
    name: KICS — Ansible
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}/kics-ansible"

      - name: Run KICS on Ansible
        run: |
          docker run --rm \
            -v "${{ github.workspace }}/labs/lab6:/path" \
            "${KICS_IMAGE}" \
            scan -p /path/vulnerable-iac/ansible/ \
                 -o /path/results/kics-ansible/ \
                 --report-formats json,sarif \
                 --fail-on none

      - name: Upload KICS Ansible reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab6-kics-ansible-reports
          path: |
            ${{ env.RESULTS_DIR }}/kics-ansible/
          retention-days: 30

  kics-pulumi:
    name: KICS — Pulumi
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}/kics-pulumi"

      - name: Run KICS on Pulumi
        run: |
          docker run --rm \
            -v "${{ github.workspace }}/labs/lab6:/path" \
            "${KICS_IMAGE}" \
            scan -p /path/vulnerable-iac/pulumi/ \
                 -o /path/results/kics-pulumi/ \
                 --report-formats json,sarif \
                 --fail-on none

      - name: Upload KICS Pulumi reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab6-kics-pulumi-reports
          path: |
            ${{ env.RESULTS_DIR }}/kics-pulumi/
          retention-days: 30
```

Commit and push:

```bash
git add .github/workflows/lab6-iac-scanning.yml
git commit -m "feat(lab6.3): add IaC scanning GitHub Actions workflow"
git push -u origin feature/lab6.3
```

### 6.3.6: Trigger and verify the workflow

The workflow runs automatically when you:
- **Push** this branch and open a **pull request** to `main`, or
- **Merge/push to `main`**, or
- Manually trigger it: **Actions** tab → **Lab 6 - IaC Scanning** → **Run workflow**

1. Open your fork on GitHub → **Actions** tab
2. Find the **Lab 6 - IaC Scanning** workflow run triggered by your push or PR
3. Confirm **all three jobs** (`Checkov — Terraform`, `KICS — Ansible`, `KICS — Pulumi`) show **green checkmarks** (status: **Success**)
4. Download the `lab6-checkov-reports`, `lab6-kics-ansible-reports`, and `lab6-kics-pulumi-reports` artifacts and verify they contain JSON/SARIF files

> **Note:** Findings in the reports do **not** fail the workflow — Checkov uses `--soft-fail` and KICS uses `--fail-on none`. Only scan errors (tool crash, bad path, Docker pull failure) fail the pipeline.

### 6.3.7: Document in `submissions/lab6.3.md`

Append to your submission file:

```markdown
## Task 4: GitHub Actions IaC Scanning Pipeline

### Workflow file
Paste the full content of `.github/workflows/lab6-iac-scanning.yml`:

### Successful workflow run
- Direct link to a **green (Success)** workflow run (all three jobs must pass): <URL>

### Job: `checkov` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Triggers (`on:`)
What events start this workflow, and why run IaC scans on both `push` and `pull_request`?

#### Step: Run Checkov on Terraform
What does `--soft-fail` do and why is it set here? How does this match Lab 6.1?

#### Step: Upload Checkov reports
What artifact is uploaded, and why use `if: always()`?

### Job: `kics-ansible` / `kics-pulumi` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Step: Run KICS on Ansible / Pulumi
Why run KICS inside Docker? What does `--fail-on none` do?

#### Step: Upload KICS reports
What artifacts are uploaded, and why separate jobs for Ansible vs Pulumi?

### One-paragraph reflection (2-3 sentences)
How does this CI pipeline complement the local Checkov and KICS scans from Lab 6.1 and Task 3?
When would you still run scans locally instead of (or in addition to) CI?
```

---

## How to Submit

```bash
git add .github/workflows/lab6-iac-scanning.yml
git add submissions/lab6.3.md
git commit -m "feat(lab6.3): KICS scans + IaC CI workflow + submission"
git push -u origin feature/lab6.3
```

Open a PR to `main` and confirm the **Lab 6 - IaC Scanning** check appears on the PR with all three jobs green.

> **Do NOT commit** `labs/lab6/results/` — CI generates these on the runner and uploads them as artifacts. The submission paste-in and workflow URL are the evidence.

PR checklist body:

```text
- [ ] Task 3 — KICS on Ansible + Pulumi with Checkov-vs-KICS comparison
- [ ] Task 4 — lab6-iac-scanning.yml committed
- [ ] Lab 6 - IaC Scanning workflow run is green (all three jobs Success)
- [ ] Submission includes workflow URL + step explanations + CI vs local reflection
```

---

## Acceptance Criteria

### Task 3 (4 pts)
- ✅ KICS scan completes on both the Ansible and Pulumi samples
- ✅ Ansible + Pulumi severity tables and the Ansible top-5 table use real values
- ✅ Checkov-vs-KICS comparison has substantive 2-3-sentence answers per question

### Task 4 (4 pts)
- ✅ `.github/workflows/lab6-iac-scanning.yml` exists and matches the reference structure (three jobs: `checkov`, `kics-ansible`, `kics-pulumi`)
- ✅ Submission includes a direct link to a **successful (green)** GitHub Actions run with all three jobs passing
- ✅ Checkov job steps explained accurately (`--soft-fail`, artifact upload, triggers)
- ✅ KICS job steps explained accurately (Docker invocation, `--fail-on none`, separate artifacts)
- ✅ Reflection addresses how CI complements local Lab 6.1 / Task 3 scans

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 3** — KICS | **4** | Ansible + Pulumi scans + Checkov-vs-KICS comparison with concrete examples |
| **Task 4** — IaC CI workflow | **4** | Workflow committed + green run URL (all jobs) + step explanations + reflection |
| **Total** | **8** | |

---