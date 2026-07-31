# Lab 3.3 — Gitleaks CI Scan with GitHub Actions

![difficulty](https://img.shields.io/badge/difficulty-beginner-success)
![topic](https://img.shields.io/badge/topic-Secure%20Git-blue)
![points](https://img.shields.io/badge/points-4-orange)
![tech](https://img.shields.io/badge/tech-GitHub%20Actions%20%2B%20gitleaks-informational)

> **Goal:** Add a GitHub Actions workflow that scans your repository for secrets with gitleaks on every push and pull request.
> **Deliverable:** A PR from `feature/lab3.3` with `.github/workflows/lab3-gitleaks-scan.yml` and `submissions/lab3.3.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 3.1](lab3.1.md) — gitleaks pre-commit hook should already be working locally.

---

## Overview

In Lab 3.1 you blocked secrets **before commit** with a pre-commit hook. That control only protects the machine where the hook is installed — a teammate can bypass it with `--no-verify`, or secrets may already exist in history.

This lab adds a **second line of defense** in CI:
- **GitHub Actions workflow** — runs gitleaks automatically on every push to `main` and on every pull request targeting `main`
- **Defense in depth** — local hook catches mistakes early; CI catches anything that still reaches the remote

Reference workflow (course example): [lab3-gitleaks-scan.yml](https://github.com/golden-P11/DevSecOps-lab-26/blob/main/.github/workflows/lab3-gitleaks-scan.yml)

---

## Project State

**You should have from Lab 3.1:**
- `.pre-commit-config.yaml` with gitleaks configured
- Familiarity with gitleaks rule IDs and scan output

**This lab adds:**
- A reusable CI pipeline that scans the full repository (including git history) on GitHub-hosted runners

---

## Setup

You need:
- A fork of the course repo with **Actions enabled** (GitHub → Settings → Actions → General → Allow all actions)
- Lab 3.1 completed (pre-commit + gitleaks)

```bash
git switch main && git pull
git switch -c feature/lab3.3
```

---

## Task — GitHub Actions + gitleaks (4 pts)

**Objective:** Copy the reference workflow into your fork, push it, trigger a successful run, and document what each step does.

### 3.3.1: Create the workflow file

Create the directory and file:

```bash
mkdir -p .github/workflows
nano .github/workflows/lab3-gitleaks-scan.yml
```

Paste the following content (matches the [course reference workflow](https://github.com/golden-P11/DevSecOps-lab-26/blob/main/.github/workflows/lab3-gitleaks-scan.yml)):

```yaml
name: Gitleaks Scan

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  gitleaks:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Commit and push:

```bash
git add .github/workflows/lab3-gitleaks-scan.yml
git commit -m "feat(lab3.3): add gitleaks CI scan workflow"
git push -u origin feature/lab3.3
```

### 3.3.2: Trigger and verify the workflow

The workflow runs automatically when you:
- **Push** this branch and open a **pull request** to `main`, or
- **Merge/push to `main`**, or
- Manually trigger it: **Actions** tab → **Gitleaks Scan** → **Run workflow**

1. Open your fork on GitHub → **Actions** tab
2. Find the **Gitleaks Scan** workflow run triggered by your push or PR
3. Confirm the run shows a **green checkmark** (status: **Success**)

> If the workflow fails, click the failed job to read the gitleaks output. A red run usually means an actual (or test) secret was detected in the scanned commits — fix or remove it before resubmitting.

### 3.3.3: Document in `submissions/lab3.3.md`

```markdown
# Lab 3.3 — Submission

## Task: Gitleaks CI Scan

### Workflow file
Paste the full content of `.github/workflows/lab3-gitleaks-scan.yml`:

### Successful workflow run
- Direct link to a **green (Success)** workflow run: <URL>

### Job step explanation
Explain the purpose of each part of the `gitleaks` job (2-3 sentences each):

#### Triggers (`on:`)
What events start this workflow, and why scan on both `push` and `pull_request`?

#### Job: `gitleaks` / `runs-on: ubuntu-latest`
What is this job, and why does it run on a GitHub-hosted Ubuntu runner?

#### Step: Checkout repository
What does `actions/checkout@v4` do? Why is `fetch-depth: 0` important for gitleaks?

#### Step: Run Gitleaks
What does `gitleaks/gitleaks-action@v2` do? What is `GITHUB_TOKEN` used for?

### One-paragraph reflection (2-3 sentences)
Why is CI scanning still necessary if every developer already has a gitleaks pre-commit hook?
```

---

## How to Submit

```bash
git add .github/workflows/lab3-gitleaks-scan.yml
git add submissions/lab3.3.md
git commit -m "feat(lab3.3): gitleaks CI workflow + submission"
# This commit must be signed — verify with: git log --show-signature -1
git push -u origin feature/lab3.3
```

Open a PR to `main` and confirm the **Gitleaks Scan** check appears on the PR with a green status.

PR checklist body:

```text
- [ ] Task — lab3-gitleaks-scan.yml committed
- [ ] Gitleaks Scan workflow run is green (Success)
- [ ] Submission explains each job step + CI vs pre-commit reflection
```

---

## Acceptance Criteria

### Task (4 pts)
- ✅ `.github/workflows/lab3-gitleaks-scan.yml` exists and matches the reference structure (`on`, `jobs.gitleaks`, two steps)
- ✅ Submission includes a direct link to a **successful (green)** GitHub Actions run
- ✅ Each workflow trigger, job setting, and step is explained accurately (checkout + `fetch-depth: 0`, gitleaks action, `GITHUB_TOKEN`)
- ✅ Reflection addresses why CI scanning complements (not replaces) local pre-commit hooks

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task** — Gitleaks CI workflow | **4** | Workflow committed + green run link + step explanations + reflection |
| **Total** | **4** | |

---
