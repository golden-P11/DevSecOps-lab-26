# Lab 5.2 — DAST: Scanning Juice Shop with OWASP ZAP

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-DAST-blue)
![points](https://img.shields.io/badge/points-6%2B2-orange)
![tech](https://img.shields.io/badge/tech-OWASP%20ZAP-informational)

> **Goal:** Run DAST with **OWASP ZAP** against the running Juice Shop — both unauthenticated (baseline) and authenticated (full) scans — and analyze the gap between them.
> **Deliverable:** A PR from `feature/lab5-2` with `submissions/lab5-2.md` (ZAP analysis; optional correlation if you completed Lab 5.1). Submit PR link via Moodle.

> **Part of Lab 5:** This is the DAST half of Lab 5. Complete **Lab 5.1 (SAST)** first if you want to attempt the correlation bonus. **Lab 5.3** automates both scans in GitHub Actions.

---

## Overview

In this lab you will practice:
- **DAST** with **OWASP ZAP** (Lecture 5) — baseline + full authenticated scan
- **Auth vs unauth gap analysis** — comparing alert counts and identifying auth-only findings
- **Optional correlation** — matching ZAP alerts to Semgrep findings from Lab 5.1 (Lecture 5 slide 15: highest-confidence finding type)

> Recall Lecture 5 slide 11: *authenticated DAST finds 10–20× more issues than unauth*. Don't skip the auth setup.

---

## Project State

**You should have from Labs 1–4:**
- Juice Shop v20.0.0 deployable locally (Lab 1)
- Signed commits + pre-commit hooks working (Lab 3)

**This lab adds:**
- A baseline ZAP scan + a full authenticated ZAP scan
- Auth/baseline ratio analysis with two auth-only alert deep-dives
- *(Bonus)* A correlation report if you also have Semgrep output from Lab 5.1

---

## Setup

You need:
- **Docker** (Juice Shop + ZAP run as containers)
- **`jq`** + **`git`**

```bash
git switch main && git pull
git switch -c feature/lab5-2

# Verify
docker --version
```

> **Plumbing provided** (already in `labs/lab5/scripts/`):
> - [`labs/lab5/scripts/zap-auth.yaml`](lab5/scripts/zap-auth.yaml) — ZAP Automation Framework config for authenticated scan
> - [`labs/lab5/scripts/compare_zap.sh`](lab5/scripts/compare_zap.sh) — script to diff baseline vs authenticated ZAP results
> - [`labs/lab5/scripts/summarize_dast.sh`](lab5/scripts/summarize_dast.sh) — produce a severity-count summary
>
> Read these files before running — they contain inline comments explaining design choices.

---

## Task 1 — DAST with OWASP ZAP (6 pts)

**Objective:** Run ZAP in baseline mode (unauthenticated) and full mode (authenticated), then analyze the gap.

### 5.1: Start Juice Shop on a dedicated network

```bash
docker network create lab5-net 2>/dev/null || true

docker run -d --name juice-shop --network lab5-net \
  -p 127.0.0.1:3000:3000 \
  bkimminich/juice-shop:v20.0.0

# Wait until it's ready
until curl -s -o /dev/null http://127.0.0.1:3000/rest/products; do sleep 2; done
echo "✅ Juice Shop ready"

mkdir -p labs/lab5/results
```

### 5.2: Baseline (unauthenticated) ZAP scan

```bash
docker run --rm --network lab5-net \
  -v "$(pwd)/labs/lab5/results:/zap/wrk" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t http://juice-shop:3000 \
  -r baseline-report.html -J baseline-report.json
# Will print scan progress; expected to finish in 1-2 minutes
# Exits 2 if it finds issues — that's normal for Juice Shop
```

### 5.3: Authenticated ZAP scan with the Automation Framework

```bash
# The provided zap-auth.yaml drives the Automation Framework
# _JAVA_OPTIONS caps ZAP's JVM heap; without it the active scan OOM-kills the container
docker run --rm --network lab5-net \
  -e _JAVA_OPTIONS="-Xmx512m" \
  -v "$(pwd)/labs/lab5:/zap/wrk" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap.sh -cmd -autorun /zap/wrk/scripts/zap-auth.yaml -port 8090
# This takes 5-10 minutes — it crawls + actively scans authenticated routes
```

### 5.4: Compare the two reports

```bash
bash labs/lab5/scripts/compare_zap.sh \
  labs/lab5/results/baseline-report.json \
  labs/lab5/results/auth-report.json
# Prints a side-by-side severity count table
```

### 5.5: Document in `submissions/lab5-2.md`

```markdown
# Lab 5.2 — Submission

## Task 1: DAST with OWASP ZAP

### Baseline (unauthenticated) scan
- Duration: <X minutes>
- Total alerts: <n>
| Severity | Count |
|----------|------:|
| High | <n> |
| Medium | <n> |
| Low | <n> |
| Informational | <n> |

### Authenticated full scan
- Duration: <X minutes>
- Total alerts: <n>
| Severity | Count |
|----------|------:|
| High | <n> |
| Medium | <n> |
| Low | <n> |
| Informational | <n> |

### The "10–20× more" claim (Lecture 5 slide 11)
- Ratio (auth alerts / baseline alerts): <e.g., 18.5×>
- Did your run match the lecture's ratio? (2-3 sentences)
- Pick **two specific alerts** that only the authenticated scan found. For each:
  1. Alert title + severity
  2. Why was it unreachable to the unauthenticated scan? (1 sentence)
```

---

## Bonus Task — SAST/DAST Correlation (2 pts)

> 🌟 **Requires Lab 5.1.** The strongest possible finding is one both tools agree on (Lecture 5 slide 15). You need `labs/lab5/results/semgrep.json` from Lab 5.1 plus the ZAP reports from this lab.

**Objective:** Find at least one vulnerability that **both** Semgrep and ZAP report on the same component/endpoint. Write up the correlated finding.

### B.1: Cross-reference the reports

```bash
# Extract URLs/endpoints flagged by ZAP authenticated scan
jq -r '[.site[].alerts[].instances[].uri] | unique[]' \
  labs/lab5/results/auth-report.json | head -50 > /tmp/zap-urls.txt

# Extract file paths flagged by Semgrep (from Lab 5.1)
jq -r '[.results[].path] | unique[]' \
  labs/lab5/results/semgrep.json | head -50 > /tmp/semgrep-paths.txt

# YOUR TASK: find the overlap
# Hint: ZAP's URI '/rest/products/search' likely maps to a Semgrep finding
# in the routes/* or api/* directory of Juice Shop source
```

### B.2: Build the correlation table

For each correlated finding (you need ≥1, ideally 2-3):

```markdown
| # | OWASP cat | ZAP alert | ZAP URI | Semgrep rule | Semgrep file:line | Confidence |
|---|-----------|-----------|---------|--------------|-------------------|------------|
| 1 | A03 Injection | SQL Injection | /rest/products/search?q=... | tainted-sql | routes/search.ts:42 | High (both agree) |
| 2 | ... |
```

### B.3: The fix — proposed remediation

For your strongest correlation (the one with highest severity in both reports):
1. **Paste the vulnerable code** from Semgrep's file:line
2. **Paste a working payload** from ZAP's report
3. **Write the fix** (parameterized query / output encoding / capability check / whatever applies)
4. **Why both tools caught it** (1-2 sentences — what made this discoverable from both angles?)

### B.4: Document in `submissions/lab5-2.md`

```markdown
## Bonus: SAST/DAST Correlation

### Correlation table
<paste the table from B.2>

### Strongest correlation deep-dive
<paste the work from B.3>

### Reflection (2-3 sentences)
Lecture 5 slide 15 calls this "the highest-confidence finding type." In a real PR review,
which of these two would you want first — the SAST finding or the DAST evidence — and why?
```

---

## Cleanup (after submitting)

```bash
docker stop juice-shop
docker network rm lab5-net
```

---

## How to Submit

```bash
git add submissions/lab5-2.md
git commit -m "feat(lab5-2): ZAP baseline + auth scan + correlation"
git push -u origin feature/lab5-2
```

> **Do NOT commit** `labs/lab5/results/` (scanner outputs are large and regeneratable). The submission paste-in is the evidence.

PR checklist body:

```text
- [ ] Task 1 — ZAP baseline + auth + 10-20× ratio analysis
- [ ] Bonus — Correlation table with 1+ confirmed cross-tool finding (requires Lab 5.1 Semgrep output)
```

---

## Acceptance Criteria

### Task 1 (6 pts)
- ✅ Both ZAP runs complete (baseline + authenticated)
- ✅ Severity tables for both runs in submission match actual JSON output
- ✅ Auth/baseline ratio computed; lecture's 10-20× claim addressed honestly
- ✅ Two auth-only alerts identified with WHY each was unreachable to baseline (1 sentence each, specific)

### Bonus Task (2 pts)
- ✅ Correlation table with ≥1 row showing same vuln found by both Semgrep and ZAP
- ✅ Strongest correlation includes vulnerable code paste + working payload + fix
- ✅ "Why both tools caught it" reflection demonstrates understanding of static/dynamic complementarity

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — DAST | **6** | Both ZAP runs + ratio analysis + 2 auth-only-alert deep-dives |
| **Bonus Task** — Correlation | **2** | ≥1 confirmed correlated finding with code + payload + fix (requires Lab 5.1) |
| **Total** | **8** | 6 main + 2 bonus |

> Combined with **Lab 5.1 (4 pts)** and **Lab 5.3 (4 pts)**, the full Lab 5 series totals **16 points**.

---
