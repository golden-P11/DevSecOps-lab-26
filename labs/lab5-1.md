# Lab 5.1 — SAST: Scanning Juice Shop Source with Semgrep

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-SAST-blue)
![points](https://img.shields.io/badge/points-4-orange)
![tech](https://img.shields.io/badge/tech-Semgrep-informational)

> **Goal:** Run SAST with **Semgrep** against OWASP Juice Shop v20.0.0 source code, analyze severity breakdown and top findings, and triage one false positive.
> **Deliverable:** A PR from `feature/lab5-1` with `submissions/lab5-1.md` (Semgrep analysis). Submit PR link via Moodle.

> **Part of Lab 5:** This is the SAST half of Lab 5. Complete **Lab 5.2 (DAST)** separately; the optional correlation bonus lives there and requires Semgrep output from this lab. **Lab 5.3** automates both scans in GitHub Actions.

---

## Overview

In this lab you will practice:
- **SAST** with **Semgrep** (Lecture 5) — `p/owasp-top-ten` ruleset against Juice Shop source
- **Triage** — sorting findings by rule frequency and picking what to fix first (Lecture 5 slide 8)
- **False-positive review** — suppressing a finding only after inspecting the specific code

You do **not** need a running Juice Shop container for this lab — Semgrep analyzes source code statically. Pin the clone to **v20.0.0** so results stay comparable with the container image used in Lab 5.2.

---

## Project State

**You should have from Labs 1–4:**
- Familiarity with Juice Shop v20.0.0 (Lab 1)
- The CycloneDX SBOM from Lab 4 (informs which dependencies your SAST review should focus on)
- Signed commits + pre-commit hooks working (Lab 3)

**This lab adds:**
- A Semgrep scan of Juice Shop source code pinned to v20.0.0
- A severity breakdown + top-10-by-rule analysis
- One documented false-positive triage decision

---

## Setup

You need:
- **Semgrep** — `pip install semgrep` (course pins **Semgrep CE 1.x latest**)
- **`jq`** + **`git`**
- **~3 GB free disk** for Juice Shop source code (~200 MB compressed; Semgrep needs space for its parser cache)

```bash
git switch main && git pull
git switch -c feature/lab5-1

# Verify
semgrep --version
```

```bash
mkdir -p labs/lab5/results
```

---

## Task 1 — SAST with Semgrep (4 pts)

**Objective:** Clone Juice Shop source, run Semgrep with the OWASP Top 10 ruleset, analyze the top findings.

### 5.1: Clone the Juice Shop source

```bash
# Pin to v20.0.0 — same tag as the running container in Lab 5.2
git clone --depth 1 --branch v20.0.0 \
  https://github.com/juice-shop/juice-shop.git \
  labs/lab5/semgrep/juice-shop

du -sh labs/lab5/semgrep/juice-shop
# ~200 MB
```

### 5.2: Run Semgrep

```bash
# OWASP Top 10 community ruleset + JavaScript-specific rules
semgrep \
  --config=p/owasp-top-ten \
  --config=p/javascript \
  --config=p/secrets \
  labs/lab5/semgrep/juice-shop \
  --json -o labs/lab5/results/semgrep.json \
  --severity ERROR --severity WARNING

# Human-readable summary
semgrep \
  --config=p/owasp-top-ten \
  --config=p/javascript \
  labs/lab5/semgrep/juice-shop \
  --severity ERROR | tee labs/lab5/results/semgrep.txt
```

### 5.3: Analyze top findings

```bash
# Severity breakdown
jq '[.results[].extra.severity] | group_by(.) | map({severity: .[0], count: length})' \
  labs/lab5/results/semgrep.json

# Top 10 by rule ID frequency (Lecture 5 slide 8: "sort by rule ID frequency first")
jq '[.results[].check_id] | group_by(.) | map({rule: .[0], count: length}) |
    sort_by(-.count) | .[:10]' \
  labs/lab5/results/semgrep.json
```

### 5.4: Document in `submissions/lab5-1.md`

```markdown
# Lab 5.1 — Submission

## Task 1: SAST with Semgrep

### Semgrep severity breakdown
| Severity | Count |
|----------|------:|
| ERROR | <n> |
| WARNING | <n> |
| INFO | <n> |
| **Total** | <n> |

### Top 10 rules by frequency
| Rule ID | Count | OWASP category |
|---------|------:|----------------|
| <e.g., javascript.express.security.injection.tainted-sql> | <n> | A03 |
| ... |

### Triage shortcut (Lecture 5 slide 8)
Looking at the top 10 — which **one rule** would you fix first if you had time for only one?
Why? (2-3 sentences. Likely answer: the highest-frequency rule that's not a duplicate
of patterns the team already knows about; one fix at the module level closes many findings.)

### False-positive sample
Pick **one** finding you'd suppress as a false positive after review. Quote the file path +
rule + 1-sentence reason. (NOT generic — must reference the specific code.)
```

---

## Cleanup (after submitting)

```bash
rm -rf labs/lab5/semgrep/juice-shop      # 200MB; keep if you'll re-run; delete to save space
```

---

## How to Submit

```bash
git add submissions/lab5-1.md
git commit -m "feat(lab5-1): Semgrep SAST analysis"
git push -u origin feature/lab5-1
```

> **Do NOT commit** `labs/lab5/results/` (scanner outputs are large and regeneratable) or `labs/lab5/semgrep/juice-shop/` (200MB clone). The submission paste-in is the evidence.

PR checklist body:

```text
- [ ] Task 1 — Semgrep severity breakdown + top-10 rules + triage shortcut + false-positive sample
```

---

## Acceptance Criteria

### Task 1 (4 pts)
- ✅ Semgrep run against pinned v20.0.0 source (NOT main branch — must match the Juice Shop container tag used in Lab 5.2)
- ✅ Severity breakdown + top-10-by-rule table populated
- ✅ Triage-shortcut answer references the specific rule with reasoning
- ✅ One concrete false-positive identified with specific file path + reason

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — SAST | **4** | Semgrep run + severity table + top-10 rules + triage-shortcut + FP sample |
| **Total** | **4** | |

---

