# Lab 9.1 — Runtime Detection with Falco

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Runtime%20Detection-blue)
![points](https://img.shields.io/badge/points-6-orange)
![tech](https://img.shields.io/badge/tech-Falco%20%2B%20eBPF-informational)

> **Goal:** Run Falco with modern eBPF, trigger baseline + custom alerts, and document tuning considerations for your custom rule.
> **Deliverable:** A PR from `feature/lab9.1` with `labs/lab9/falco/rules/custom-rules.yaml` and `submissions/lab9.1.md`. Submit PR link via Moodle.

> **Part of Lab 9:** This is the Falco runtime half of Lab 9. Complete **[Lab 9.2](lab9.2.md)** (Conftest Policy-as-Code) and **[Lab 9.3](lab9.3.md)** (cryptominer bonus) separately.

---

## Overview

In this lab you will practice:
- **Falco v0.43.x** runtime detection via modern eBPF (Lecture 9 slides 5-8)
- **Custom Falco rules** with `condition:` + `exceptions:` (Lecture 9 slide 8)

> Lecture 9 slide 6 — Falco is "the runtime equivalent of grep — fast, predictable, composable." This lab is where you actually wield it.

---

## Project State

**You should have from Labs 1-8:**
- Juice Shop image (Lab 1), hardened K8s deployment from Lab 7 (or you'll re-deploy)
- Lab 7's Conftest preview (Lab 9.2 goes deep on it)

**This lab adds:**
- Falco running in a container with custom rules
- Captured Falco alerts proving runtime detection works

---

## Setup

You need:
- **Docker** (Falco runs containerized)
- **`jq`**
- **A Linux kernel with eBPF + BTF** (for Falco's modern driver). Native Linux and WSL2 (kernel ≥ 5.8) work out of the box. **macOS — including Apple Silicon — does NOT work through Docker Desktop**: its LinuxKit VM kernel ships without BTF, so Falco runs but detects nothing. Use **Colima** instead — see Common Pitfalls → "macOS / Apple Silicon"

```bash
git switch main && git pull
git switch -c feature/lab9.1

# Verify
docker --version

mkdir -p labs/lab9/{falco/{rules,logs},policies/extra,analysis}
```

> **Plumbing provided** (already in `labs/lab9/`):
> - [`labs/lab9/manifests/`](lab9/manifests/) — `k8s/juice-{hardened,unhardened}.yaml` + `compose/juice-compose.yml`
> - [`labs/lab9/policies/`](lab9/policies/) — starter Conftest policies for both shapes (`k8s-security.rego`, `compose-security.rego`)

---

## Task 1 — Runtime Detection with Falco (6 pts)

**Objective:** Run Falco against a target container, trigger 2 baseline alerts + 1 custom alert.

### 9.1.1: Start the target container

```bash
docker run -d --name lab9-target alpine:3.20 sleep 1d
```

### 9.1.2: Run Falco with modern eBPF

```bash
docker run -d --name falco \
  --privileged \
  -v /proc:/host/proc:ro \
  -v /boot:/host/boot:ro \
  -v /lib/modules:/host/lib/modules:ro \
  -v /usr:/host/usr:ro \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v "$(pwd)/labs/lab9/falco/rules":/etc/falco/rules.d:ro \
  falcosecurity/falco:0.43.1 \
  falco -U \
        -o json_output=true \
        -o time_format_iso_8601=true

# Follow Falco logs in a separate terminal OR background it
docker logs -f falco > labs/lab9/falco/logs/falco.log 2>&1 &
LOGS_PID=$!
echo "Falco logs tail PID: $LOGS_PID — kill it when done"

# Give Falco a moment to initialize
sleep 5
```

### 9.1.3: Trigger 2 baseline alerts

```bash
# Trigger A: Terminal shell in container — built-in rule
docker exec -it lab9-target /bin/sh -lc 'echo "shell-in-container test"'

# Trigger B: Read a sensitive file — built-in "Read sensitive file untrusted" rule
docker exec lab9-target /bin/sh -lc 'cat /etc/shadow'

# Wait a few seconds, then check Falco alerts
sleep 3
grep -E "(Terminal shell|Read sensitive file)" labs/lab9/falco/logs/falco.log | head -10
```

### 9.1.4: Write 1 custom Falco rule

Create `labs/lab9/falco/rules/custom-rules.yaml`:

```yaml
# YOUR TASK: Write a custom Falco rule
# Requirements (Lecture 9 slide 7):
#   - rule: "Write to /tmp by container"
#   - condition: detects writes to /tmp inside any container (NOT host)
#   - output: should include container.name + user.name + fd.name + proc.cmdline
#   - priority: WARNING
#   - tags: [container, drift]
#
# Hint: Falco ships the `open_write` macro — read it inside the container:
#       docker exec falco cat /etc/falco/falco_rules.yaml | grep -A2 'macro: open_write'
#       Your rule combines open_write + a container check (container.id != host) +
#       fd.name startswith /tmp/.
```

Falco auto-reloads rules in `/etc/falco/rules.d/`. To force reload after editing:

```bash
docker kill --signal=SIGHUP falco && sleep 3
```

### 9.1.5: Trigger your custom rule

```bash
docker exec --user 0 lab9-target /bin/sh -lc 'echo "test" > /tmp/my-write.txt'
sleep 3
grep "Write to /tmp by container" labs/lab9/falco/logs/falco.log | head -5
```

### 9.1.6: Document in `submissions/lab9.1.md`

````markdown
# Lab 9.1 — Submission

## Task 1: Runtime Detection with Falco

### Baseline alert A — Terminal shell in container
JSON alert from Falco logs (paste the most relevant lines):
```json
<paste>
```

### Baseline alert B — Read sensitive file untrusted (`cat /etc/shadow`)
```json
<paste>
```

### Custom rule (paste labs/lab9/falco/rules/custom-rules.yaml)
```yaml
<paste full rule>
```

### Custom rule fired
Falco log line showing your custom rule:
```json
<paste>
```

### Tuning consideration (Lecture 9 slide 8)
Your custom "write to /tmp" rule will fire on legitimate uses too (logging frameworks
often write to /tmp). What's your tuning approach? (2-3 sentences referencing the
`exceptions:` block vs `and not proc.name=...` patterns from Lecture 9.)
````

---

## Cleanup

```bash
# Stop the tail
kill $LOGS_PID 2>/dev/null || true

# Stop containers
docker stop falco lab9-target
docker rm falco lab9-target
```

---

## How to Submit

```bash
git add labs/lab9/falco/rules/custom-rules.yaml
git add submissions/lab9.1.md
git commit -m "feat(lab9.1): falco custom rules + runtime detection evidence"
git push -u origin feature/lab9.1
```

> **Do NOT commit** `labs/lab9/falco/logs/` — log files are large and student-specific. Submission paste-ins are the evidence.

PR checklist body:

```text
- [x] Task 1 — 2 baseline + 1 custom Falco alert with tuning discussion
```

---

## Acceptance Criteria

### Task 1 (6 pts)
- ✅ Falco running with modern eBPF (verify with `docker logs falco | grep -i engine`)
- ✅ Both baseline alerts (Terminal shell + Read sensitive file) appear in Falco logs
- ✅ Custom rule `custom-rules.yaml` exists with required fields
- ✅ Custom rule fires (visible in Falco log after the test trigger)
- ✅ Tuning consideration mentions `exceptions:` block OR `and not` pattern with reasoning

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — Falco runtime | **6** | 2 baseline + 1 custom alert + tuning discussion |
| **Total** | **6** | |

---
