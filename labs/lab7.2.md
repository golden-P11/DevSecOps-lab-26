# Lab 7.2 — Kubernetes Hardening (PSS + NetworkPolicy)

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Container%20Security-blue)
![points](https://img.shields.io/badge/points-4-orange)
![tech](https://img.shields.io/badge/tech-PSS%20%2B%20NetworkPolicy-informational)

> **Goal:** Deploy Juice Shop to a local K8s cluster with full PSS `restricted` profile compliance, including securityContext, NetworkPolicy, and a non-default ServiceAccount.
> **Deliverable:** A PR from `feature/lab7.2` with hardened K8s manifests in `labs/lab7/k8s/` and `submissions/lab7.2.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 7.1](lab7.1.md) recommended — you should already understand Trivy image scanning before hardening the deployment.

> **Part of Lab 7:** This is the Kubernetes hardening half of Lab 7. Complete **[Lab 7.1](lab7.1.md)** first; **[Lab 7.3](lab7.3.md)** covers Conftest policy gate + CI automation.

---

## Overview

In this lab you will practice:
- Hardening a K8s Deployment with **Pod Security Standards** (`restricted` profile) + **`securityContext`** + **NetworkPolicy** (Lectures 7 slides 11-15)
- **Trivy `k8s` mode** against a live cluster to verify manifest compliance

> ⏭️ Optional. Skipping won't affect future labs, but you miss the most concrete shift-right experience of the course.

---

## Project State

**You should have from Lab 7.1:**
- Trivy v0.69.x installed locally
- Familiarity with Juice Shop image (`bkimminich/juice-shop:v20.0.0`)
- Image digest from Lab 4 for pinning

**This lab adds:**
- Four hardened Kubernetes manifests under `labs/lab7/k8s/`
- Trivy K8s scan results against the running deployment

---

## Setup

You need:
- **Docker**
- **Trivy v0.69.x**
- **`kubectl`** + **`kind`** or **`k3d`** — for a local Kubernetes cluster
- **`jq`**

```bash
git switch main && git pull
git switch -c feature/lab7.2

# Verify
trivy --version && kubectl version --client && docker --version

# Start a local K8s cluster
kind create cluster --name lab7 --image kindest/node:v1.33.0
# OR: k3d cluster create lab7 --image rancher/k3s:v1.33.0-k3s1

kubectl cluster-info

mkdir -p labs/lab7/{results,k8s}
```

---

## Task 2 — Kubernetes Hardening (4 pts)

**Objective:** Deploy Juice Shop to your local K8s cluster with full PSS `restricted` profile compliance, including securityContext, NetworkPolicy, and a non-default ServiceAccount.

### 7.2.1: Write the hardened manifests

Create the following files. **The lab does NOT ship them as plumbing** — writing them is the skill.

#### `labs/lab7/k8s/namespace.yaml`

```yaml
# YOUR TASK: namespace with PSS labels
apiVersion: v1
kind: Namespace
metadata:
  name: juice-shop
  labels:
    # PSS enforce: restricted (Lecture 7 slide 11)
    # Pick all three: enforce, warn, audit — all set to restricted
    # pod-security.kubernetes.io/enforce: <?>
    # pod-security.kubernetes.io/warn: <?>
    # pod-security.kubernetes.io/audit: <?>
```

#### `labs/lab7/k8s/serviceaccount.yaml`

A dedicated SA with `automountServiceAccountToken: false` (Lecture 7 slide 12 anti-pattern).

#### `labs/lab7/k8s/deployment.yaml`

```yaml
# YOUR TASK: Juice Shop Deployment with FULL hardening
# Requirements (all required for PSS restricted compliance):
#   - serviceAccountName: <your dedicated SA>
#   - automountServiceAccountToken: false
#   - pod-level securityContext:
#       runAsNonRoot: true
#       runAsUser: 1000      # Juice Shop runs as UID 1000 by default
#       fsGroup: 1000
#       seccompProfile: { type: RuntimeDefault }
#   - container-level securityContext:
#       allowPrivilegeEscalation: false
#       readOnlyRootFilesystem: true       # See pitfalls — Juice Shop writes /tmp
#       capabilities: { drop: ["ALL"] }
#   - resources.limits.{memory,cpu} + resources.requests.{memory,cpu}
#   - image pinned by digest: bkimminich/juice-shop@sha256:<from your Lab 4 capture>
#
# Hint: readOnlyRootFilesystem=true breaks Juice Shop. Mount emptyDir
#       at /tmp, /usr/src/app/logs, and any other path Juice Shop writes to.
```

#### `labs/lab7/k8s/networkpolicy.yaml`

```yaml
# YOUR TASK: default-deny + allow-ingress-from-localhost
# Requirements (Lecture 7 slide 15):
#   - podSelector matching app=juice-shop
#   - policyTypes: [Ingress, Egress]
#   - ingress: explicitly allow from-namespace-ingress-controller-or-localhost-port-forward
#   - egress: explicitly allow DNS (UDP 53 to kube-system) and HTTPS (TCP 443) — nothing else
```

### 7.2.2: Apply + verify

```bash
kubectl apply -f labs/lab7/k8s/

# Wait for the pod
kubectl -n juice-shop wait --for=condition=ready pod -l app=juice-shop --timeout=120s

# Capture full pod spec for proof
kubectl -n juice-shop get pod -l app=juice-shop -o yaml > labs/lab7/results/pod-spec.yaml

# Quick PSS compliance check
kubectl -n juice-shop describe pod -l app=juice-shop | grep -A 3 -i "security context"
```

### 7.2.3: Trivy K8s scan

```bash
trivy k8s --include-namespaces juice-shop \
  --severity HIGH,CRITICAL \
  --format json --output labs/lab7/results/trivy-k8s.json

trivy k8s --include-namespaces juice-shop \
  --severity HIGH,CRITICAL \
  --report=summary
```

### 7.2.4: Document in `submissions/lab7.2.md`

````markdown
# Lab 7.2 — Submission

## Task 2: Kubernetes Hardening

### Manifests (paste relevant snippets)
- `namespace.yaml` PSS labels:
```yaml
<paste the three labels>
```
- `deployment.yaml` securityContext sections (pod + container):
```yaml
<paste>
```
- `networkpolicy.yaml` ingress + egress:
```yaml
<paste>
```

### Pod is running
Output of `kubectl get pod -n juice-shop -l app=juice-shop`:
```
<paste — must show Running, Ready 1/1>
```

### Trivy K8s scan
| Severity | Count |
|----------|------:|
| Critical | <n> |
| High | <n> |

### What broke and how you fixed it (2-3 sentences)
`readOnlyRootFilesystem: true` likely broke Juice Shop. What paths did it need to write?
How did you fix it (which emptyDir mounts)?
````

---

## How to Submit

```bash
git add labs/lab7/k8s/
git add submissions/lab7.2.md
git commit -m "feat(lab7.2): PSS restricted k8s deployment + networkpolicy"
git push -u origin feature/lab7.2

# Cleanup the cluster after submitting
kind delete cluster --name lab7    # or k3d cluster delete lab7
```

> **Do NOT commit** `labs/lab7/results/` — regeneratable.

PR checklist body:

```text
- [ ] Task 2 — Hardened K8s deployment with PSS restricted + NetworkPolicy
```

---

## Acceptance Criteria

### Task 2 (4 pts)
- ✅ All four manifests written (namespace, sa, deployment, networkpolicy)
- ✅ Namespace has all three PSS labels (enforce + warn + audit) set to `restricted`
- ✅ Deployment passes PSS restricted (pod is Running 1/1; no PSS warnings in describe)
- ✅ Trivy `k8s` scan completes; result documented
- ✅ "What broke and how you fixed it" addresses readOnlyRootFilesystem specifically

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 2** — K8s hardening | **4** | 4 manifests + pod runs + Trivy K8s scan + read-only-root debug story |
| **Total** | **4** | |

---
