# Lab 9.2 — Conftest Policy-as-Code

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Policy-as-Code-blue)
![points](https://img.shields.io/badge/points-4-orange)
![tech](https://img.shields.io/badge/tech-Conftest%20%2B%20Rego-informational)

> **Goal:** Write Rego policies for Conftest that catch ≥3 K8s manifest hardening issues at CI time, then run the shipped compose policy to see the same `deny[msg]` skill generalize to a second target shape.
> **Deliverable:** A PR from `feature/lab9.2` with `labs/lab9/policies/extra/hardening.rego` and `submissions/lab9.2.md`. Submit PR link via Moodle.

> **Part of Lab 9:** This is the Conftest half of Lab 9. Complete **[Lab 9.1](lab9.1.md)** (Falco runtime) and **[Lab 9.3](lab9.3.md)** (cryptominer bonus) separately.

> ⏭️ Optional. Skipping won't affect future labs.

---

## Overview

In this lab you will practice:
- **Conftest / Rego** for K8s admission policy (Lecture 9 slides 9-10)

---

## Project State

**You should have from Labs 1-8:**
- Juice Shop image (Lab 1), hardened K8s deployment from Lab 7
- Lab 7's Conftest preview (this lab goes deep on it)

**This lab adds:**
- Conftest policies gating ≥3 hardening requirements at CI time

---

## Setup

You need:
- **`conftest`** v0.68.x — `brew install conftest` (Lab 7 bonus used this if you did it)

```bash
git switch main && git pull
git switch -c feature/lab9.2

conftest --version

mkdir -p labs/lab9/policies/extra
```

> **Plumbing provided** (already in `labs/lab9/`):
> - [`labs/lab9/manifests/`](lab9/manifests/) — `k8s/juice-{hardened,unhardened}.yaml` + `compose/juice-compose.yml`
> - [`labs/lab9/policies/`](lab9/policies/) — starter Conftest policies for both shapes (`k8s-security.rego`, `compose-security.rego`)
>
> Read these files before writing your own — they show the Rego style + sample manifest shape.

---

## Task 2 — Conftest Policy-as-Code (4 pts)

**Objective:** Write Rego policies for Conftest that catch ≥3 K8s manifest hardening issues at CI time, then run the shipped compose policy to see the same `deny[msg]` skill generalize to a second target shape.

### 9.2.1: Read the provided manifests + starter policies

```bash
ls labs/lab9/manifests/k8s/
# Should show: juice-hardened.yaml (compliant), juice-unhardened.yaml (non-compliant)

ls labs/lab9/policies/
# Two starter policies, one per target shape:
#   k8s-security.rego      (package k8s.security)     — K8s Deployments (input.spec.template.spec)
#   compose-security.rego  (package compose.security) — docker-compose  (input.services)

cat labs/lab9/policies/*.rego
# Read both — note how the SAME deny[msg] pattern adapts to two different input shapes.
# Task 2 has you EXTEND the K8s one (9.2.2) and RUN the compose one (9.2.3).
```

### 9.2.2: Write your Conftest policies

Add to `labs/lab9/policies/extra/`:

```rego
# labs/lab9/policies/extra/hardening.rego
# YOUR TASK: Rego policies for 3+ K8s hardening rules
# Required denies (one Rego rule per requirement):
#   1. runAsNonRoot must be true (pod-level or container-level securityContext)
#   2. allowPrivilegeEscalation must be false (every container)
#   3. capabilities.drop must include "ALL" (every container)
#   4. (optional 4th) resources.limits.memory must be set
#   5. (optional 5th) image must use sha256: digest, not :tag
#
# Hints:
#   - Lecture 9 slide 10 shows the deny[msg] pattern
#   - `not <something>` is your friend
#   - For arrays: `not "ALL" in container.securityContext.capabilities.drop`
#     (requires Rego v1 — recent OPA/Conftest versions)
```

### 9.2.3: Run Conftest — your K8s policy + the shipped compose policy

**A. Your K8s policy** (`policies/extra/`) against the shipped manifests:

```bash
# Compliant manifest — should PASS (0 failures)
conftest test labs/lab9/manifests/k8s/juice-hardened.yaml \
  --policy labs/lab9/policies/extra/

# Non-compliant manifest — should FAIL with multiple deny messages
# (juice-unhardened has no securityContext, no resources, and a :latest tag,
#  so it trips several of your rules at once)
conftest test labs/lab9/manifests/k8s/juice-unhardened.yaml \
  --policy labs/lab9/policies/extra/
```

**B. The shipped compose policy** — same `deny[msg]` skill, a different target shape.
It declares `package compose.security`, so Conftest needs `--namespace compose.security`
to find its rules (Conftest defaults to the `main` namespace):

```bash
# Shipped hardened compose — should PASS
conftest test labs/lab9/manifests/compose/juice-compose.yml \
  --policy labs/lab9/policies/compose-security.rego \
  --namespace compose.security

# A deliberately unhardened compose — should FAIL (no user / read_only / cap_drop)
cat > /tmp/bad-compose.yml <<'EOF'
services:
  app:
    image: nginx:latest
    ports: ["8080:80"]
EOF
conftest test /tmp/bad-compose.yml \
  --policy labs/lab9/policies/compose-security.rego \
  --namespace compose.security
```

### 9.2.4: Document in `submissions/lab9.2.md`

````markdown
# Lab 9.2 — Submission

## Task 2: Conftest Policy-as-Code

### My policy file (paste labs/lab9/policies/extra/hardening.rego)
```rego
<paste>
```

### Compliant manifest passes (juice-hardened.yaml)
```
<paste conftest output — 0 failures>
```

### Non-compliant manifest fails (juice-unhardened.yaml)
```
<paste conftest output — must show ≥2 distinct deny messages,
 e.g. runAsNonRoot + allowPrivilegeEscalation + dropped capabilities>
```

### Compose policy generalizes (shipped compose-security.rego)
```
<paste both runs — PASS on juice-compose.yml, FAIL on /tmp/bad-compose.yml —
 showing the same deny[msg] pattern works on input.services>
```

### Why CI-time vs admission-time (Lecture 9 slide 9)
2-3 sentences. CI-time Conftest happens during PR review; admission-time Conftest happens at
`kubectl apply`. What's the operational benefit of running BOTH (defense in depth)?
````

---

## How to Submit

```bash
git add labs/lab9/policies/extra/
git add submissions/lab9.2.md
git commit -m "feat(lab9.2): conftest hardening policies"
git push -u origin feature/lab9.2
```

PR checklist body:

```text
- [ ] Task 2 — ≥3 Conftest rules (K8s pass/fail) + shipped compose policy run
```

---

## Acceptance Criteria

### Task 2 (4 pts)
- ✅ ≥3 Rego rules in `labs/lab9/policies/extra/`
- ✅ Compliant manifest (`juice-hardened.yaml`) PASSES (0 failures from conftest)
- ✅ Non-compliant manifest (`juice-unhardened.yaml`) FAILS with ≥2 distinct deny messages
- ✅ Shipped `compose-security.rego` run shown — PASS on `juice-compose.yml`, FAIL on a bad compose
- ✅ CI-vs-admission answer demonstrates understanding of defense-in-depth

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 2** — Conftest policies | **4** | 3+ Rego rules + K8s good/bad + shipped compose policy run + CI/admission reasoning |
| **Total** | **4** | |

---
