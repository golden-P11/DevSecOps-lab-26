# Lab 3.2 — Secure Git: History Hygiene

![difficulty](https://img.shields.io/badge/difficulty-beginner-success)
![topic](https://img.shields.io/badge/topic-Secure%20Git-blue)
![points](https://img.shields.io/badge/points-2-orange)
![tech](https://img.shields.io/badge/tech-Git%20%2B%20filter--repo-informational)

> **Goal:** Complete the gitleaks tune-out exercise and (bonus) rewrite history to purge a planted secret.
> **Deliverable:** A PR from `feature/lab3.2` with updated `submissions/lab3.2.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 3.1](lab3.1.md) — SSH signing and gitleaks pre-commit hook must be working.

---

## Overview

In this lab you will practice:
- **History rewriting with `git filter-repo`** — the cleanup tool when prevention failed

> This is the tool you'll use the day a real secret slips past your hooks. Doing it once on a sandbox repo means you'll know the workflow when it counts.

---

## Setup

You need from Lab 3.1:
- Working SSH commit signing
- `.pre-commit-config.yaml` with gitleaks installed

Additional requirement for the bonus task:
- **`git-filter-repo`** — `sudo apt install git-filter-repo`

```bash
# Branch off main
git switch main && git pull
git switch -c feature/lab3.2

sudo apt install git-filter-repo     # for the bonus task
git-filter-repo --version
```

---

## Bonus Task — History Rewrite with `git filter-repo` (2 pts)

> 🌟 **Practical & genuinely tricky.**

**Objective:** Plant a fake secret in a fresh sandbox repo, push it, then **rewrite history** with `git filter-repo` to purge the secret across all commits and force-push. Document the gotchas.

### B.1: Set up the sandbox

```bash
# Work outside your course fork — this is a throwaway repo
cd /tmp
mkdir lab3-bonus && cd lab3-bonus
git init
git commit --allow-empty -m "init"

# Plant a secret across three commits to make rewriting non-trivial
echo "API_KEY=ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJ" > config.txt
git add config.txt && git commit -m "feat: add config"

echo "log file" > app.log
git add app.log && git commit -m "feat: empty log"

echo "API_KEY=ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJ" >> README.md
git add README.md && git commit -m "docs: add usage notes"

# Verify the secret is in history
git log -p | grep -c 'ghp_AAAA'
# Should print: 2 (two commits contain the secret)
```

### B.2: Rewrite history

```bash
# Use a replacement file to swap the secret everywhere
echo 'ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJ==>[REDACTED]' > /tmp/replace.txt

# YOUR TASK: 
run git filter-repo --replace-text /tmp/replace.txt
# Hint: filter-repo refuses to run if there's an existing remote (this is a sandbox so no issue)

# Verify the rewrite
git log -p | grep -c 'ghp_AAAA'
# Should now print: 0

git log -p | grep -c 'REDACTED'
# Should print: 2 (the secret is gone; the marker remains)
```

### B.3: Document in `submissions/lab3.2.md`

```markdown
## Bonus: History Rewrite

### Before
```
<paste output of: git log --oneline before rewrite>
```
Output of `git log -p | grep -c 'ghp_'`: **2**

### After
```
<paste output of: git log --oneline after rewrite>
```
Output of `git log -p | grep -c 'ghp_'`: **0**
Output of `git log -p | grep -c 'REDACTED'`: **2**

### The two-step pattern in real life
1. `git filter-repo --replace-text replacements.txt` — rewrite locally
2. **<answer here>** — what's the MANDATORY second step in a real incident?
   (Hint: Lecture 3 slide 12 has this — it's the difference between cleanup and remediation.)

### Two real-world gotchas you discovered (2 sentences each)
1. <something the lab actually surprised you with — e.g., "filter-repo refused to run because there were existing remotes; I had to remove origin">
2. <another>
```

> ⚠️ **Do NOT commit `/tmp/lab3-bonus`** to your course fork. The bonus is on a sandbox repo; the submission paste-in is the evidence.

---

## How to Submit

```bash
git add submissions/lab3.2.md
git commit -m "feat(lab3.2): gitleaks tune-out + history rewrite practice"
# This commit must be signed — verify with: git log --show-signature -1
git push -u origin feature/lab3.2
```

PR checklist body:

```text
- [ ] Task 2 (continued) — tune-out exercise answered
- [ ] Bonus — filter-repo rewrite practice documented
```

---

## Acceptance Criteria

### Task 2 — Tune-out (part of Lab 3.1 Task 2 grading)
- ✅ Tune-out exercise answered for both inline allowlist AND path exclusion

### Bonus Task (2 pts)
- ✅ Submission shows before/after `git log -p | grep -c` outputs (2 → 0)
- ✅ The MANDATORY second step is correctly identified (it's **rotation**, not just rewrite)
- ✅ Two genuine gotchas the student hit during their dry-run (not generic — must be specific)

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Bonus Task** — History rewrite | **2** | Before/after greps + correct mandatory-second-step + 2 specific gotchas |
| **Total** | **2** | bonus points |

---
