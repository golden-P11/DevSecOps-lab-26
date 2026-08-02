# Lab 9.3 — Cryptominer Detection

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Runtime%20Detection-blue)
![points](https://img.shields.io/badge/points-2-orange)
![tech](https://img.shields.io/badge/tech-Falco-informational)

> **Goal:** Write a Falco rule that detects a cryptominer-style network pattern and prove it fires on a controlled trigger.
> **Deliverable:** A PR from `feature/lab9.3` with `labs/lab9/falco/rules/custom-rules.yaml` and `submissions/lab9.3.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 9.1](lab9.1.md) (Falco custom rules) — you append the cryptominer rule to the same `custom-rules.yaml`.

> **Part of Lab 9:** This is the bonus half of Lab 9. Complete **[Lab 9.1](lab9.1.md)** and **[Lab 9.2](lab9.2.md)** separately.

---

## Overview

In this lab you will practice:
- **Cryptominer-style detection** — a Falco rule that catches network egress to known mining-pool patterns

---

## Project State

**You should have from Lab 9.1:**
- `labs/lab9/falco/rules/custom-rules.yaml` with your `/tmp` write rule
- Familiarity with Falco eBPF container setup

**This lab adds:**
- Cryptominer detection rule appended to `custom-rules.yaml`

---

## Setup

You need:
- **Docker** (for local Falco triggers)

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

## How to Submit

```bash
git add labs/lab9/falco/rules/custom-rules.yaml
git add submissions/lab9.3.md
git commit -m "feat(lab9.3): cryptominer detection rule + submission"
git push -u origin feature/lab9.3
```

Open a PR to `main`.

> **Do NOT commit** `labs/lab9/falco/logs/` — paste the triggered alert JSON into your submission instead.

PR checklist body:

```text
- [ ] Cryptominer detection rule with ≥2 indicators in custom-rules.yaml
- [ ] Triggered alert pasted in submissions/lab9.3.md
- [ ] Reflection covers false-negative case + SLA matrix integration
```

---

## Acceptance Criteria

- ✅ Cryptominer rule combines ≥2 indicators (port OR process OR DNS)
- ✅ Rule fires on the `nc` test trigger (visible in Falco log)
- ✅ Submission includes rule YAML, triggered alert JSON, and reflection
- ✅ Reflection covers false-negative case + SLA matrix integration

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Bonus Task** — Cryptominer rule | **2** | 2+ indicators + triggered alert + reflection on FN + SLA |
| **Total** | **2** | |

---
