# Lab 9.3 — Cryptominer Detection + Runtime Detection CI

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Runtime%20%2B%20PaC-blue)
![points](https://img.shields.io/badge/points-2%2B4-orange)
![tech](https://img.shields.io/badge/tech-Falco%20%2B%20Conftest%20%2B%20GitHub%20Actions-informational)

> **Goal:** Write a Falco rule that detects a cryptominer-style network pattern, then automate Falco runtime smoke tests and Conftest policy gates in a GitHub Actions workflow.
> **Deliverable:** A PR from `feature/lab9.3` with `.github/workflows/lab9-runtime-detection.yml` and `submissions/lab9.3.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 9.1](lab9.1.md) (Falco custom rules) and [Lab 9.2](lab9.2.md) (Conftest `hardening.rego`) recommended — the CI workflow expects both.

> **Part of Lab 9:** This is the bonus + CI half of Lab 9. Complete **[Lab 9.1](lab9.1.md)** and **[Lab 9.2](lab9.2.md)** separately.

---

## Overview

In this lab you will practice:
- **Cryptominer-style detection** — a Falco rule that catches network egress to known mining-pool patterns
- **CI automation** — Falco baseline runtime alerts + Conftest K8s/compose gates on every push and pull request

Reference workflow: [`.github/workflows/lab9-runtime-detection.yml`](../.github/workflows/lab9-runtime-detection.yml)

---

## Project State

**You should have from Lab 9.1:**
- `labs/lab9/falco/rules/custom-rules.yaml` with your `/tmp` write rule
- Familiarity with Falco eBPF container setup

**You should have from Lab 9.2:**
- `labs/lab9/policies/extra/hardening.rego` with ≥3 K8s deny rules

**This lab adds:**
- Cryptominer detection rule appended to `custom-rules.yaml`
- A reusable runtime + policy-as-code CI pipeline on GitHub-hosted runners

---

## Setup

You need:
- **Docker** (for local Bonus task Falco triggers)
- A fork of the course repo with **Actions enabled** (GitHub → Settings → Actions → General → Allow all actions)

```bash
git switch main && git pull
git switch -c feature/lab9.3

docker --version
mkdir -p labs/lab9/{falco/{rules,logs},results}
```

---

## Bonus Task — Detect Cryptominer Network Pattern (2 pts)

> 🌟 **Practical & directly maps to real attacks.** The Tesla 2018 incident (Lecture 1 + 6) had cryptominers on an exposed K8s dashboard. This rule would have flagged the egress within minutes.

**Objective:** Write a Falco rule that detects a container connecting to common mining-pool ports/domains.

### 9.3.1: Pick the detection pattern

Common cryptominer indicators (any 2 are sufficient for the rule):

| Indicator | Pattern |
|---|---|
| Connection to mining pool port | `fd.sport in (3333, 4444, 5555, 7777, 14444, 19999, 45700)` |
| DNS query for known pool hostname | `evt.type=connect and fd.sockfamily=ip and fd.cip.name contains "minexmr"` |
| Process name matches known miner | `proc.name in (xmrig, ethminer, cgminer, t-rex, claymore)` |
| High CPU + low network ratio | (Out of scope — needs metrics) |

### 9.3.2: Write the rule

Add to `labs/lab9/falco/rules/custom-rules.yaml`:

```yaml
# YOUR TASK: Detect cryptominer network/process pattern
# Requirements:
#   - rule: "Possible Cryptominer Activity"
#   - condition: combines AT LEAST 2 of the indicators above
#   - priority: CRITICAL
#   - tags: [container, mitre_execution, mitre_command_and_control]
#   - output: must include container, process, target (IP/port/name)
```

### 9.3.3: Trigger your rule

Simulating a connection to a typical mining-pool port:

```bash
# Start Falco + target if not already running (see Lab 9.1 setup)
docker run -d --name lab9-target alpine:3.20 sleep 1d 2>/dev/null || true
docker run -d --name falco \
  --privileged \
  -v /proc:/host/proc:ro \
  -v /boot:/host/boot:ro \
  -v /lib/modules:/host/lib/modules:ro \
  -v /usr:/host/usr:ro \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v "$(pwd)/labs/lab9/falco/rules":/etc/falco/rules.d:ro \
  falcosecurity/falco:0.43.1 \
  falco -U -o json_output=true -o time_format_iso_8601=true 2>/dev/null || true
sleep 5

# Don't actually connect to a real pool — use a netcat to a non-existent local address
docker exec lab9-target /bin/sh -c 'nc -w 2 127.0.0.1 3333' 2>/dev/null || true
sleep 3
docker logs falco > labs/lab9/falco/logs/falco.log 2>&1
grep "Cryptominer" labs/lab9/falco/logs/falco.log
```

### 9.3.4: Document in `submissions/lab9.3.md`

````markdown
# Lab 9.3 — Submission

## Bonus: Cryptominer Detection Rule

### Rule (paste)
```yaml
<paste>
```

### Triggered alert
```json
<paste — must show the rule firing on the nc test>
```

### Reflection (2-3 sentences)
- Which 2 indicators did you use and why?
- What does this miss? (i.e., the false-negative case — e.g., obfuscated mining over HTTPS)
- How would you combine this with the Lecture 9 SLA matrix?
````

---

## Task 3 — GitHub Actions: Runtime Detection Pipeline (4 pts)

**Objective:** Copy the reference workflow into your fork, push it, trigger a run, and document what each job does.

> **Green status requirement:** This pipeline is designed to **pass with green status** on any fork with Actions enabled — provided you completed Lab 9.1 (`custom-rules.yaml`) and Lab 9.2 (`hardening.rego`). All three jobs must complete successfully.

### 9.3.5: Create the workflow file

Create the directory and file:

```bash
mkdir -p .github/workflows
nano .github/workflows/lab9-runtime-detection.yml
```

Paste the following content (matches the [course reference workflow](../.github/workflows/lab9-runtime-detection.yml)):

```yaml
name: lab9-Runtime Detection

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
  RESULTS_DIR: labs/lab9/results
  CONFTEST_VERSION: "0.68.0"
  FALCO_VERSION: "0.43.1"

jobs:
  conftest-k8s:
    name: Conftest — K8s Hardening Gate
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}"

      - name: Install Conftest
        run: |
          curl -sSL "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
            | tar xz -C /tmp conftest
          sudo mv /tmp/conftest /usr/local/bin/conftest
          conftest --version

      - name: Compliant K8s manifest passes (juice-hardened.yaml)
        id: conftest-k8s-pass
        continue-on-error: true
        run: |
          conftest test labs/lab9/manifests/k8s/juice-hardened.yaml \
            --policy labs/lab9/policies/extra/ \
            --output json \
            > "${RESULTS_DIR}/conftest-k8s-hardened.json" 2> "${RESULTS_DIR}/conftest-k8s-hardened.stderr"
          conftest test labs/lab9/manifests/k8s/juice-hardened.yaml \
            --policy labs/lab9/policies/extra/ \
            --output stdout \
            | tee "${RESULTS_DIR}/conftest-k8s-hardened.txt"

      - name: Non-compliant K8s manifest fails (juice-unhardened.yaml)
        id: conftest-k8s-fail
        continue-on-error: true
        run: |
          set +e
          conftest test labs/lab9/manifests/k8s/juice-unhardened.yaml \
            --policy labs/lab9/policies/extra/ \
            --output json \
            > "${RESULTS_DIR}/conftest-k8s-unhardened.json" 2> "${RESULTS_DIR}/conftest-k8s-unhardened.stderr"
          conftest test labs/lab9/manifests/k8s/juice-unhardened.yaml \
            --policy labs/lab9/policies/extra/ \
            --output stdout \
            | tee "${RESULTS_DIR}/conftest-k8s-unhardened.txt"
          EXIT_CODE=$?
          set -e
          if [ "${EXIT_CODE}" -eq 0 ]; then
            echo "Expected juice-unhardened.yaml to fail Conftest, but it passed."
            exit 1
          fi
          DENY_COUNT=$(grep -c "FAIL" "${RESULTS_DIR}/conftest-k8s-unhardened.txt" || true)
          if [ "${DENY_COUNT}" -lt 1 ]; then
            echo "Expected at least one Conftest failure for juice-unhardened.yaml."
            exit 1
          fi

      - name: Upload Conftest K8s reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab9-conftest-k8s-report
          path: |
            ${{ env.RESULTS_DIR }}/conftest-k8s-hardened.*
            ${{ env.RESULTS_DIR }}/conftest-k8s-unhardened.*
          if-no-files-found: warn
          retention-days: 30

      - name: Fail on Conftest K8s gate error
        if: |
          steps.conftest-k8s-pass.outcome == 'failure' ||
          steps.conftest-k8s-fail.outcome == 'failure'
        run: exit 1

  conftest-compose:
    name: Conftest — Compose Hardening Gate
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directory
        run: mkdir -p "${RESULTS_DIR}"

      - name: Install Conftest
        run: |
          curl -sSL "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
            | tar xz -C /tmp conftest
          sudo mv /tmp/conftest /usr/local/bin/conftest
          conftest --version

      - name: Compliant compose manifest passes (juice-compose.yml)
        id: conftest-compose-pass
        continue-on-error: true
        run: |
          conftest test labs/lab9/manifests/compose/juice-compose.yml \
            --policy labs/lab9/policies/compose-security.rego \
            --namespace compose.security \
            --output stdout \
            | tee "${RESULTS_DIR}/conftest-compose-hardened.txt"

      - name: Non-compliant compose manifest fails
        id: conftest-compose-fail
        continue-on-error: true
        run: |
          cat > /tmp/bad-compose.yml <<'EOF'
          services:
            app:
              image: nginx:latest
              ports: ["8080:80"]
          EOF
          set +e
          conftest test /tmp/bad-compose.yml \
            --policy labs/lab9/policies/compose-security.rego \
            --namespace compose.security \
            --output stdout \
            | tee "${RESULTS_DIR}/conftest-compose-unhardened.txt"
          EXIT_CODE=$?
          set -e
          if [ "${EXIT_CODE}" -eq 0 ]; then
            echo "Expected bad-compose.yml to fail Conftest, but it passed."
            exit 1
          fi

      - name: Upload Conftest compose reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab9-conftest-compose-report
          path: |
            ${{ env.RESULTS_DIR }}/conftest-compose-hardened.txt
            ${{ env.RESULTS_DIR }}/conftest-compose-unhardened.txt
          if-no-files-found: warn
          retention-days: 30

      - name: Fail on Conftest compose gate error
        if: |
          steps.conftest-compose-pass.outcome == 'failure' ||
          steps.conftest-compose-fail.outcome == 'failure'
        run: exit 1

  falco-runtime:
    name: Falco — Runtime Detection Smoke Test
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create results directories
        run: |
          mkdir -p "${RESULTS_DIR}"
          mkdir -p labs/lab9/falco/logs labs/lab9/falco/rules

      - name: Start target container
        run: |
          docker run -d --name lab9-target alpine:3.20 sleep 1d

      - name: Start Falco with modern eBPF
        run: |
          docker run -d --name falco \
            --privileged \
            -v /proc:/host/proc:ro \
            -v /boot:/host/boot:ro \
            -v /lib/modules:/host/lib/modules:ro \
            -v /usr:/host/usr:ro \
            -v /var/run/docker.sock:/host/var/run/docker.sock \
            -v "$(pwd)/labs/lab9/falco/rules":/etc/falco/rules.d:ro \
            "falcosecurity/falco:${FALCO_VERSION}" \
            falco -U \
                  -o json_output=true \
                  -o time_format_iso_8601=true
          sleep 10
          docker logs falco 2>&1 | grep -i engine | tee "${RESULTS_DIR}/falco-engine.log"

      - name: Trigger baseline Falco alerts
        id: falco-baseline
        continue-on-error: true
        run: |
          docker exec lab9-target /bin/sh -lc 'echo "shell-in-container test"'
          docker exec lab9-target /bin/sh -lc 'cat /etc/shadow || true'
          sleep 5
          docker logs falco > labs/lab9/falco/logs/falco.log 2>&1
          grep -E "(Terminal shell|Read sensitive file)" labs/lab9/falco/logs/falco.log \
            | head -10 \
            | tee "${RESULTS_DIR}/falco-baseline-alerts.log"
          grep -q "Terminal shell" "${RESULTS_DIR}/falco-baseline-alerts.log"
          grep -q "Read sensitive file" "${RESULTS_DIR}/falco-baseline-alerts.log"

      - name: Trigger custom Falco rule (if present)
        id: falco-custom
        continue-on-error: true
        if: hashFiles('labs/lab9/falco/rules/custom-rules.yaml') != ''
        run: |
          docker kill --signal=SIGHUP falco && sleep 3
          docker exec --user 0 lab9-target /bin/sh -lc 'echo "test" > /tmp/my-write.txt'
          sleep 3
          docker logs falco >> labs/lab9/falco/logs/falco.log 2>&1
          grep "Write to /tmp by container" labs/lab9/falco/logs/falco.log \
            | head -5 \
            | tee "${RESULTS_DIR}/falco-custom-alert.log"
          grep -q "Write to /tmp by container" "${RESULTS_DIR}/falco-custom-alert.log"

      - name: Upload Falco runtime reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab9-falco-runtime-report
          path: |
            ${{ env.RESULTS_DIR }}/falco-engine.log
            ${{ env.RESULTS_DIR }}/falco-baseline-alerts.log
            ${{ env.RESULTS_DIR }}/falco-custom-alert.log
            labs/lab9/falco/logs/falco.log
          if-no-files-found: warn
          retention-days: 30

      - name: Stop Falco containers
        if: always()
        run: |
          docker stop falco lab9-target 2>/dev/null || true
          docker rm falco lab9-target 2>/dev/null || true

      - name: Fail on Falco runtime detection error
        if: steps.falco-baseline.outcome == 'failure'
        run: exit 1
```

Commit and push:

```bash
git add .github/workflows/lab9-runtime-detection.yml
git add labs/lab9/falco/rules/custom-rules.yaml
git add labs/lab9/policies/extra/
git commit -m "feat(lab9.3): runtime detection CI workflow"
git push -u origin feature/lab9.3
```

### 9.3.6: Trigger and verify the workflow

The workflow runs automatically when you:
- **Push** this branch and open a **pull request** to `main`, or
- **Merge/push to `main`**, or
- Manually trigger it: **Actions** tab → **lab9-Runtime Detection** → **Run workflow**

1. Open your fork on GitHub → **Actions** tab
2. Find the **lab9-Runtime Detection** workflow run triggered by your push or PR
3. Confirm all three jobs complete with **green status** (✅):
   - `Conftest — K8s Hardening Gate`
   - `Conftest — Compose Hardening Gate`
   - `Falco — Runtime Detection Smoke Test`
4. Download the `lab9-conftest-k8s-report`, `lab9-conftest-compose-report`, and `lab9-falco-runtime-report` artifacts

> **Note:** The `conftest-k8s` job uses your Lab 9.2 `hardening.rego` from `labs/lab9/policies/extra/`. The `falco-runtime` job verifies built-in baseline alerts and optionally tests your Lab 9.1 custom `/tmp` write rule if `custom-rules.yaml` is present.

### 9.3.7: Document in `submissions/lab9.3.md`

Append to your submission file:

```markdown
## Task 3: GitHub Actions Runtime Detection Pipeline

### Workflow file
Paste the full content of `.github/workflows/lab9-runtime-detection.yml`:

### Workflow run
- Direct link to a **green** workflow run (all three jobs passed): <URL>
- Confirm artifacts `lab9-conftest-k8s-report`, `lab9-conftest-compose-report`, and `lab9-falco-runtime-report` were uploaded

### Job: `conftest-k8s` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Triggers (`on:`)
What events start this workflow, and why run policy checks on both `push` and `pull_request`?

#### Step: Compliant K8s manifest passes
Why must `juice-hardened.yaml` pass with 0 failures before merge?

#### Step: Non-compliant K8s manifest fails
Why does this step expect Conftest to exit non-zero, and what does that prove about your Rego policies?

### Job: `conftest-compose` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Step: Compliant compose manifest passes
Why does this job use `--namespace compose.security`?

#### Step: Non-compliant compose manifest fails
How does this demonstrate the same `deny[msg]` pattern generalizing to a different input shape?

### Job: `falco-runtime` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Step: Start Falco with modern eBPF
Why does Falco need `--privileged` and host volume mounts on the GitHub runner?

#### Step: Trigger baseline Falco alerts
Which two built-in rules are exercised, and why are they sufficient as a CI smoke test?

#### Step: Trigger custom Falco rule (if present)
How does this step connect back to your Lab 9.1 custom rule work?

### One-paragraph reflection (2-3 sentences)
How does this CI pipeline complement the local Falco + Conftest work from Lab 9.1 and Lab 9.2?
When would you still run Falco or Conftest locally instead of (or in addition to) CI?
```

---

## How to Submit

```bash
git add .github/workflows/lab9-runtime-detection.yml
git add labs/lab9/falco/rules/custom-rules.yaml
git add labs/lab9/policies/extra/                # from Lab 9.2
git add submissions/lab9.3.md
git commit -m "feat(lab9.3): cryptominer rule + runtime detection CI + submission"
git push -u origin feature/lab9.3
```

Open a PR to `main` and confirm the **lab9-Runtime Detection** workflow appears on the PR with **green status**.

> **Do NOT commit** `labs/lab9/falco/logs/` or `labs/lab9/results/` — CI generates artifacts on the runner. The submission paste-in and **green workflow run URL** are the evidence.

PR checklist body:

```text
- [ ] Bonus — Cryptominer detection rule with triggered alert
- [ ] Task 3 — lab9-runtime-detection.yml committed
- [ ] lab9-Runtime Detection workflow: all three jobs green + artifacts uploaded
- [ ] Submission includes green workflow run URL + job step explanations + CI vs local reflection
```

---

## Acceptance Criteria

### Bonus Task (2 pts)
- ✅ Cryptominer rule combines ≥2 indicators (port OR process OR DNS)
- ✅ Rule fires on the `nc` test trigger (visible in Falco log)
- ✅ Reflection covers false-negative case + SLA matrix integration

### Task 3 (4 pts)
- ✅ `.github/workflows/lab9-runtime-detection.yml` exists and matches the reference structure (three jobs: Conftest K8s, Conftest compose, Falco runtime)
- ✅ Submission includes a direct link to a **green** workflow run where all three jobs passed
- ✅ Conftest K8s job steps explained accurately (pass on hardened, fail on unhardened)
- ✅ Conftest compose job explained with namespace + shape generalization
- ✅ Falco runtime job explained with eBPF setup + baseline alert smoke test
- ✅ Reflection addresses how CI complements local Lab 9.1 / Lab 9.2 work

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Bonus Task** — Cryptominer rule | **2** | 2+ indicators + triggered alert + reflection on FN + SLA |
| **Task 3** — Runtime Detection CI | **4** | Workflow committed + green run URL + job explanations + reflection |
| **Total** | **6** | |

---
