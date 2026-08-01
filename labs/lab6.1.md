# Lab 6.1 — Checkov on Terraform

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-IaC%20Security-blue)
![points](https://img.shields.io/badge/points-6-orange)
![tech](https://img.shields.io/badge/tech-Checkov-informational)

> **Goal:** Scan vulnerable Terraform with Checkov; identify findings; group by module/rule frequency to find the highest-leverage fixes.
> **Deliverable:** A PR from `feature/lab6.1` with `submissions/lab6.1.md` (findings tables + module-leverage analysis). Submit PR link via Moodle.

> **Part of Lab 6:** This is the first part of Lab 6. Complete **[Lab 6.2](lab6.2.md)** (custom policy) and **[Lab 6.3](lab6.3.md)** (KICS + CI) separately.

---

## Overview

In this lab you will practice:
- **Checkov 3.x** on Terraform (~2,500 built-in policies, including 800+ graph-based) — Lecture 6
- **Triage at the module level** (Lecture 6 slide 17 — one fix at module level closes many findings)

> Plumbing in `labs/lab6/vulnerable-iac/` contains deliberately misconfigured IaC across all three formats. Don't fix the files — analyze them.

---

## Project State

**You should have from Labs 1-5:**
- A working `feature/labN` PR workflow + signed commits + pre-commit secret scanning
- A general feel for "static text → security findings" from Lab 5's SAST work

**This lab adds:**
- Checkov scan report on the vulnerable Terraform sample
- Module-leverage triage analysis

---

## Setup

You need:
- **Python 3.10+** + **pip**
- **`jq`**

```bash
git switch main && git pull
git switch -c feature/lab6.1

# Install Checkov (course pins 3.x)
pip install checkov

# Verify
checkov --version

# Examine the vulnerable IaC (don't fix it — that's the lecture exercise)
ls labs/lab6/vulnerable-iac/terraform

mkdir -p labs/lab6/results
```

> **Plumbing provided** (in `labs/lab6/vulnerable-iac/`):
> - `terraform/` — deliberately misconfigured AWS resources (IAM, RDS, DynamoDB, security groups)
> - `README.md` — documents the vulnerability classes each file targets

---

## Task 1 — Checkov on Terraform (6 pts)

**Objective:** Scan the Terraform sample with Checkov; identify findings; group by module/rule frequency to find the highest-leverage fixes.

> **Why Terraform-only for Checkov?** Pulumi is real Python; Checkov 3.x does not have a `pulumi` framework directly (it expects rendered state via `pulumi preview --json` OR the SAST-Python framework). To keep the lab's tool surface manageable, **Pulumi is scanned with KICS** in [Lab 6.3](lab6.3.md) (which natively understands Pulumi source). You'll see the trade-off live: tool ecosystems specialize differently.

### 6.1.1: Scan Terraform

```bash
checkov -d labs/lab6/vulnerable-iac/terraform \
  --output cli --output json \
  --output-file-path labs/lab6/results/checkov-terraform/
```

### 6.1.2: Triage by rule frequency

Checkov scans the directory with several frameworks at once (`terraform` and `secrets`), so
`results_json.json` is a JSON **array** — one object per framework. Open-source Checkov doesn't
assign severities (that's a Prisma Cloud feature), so you triage by **how often each rule fires**:
the most frequent rule is the one a single module-level fix can clear in bulk (Lecture 6 slide 17).

```bash
# Top 5 rule IDs by count — the highest-leverage fixes
jq '[.[].results.failed_checks[]?.check_id]
    | group_by(.) | map({rule: .[0], count: length})
    | sort_by(-.count) | .[:5]' \
  labs/lab6/results/checkov-terraform/results_json.json

# Passed / failed per framework
jq 'map({framework: .check_type, passed: .summary.passed, failed: .summary.failed})' \
  labs/lab6/results/checkov-terraform/results_json.json
```

### 6.1.3: Document in `submissions/lab6.1.md`

```markdown
# Lab 6.1 — Submission

## Task 1: Checkov on Terraform

### Terraform scan (passed/failed per framework)
| Framework | Passed | Failed |
|-----------|-------:|-------:|
| terraform | <n> | <n> |
| secrets | <n> | <n> |

### Top 5 rule IDs (by frequency)
| Rule ID | Count | What it checks |
|---------|------:|----------------|
| <CKV_AWS_*> | <n> | <1-line description> |

### Module-leverage analysis (Lecture 6 slide 17)
Looking at your top-5 Terraform rules, which ONE fix would eliminate the most findings if applied
at the module level? (2-3 sentences. e.g., "If the shared IAM policy dropped its `Resource: "*"`
wildcard, the CKV_AWS_355/289/290 findings on every policy would collapse into one fix.")
```

---

## How to Submit

```bash
git add submissions/lab6.1.md
git commit -m "feat(lab6.1): Checkov Terraform scan + module-leverage analysis"
git push -u origin feature/lab6.1
```

> **Do NOT commit** `labs/lab6/results/` — scanner output is regeneratable. Submission paste-ins are the evidence.

PR checklist body:

```text
- [x] Task 1 — Checkov on Terraform with top-5 rules and module-leverage analysis
```

---

## Acceptance Criteria

### Task 1 (6 pts)
- ✅ Checkov scan completes on the Terraform sample
- ✅ Passed/failed table matches actual JSON output (no placeholders)
- ✅ Top-5 rules table populated with real CKV_AWS_* IDs + descriptions
- ✅ Module-leverage analysis identifies ONE concrete fix with multi-finding impact

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — Checkov | **6** | Terraform scan + top-5 rules + module-leverage analysis |
| **Total** | **6** | |

---
