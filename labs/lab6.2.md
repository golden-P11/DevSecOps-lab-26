# Lab 6.2 — Custom Checkov Policy (Policy-as-Code)

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-IaC%20Security-blue)
![points](https://img.shields.io/badge/points-2-orange)
![tech](https://img.shields.io/badge/tech-Checkov%20Custom%20Policies-informational)

> **Goal:** Write a custom Checkov policy in YAML (graph-based or single-resource) and demonstrate it fires on the vulnerable Terraform sample.
> **Deliverable:** A PR from `feature/lab6.2` with `labs/lab6/policies/my-custom-policy.yaml` and `submissions/lab6.2.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 6.1](lab6.1.md) — you should already understand Checkov's Terraform scan output and triage workflow.

> **Part of Lab 6:** This is the Policy-as-Code half of Lab 6. Complete **[Lab 6.1](lab6.1.md)** first; **[Lab 6.3](lab6.3.md)** covers KICS + CI automation.

---

## Overview

In this lab you will practice:
- Writing a **custom Checkov policy** in YAML for a project-specific rule
- Running Checkov with `--external-checks-dir` to load your policy
- Verifying the policy fires on deliberately misconfigured Terraform

> **Genuinely challenging.** Writing custom policies is how Policy-as-Code scales beyond what vendors ship.

---

## Project State

**You should have from Lab 6.1:**
- Checkov 3.x installed locally
- Familiarity with the vulnerable Terraform in `labs/lab6/vulnerable-iac/terraform/`
- Understanding of Checkov rule IDs and triage by frequency

**This lab adds:**
- A custom Checkov policy file in `labs/lab6/policies/`
- Proof that your rule fires on ≥1 resource in the vulnerable sample

---

## Setup

You need:
- **Python 3.10+** + **pip** (Checkov from Lab 6.1)
- **`jq`**

```bash
git switch main && git pull
git switch -c feature/lab6.2

# Verify Checkov is installed
checkov --version

mkdir -p labs/lab6/policies labs/lab6/results
```

---

## Task 2 — Custom Checkov Policy (2 pts)

**Objective:** Write a custom Checkov policy in YAML (graph-based or single-resource — your choice). Apply it to the vulnerable Terraform sample and demonstrate it fires.

### 6.2.1: Pick a rule

Pick a project-specific check that's NOT already in Checkov's built-in catalog. Examples:

- "Every S3 bucket must have a `lifecycle_configuration` block"
- "Every RDS instance must have `iam_database_authentication_enabled = true`"
- "Every IAM policy attached to a Lambda must not have `Action: *` or `Resource: *`"
- "Every CloudWatch log group must have `retention_in_days <= 365`"

### 6.2.2: Write the policy

```yaml
# labs/lab6/policies/my-custom-policy.yaml
# YOUR TASK: Custom Checkov policy
# Required structure:
# metadata:
#   id: CKV2_CUSTOM_1     # CKV_* for single-resource, CKV2_* for graph (cross-resource)
#   name: <descriptive>
#   category: <one of Checkov's standard categories>
#   severity: HIGH | MEDIUM | LOW
# definition:
#   and:                  # or: or, not — Boolean composition
#     - cond_type: filter | attribute | connection
#       attribute: <field-path>
#       value: <expected>
#       operator: equals | within | exists | greater_than | ...
#
# See Checkov docs for the full schema:
# https://www.checkov.io/3.Custom%20Policies/YAML%20Custom%20Policies.html
```

### 6.2.3: Run Checkov with the custom policy

```bash
checkov -d labs/lab6/vulnerable-iac/terraform \
  --external-checks-dir labs/lab6/policies \
  --output cli --output json \
  --output-file-path labs/lab6/results/checkov-custom/
```

### 6.2.4: Verify your policy fires

```bash
# Look for your custom rule ID among the failed checks
jq '[.[].results.failed_checks[]?]
    | map(select(.check_id | startswith("CKV2_CUSTOM_")))' \
  labs/lab6/results/checkov-custom/results_json.json
```

### 6.2.5: Document in `submissions/lab6.2.md`

````markdown
# Lab 6.2 — Submission

## Task 2: Custom Checkov Policy

### Policy file (paste full contents of labs/lab6/policies/my-custom-policy.yaml)
```yaml
<paste>
```

### Rule fires
Output of the 6.2.4 jq (must show ≥1 failed check whose `check_id` starts with `CKV2_CUSTOM_`):
```
<paste — must show ≥1 failed check with YOUR rule ID>
```

### Why this rule matters
2-3 sentences: what real-world incident or compliance requirement does your custom policy address?
(References to specific incidents or NIST/CIS controls strengthen the answer.)
````

---

## How to Submit

```bash
git add labs/lab6/policies/my-custom-policy.yaml
git add submissions/lab6.2.md
git commit -m "feat(lab6.2): custom Checkov policy"
git push -u origin feature/lab6.2
```

> **Do NOT commit** `labs/lab6/results/` — scanner output is regeneratable. Submission paste-ins are the evidence.

PR checklist body:

```text
- [ ] Task 2 — Custom Checkov policy demonstrably firing on the vulnerable sample
```

---

## Acceptance Criteria

### Task 2 (2 pts)
- ✅ Custom policy file exists at `labs/lab6/policies/my-custom-policy.yaml`
- ✅ Policy has valid YAML schema (Checkov accepts it without parse errors)
- ✅ Policy fires on ≥1 resource in the vulnerable Terraform sample (proof in submission)
- ✅ "Why this rule matters" answer references a real incident or compliance control

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 2** — Custom policy | **2** | Valid YAML schema + actually firing on vulnerable resource + business justification |
| **Total** | **2** | |

---
