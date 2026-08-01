# Lab 7.3 — Conftest Policy Gate + Container Security CI

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Container%20Security-blue)
![points](https://img.shields.io/badge/points-2%2B4-orange)
![tech](https://img.shields.io/badge/tech-Conftest%20%2B%20GitHub%20Actions-informational)

> **Goal:** Write a Conftest/Rego policy that gates non-compliant pods at CI time, then automate Trivy + Conftest scans in a GitHub Actions workflow.
> **Deliverable:** A PR from `feature/lab7.3` with `labs/lab7/policies/pod-hardening.rego`, `.github/workflows/lab7-container-security.yml`, and `submissions/lab7.3.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 7.2](lab7.2.md) — you need hardened K8s manifests in `labs/lab7/k8s/` for Conftest and the CI pipeline to pass.

> **Part of Lab 7:** This is the Conftest + CI half of Lab 7. Complete **Lab 7.1 (Trivy)** and **Lab 7.2 (K8s hardening)** first.

---

## Overview

In this lab you will practice:
- Writing a **Conftest/Rego** policy to gate non-compliant pods (Lecture 7 slide 16; Lecture 9 preview)
- **CI automation** — Trivy image + config scans and Conftest policy gate on every push and pull request

Reference workflow: [`.github/workflows/lab7-container-security.yml`](../.github/workflows/lab7-container-security.yml)

---

## Project State

**You should have from Lab 7.2:**
- Hardened K8s manifests in `labs/lab7/k8s/` (namespace, serviceaccount, deployment, networkpolicy)
- A running Juice Shop pod that passes PSS `restricted`

**This lab adds:**
- A Conftest Rego policy at `labs/lab7/policies/pod-hardening.rego`
- A reusable CI pipeline that runs Trivy + Conftest on GitHub-hosted runners

---

## Setup

You need:
- **`conftest`** v0.68.x — `brew install conftest` (only needed for local testing)
- A fork of the course repo with **Actions enabled** (GitHub → Settings → Actions → General → Allow all actions)

```bash
git switch main && git pull
git switch -c feature/lab7.3

conftest --version

mkdir -p labs/lab7/policies
```

---

## Bonus Task — Conftest Policy Gate (2 pts)

> 🌟 **Genuinely valuable.** Conftest in CI catches insecure pods *before* `kubectl apply`. Lecture 9 covers Conftest in depth; this bonus is your preview.

**Objective:** Write a Rego policy that refuses pods missing key hardening (runAsNonRoot, readOnlyRootFilesystem, no wildcard caps).

### 7.3.1: Write the policy

```rego
# labs/lab7/policies/pod-hardening.rego
# YOUR TASK: Rego policy refusing non-compliant pods
# Requirements:
#   - Run via: conftest test labs/lab7/k8s/deployment.yaml --policy labs/lab7/policies
#   - Must produce deny rules for pods missing:
#       1. spec.securityContext.runAsNonRoot != true
#       2. (any container) spec.containers[_].securityContext.readOnlyRootFilesystem != true
#       3. (any container) spec.containers[_].securityContext.allowPrivilegeEscalation != false
#       4. (any container) spec.containers[_].securityContext.capabilities.drop missing "ALL"
#
# Hints:
#   - Rego primer at https://www.openpolicyagent.org/docs/latest/policy-language/
#   - Conftest 0.68.x uses Rego v1 syntax: `deny contains msg if { ... }` (not `deny[msg] { ... }`)
#   - `input.kind == "Deployment"` to filter; the pod spec is `input.spec.template.spec`
#   - `[_]` iterates; `msg := sprintf("...", [...])` formats
#   - Sample structure:
#     package main
#     deny contains msg if { input.kind == "Deployment"; <condition>; msg := "..." }
```

### 7.3.2: Run Conftest against your manifests

```bash
# Should PASS on your hardened deployment (Lab 7.2 work)
conftest test labs/lab7/k8s/deployment.yaml --policy labs/lab7/policies

# Create an intentionally bad manifest to verify the policy fires
cat > /tmp/bad-pod.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: bad-app }
spec:
  template:
    spec:
      containers:
        - name: app
          image: nginx
          # No securityContext at all — should fail your policy
EOF

conftest test /tmp/bad-pod.yaml --policy labs/lab7/policies
# Should FAIL with deny messages
```

### 7.3.3: Document in `submissions/lab7.3.md`

````markdown
# Lab 7.3 — Submission

## Bonus: Conftest Policy

### Policy (paste labs/lab7/policies/pod-hardening.rego)
```rego
<paste full policy>
```

### Output: PASS on hardened manifest
```
<paste — should show 0 failures>
```

### Output: FAIL on bad manifest
```
<paste — should show your deny messages>
```

### What this prevents at CI time (2-3 sentences)
Reference Lecture 7 slide 16 (admission control diagram). What Class of bug does this
policy catch BEFORE `kubectl apply` runs? Why is catching at CI-time better than at admission-time?
````

---

## Task 3 — GitHub Actions: Container Security Pipeline (4 pts)

**Objective:** Copy the reference workflow into your fork, push it, trigger a run, and document what each job and step does.

> **Green status requirement:** Unlike Lab 6.3 (where vulnerable IaC is *expected* to fail scans), this pipeline is designed to **pass with green status** when your Lab 7.2 manifests and Lab 7.3 Conftest policy are correct. Trivy image/config jobs use `exit-code: "0"` (informational — CVEs in Juice Shop are expected). The **Conftest job is the hard gate** — it fails if your deployment does not meet the pod-hardening policy.

### 7.3.4: Create the workflow file

Create the directory and file:

```bash
mkdir -p .github/workflows
nano .github/workflows/lab7-container-security.yml
```

Paste the following content (matches the [course reference workflow](../.github/workflows/lab7-container-security.yml)):

```yaml
name: lab7-Container Security

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  actions: write

env:
  IMAGE: bkimminich/juice-shop:v20.0.0
  RESULTS_DIR: labs/lab7/results

jobs:
  trivy-image:
    name: Trivy — Image Scan
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}"

      - name: Run Trivy image scan
        uses: aquasecurity/trivy-action@v0.36.0
        with:
          scan-type: image
          image-ref: ${{ env.IMAGE }}
          scanners: vuln
          severity: HIGH,CRITICAL
          format: json
          output: ${{ env.RESULTS_DIR }}/trivy-image.json
          exit-code: "0"

      - name: Upload Trivy image report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab7-trivy-image-report
          path: ${{ env.RESULTS_DIR }}/trivy-image.json
          if-no-files-found: warn
          retention-days: 30

  trivy-config:
    name: Trivy — K8s Manifest Scan
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}"

      - name: Run Trivy config scan on K8s manifests
        uses: aquasecurity/trivy-action@v0.36.0
        with:
          scan-type: config
          scan-ref: labs/lab7/k8s
          severity: HIGH,CRITICAL
          format: json
          output: ${{ env.RESULTS_DIR }}/trivy-config.json
          exit-code: "0"

      - name: Upload Trivy config report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab7-trivy-config-report
          path: ${{ env.RESULTS_DIR }}/trivy-config.json
          if-no-files-found: warn
          retention-days: 30

  conftest:
    name: Conftest — Pod Hardening Gate
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Conftest
        run: |
          CONFTEST_VERSION="0.68.0"
          curl -sSL "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
            | tar xz -C /tmp conftest
          sudo mv /tmp/conftest /usr/local/bin/conftest
          conftest --version

      - name: Run Conftest pod hardening policy
        run: |
          conftest test labs/lab7/k8s/deployment.yaml \
            --policy labs/lab7/policies \
            --output stdout
```

Commit and push:

```bash
git add .github/workflows/lab7-container-security.yml
git add labs/lab7/policies/
git add labs/lab7/k8s/
git commit -m "feat(lab7.3): conftest policy + container security CI workflow"
git push -u origin feature/lab7.3
```

### 7.3.5: Trigger and verify the workflow

The workflow runs automatically when you:
- **Push** this branch and open a **pull request** to `main`, or
- **Merge/push to `main`**, or
- Manually trigger it: **Actions** tab → **lab7-Container Security** → **Run workflow**

1. Open your fork on GitHub → **Actions** tab
2. Find the **lab7-Container Security** workflow run triggered by your push or PR
3. Confirm all three jobs complete with **green status** (✅):
   - `Trivy — Image Scan`
   - `Trivy — K8s Manifest Scan`
   - `Conftest — Pod Hardening Gate`
4. Download the `lab7-trivy-image-report` and `lab7-trivy-config-report` artifacts

> **Note:** Trivy jobs use `exit-code: "0"` so known Juice Shop CVEs do not fail the pipeline. The Conftest job has no soft-fail — if your hardened deployment or Rego policy is wrong, the workflow turns red.

### 7.3.6: Document in `submissions/lab7.3.md`

Append to your submission file:

```markdown
## Task 3: GitHub Actions Container Security Pipeline

### Workflow file
Paste the full content of `.github/workflows/lab7-container-security.yml`:

### Workflow run
- Direct link to a **green** workflow run (all three jobs passed): <URL>
- Confirm artifacts `lab7-trivy-image-report` and `lab7-trivy-config-report` were uploaded

### Job: `trivy-image` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Triggers (`on:`)
What events start this workflow, and why run container scans on both `push` and `pull_request`?

#### Step: Run Trivy image scan
Why use `exit-code: "0"` here instead of failing on HIGH/CRITICAL CVEs?

#### Step: Upload Trivy image report
What artifact is uploaded, and why use `if: always()`?

### Job: `trivy-config` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Step: Run Trivy config scan on K8s manifests
How does `scan-type: config` differ from the `k8s` mode you ran locally in Lab 7.2?

### Job: `conftest` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Step: Run Conftest pod hardening policy
Why is this job the **hard gate** (no soft-fail) while Trivy jobs are informational?

### One-paragraph reflection (2-3 sentences)
How does this CI pipeline complement the local Trivy and Conftest runs from Lab 7.1, Lab 7.2, and the Bonus task?
When would you still run scans locally instead of (or in addition to) CI?
```

---

## How to Submit

```bash
git add labs/lab7/policies/
git add labs/lab7/k8s/
git add .github/workflows/lab7-container-security.yml
git add submissions/lab7.3.md
git commit -m "feat(lab7.3): conftest policy + container security CI + submission"
git push -u origin feature/lab7.3
```

Open a PR to `main` and confirm the **lab7-Container Security** workflow appears on the PR with **green status**.

> **Do NOT commit** `labs/lab7/results/` — CI generates these on the runner and uploads Trivy reports as artifacts. The submission paste-in and workflow URL are the evidence.

PR checklist body:

```text
- [ ] Bonus — Conftest policy passing on hardened + failing on bad manifest
- [ ] Task 3 — lab7-container-security.yml committed
- [ ] lab7-Container Security workflow: all three jobs green + artifacts uploaded
- [ ] Submission includes green workflow run URL + job step explanations + CI vs local reflection
```

---

## Acceptance Criteria

### Bonus Task (2 pts)
- ✅ Rego policy file exists at `labs/lab7/policies/pod-hardening.rego`
- ✅ Policy PASSES on Lab 7.2 hardened deployment
- ✅ Policy FAILS on intentionally bad manifest with clear deny messages
- ✅ CI-time vs admission-time explanation demonstrates understanding (2-3 sentences)

### Task 3 (4 pts)
- ✅ `.github/workflows/lab7-container-security.yml` exists and matches the reference structure (three jobs: Trivy image, Trivy config, Conftest gate)
- ✅ Submission includes a direct link to a **green** workflow run where all three jobs passed
- ✅ Trivy job steps explained accurately (`exit-code: "0"`, `if: always()` upload, triggers)
- ✅ Conftest job explained as the hard policy gate (no soft-fail)
- ✅ Reflection addresses how CI complements local Lab 7.1 / Lab 7.2 / Bonus scans

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Bonus Task** — Conftest | **2** | Rego policy PASSES + FAILS correctly + CI-vs-admission reflection |
| **Task 3** — Container Security CI | **4** | Workflow committed + green run URL + job explanations + reflection |
| **Total** | **6** | |

---
