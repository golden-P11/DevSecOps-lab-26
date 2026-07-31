# Lab 3.1 — Secure Git: SSH Signing & Secret Scanning

![difficulty](https://img.shields.io/badge/difficulty-beginner-success)
![topic](https://img.shields.io/badge/topic-Secure%20Git-blue)
![points](https://img.shields.io/badge/points-10-orange)
![tech](https://img.shields.io/badge/tech-Git%20%2B%20gitleaks-informational)

> **Goal:** Configure SSH commit signing and wire gitleaks into a pre-commit hook.
> **Deliverable:** A PR from `feature/lab3.1` with `submissions/lab3.1.md` plus `.pre-commit-config.yaml`. Submit PR link via Moodle.

---

## Overview

In this lab you will practice:
- **SSH commit signing** (Git ≥ 2.34, GitHub verification since Aug 2022) — the STRIDE-R control from Lecture 2
- **Pre-commit hooks** + **gitleaks** — catching secrets before they leave your laptop

> Don't skim this lab. The 5-year Toyota leak  was prevented by exactly the controls you'll wire up today.

---

## Project State

**You should have from Labs 1-2:**
- A fork of the course repo + working `feature/labN` PR workflow
- The PR template auto-filling
- A threat model surfacing STRIDE-R (Repudiation) as one of the risks Threagile flagged

**This lab adds:**
- Every future commit on your fork will be cryptographically signed and show "Verified" on GitHub
- A pre-commit hook that blocks accidental secret commits

---

## Setup

You need:
- **Git ≥ 2.34** (`git --version` — needed for native SSH signing)
- **An SSH key** — follow the steps below if you don't have one yet
- **`gitleaks`** CLI — follow the steps below (course pins **gitleaks v8.x**; on macOS you can also use `brew install gitleaks`)
- **`pre-commit`** framework (`sudo apt install pre-commit` or `pipx install pre-commit`)

### SSH key setup

#### Part 1 — Generate a key pair

`ed25519` is a modern elliptic-curve **signing algorithm** recommended for SSH keys (smaller and faster than RSA).

```bash
ssh-keygen -t ed25519
```

When prompted:
- **Enter file in which to save the key** — press **Enter** to accept the default path (`~/.ssh/id_ed25519`).
- **Enter passphrase** — press **Enter** for no passphrase, or type a passphrase to encrypt the private key (you'll be asked to confirm it).

#### Part 2 — Verify the key pair was created

```bash
ls ~/.ssh/id_*
```

You should see **two files**: `id_ed25519` (private key — keep secret) and `id_ed25519.pub` (public key — safe to share).

### Gitleaks setup

The latest release on [GitHub](https://github.com/gitleaks/gitleaks/releases) is **v8.30.1** — use that version or any other **v8.x** tag.

#### Part 1 — Download and install

```bash
cd /tmp

curl -LO https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz

tar -xzf gitleaks_8.30.1_linux_x64.tar.gz

sudo mv gitleaks /usr/local/bin/

sudo chmod +x /usr/local/bin/gitleaks
```

#### Part 2 — Verify the installation

```bash
gitleaks version
```

Expected output:

```
8.30.1
```

```bash
# Branch off main
git switch main && git pull
git switch -c feature/lab3.1

# Install pre-commit (Python tool, works for any repo type)
sudo apt install pre-commit          # or: pipx install pre-commit
pre-commit --version
```

---

## Task 1 — SSH Commit Signing (6 pts)

**Objective:** Configure your Git client to sign every commit with your SSH key, upload the public key to GitHub as a **Signing Key**, and demonstrate verification works locally and on GitHub.

### 3.1: Configure local signing

```bash
# Tell Git to use SSH (not GPG) for signing
git config --global gpg.format ssh
#check SSH configured, the result shouble be "ssh"
git config --global gpg.format

# Point to your public key
git config --global user.signingkey ~/.ssh/id_ed25519.pub
#Check
git config --global user.signingkey


# Sign every commit + tag by default
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Set up local verification (so `git log --show-signature` works offline)
mkdir -p ~/.config/git
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers

# Add yourself to the allowed signers file
echo "$(git config --global user.email) namespaces=\"git\" $(cat ~/.ssh/id_ed25519.pub)" \
  >> ~/.config/git/allowed_signers

#check
cat ~/.config/git/allowed_signers
```

### 3.2: Upload the public key to GitHub as a Signing Key

1. Go to **GitHub → Settings → SSH and GPG keys → New SSH key**
2. **Key type: Signing Key** (this is the trap — if you only have it under "Authentication Key", commits show as Unverified)
3. Paste `cat ~/.ssh/id_ed25519.pub` output

> **The same key bytes can be uploaded under both roles** (Authentication + Signing). If you already use the key for `git push`, you still need to add it again under Signing.

### 3.3: Test signing

```bash
# Make a signed commit
echo "lab3 signing test" > submissions/lab3.1.md
git add submissions/lab3.1.md
git commit -m "test: first signed commit"

# Verify locally
git log --show-signature -1
# Should see: "Good \"git\" signature for <your-email>"
```

Push the branch and verify on GitHub:

```bash
git push -u origin feature/lab3.1
```

Open your fork on GitHub (branch feature) → Commits tab → your commit should show a green **Verified** badge.

### 3.4: Document in `submissions/lab3.1.md`

```markdown
# Lab 3.1 — Submission

## Task 1: SSH Commit Signing

### Local configuration
- `git config --global gpg.format` → <output>
- `git config --global user.signingkey` → <output>
- `git config --global commit.gpgsign` → <output>

### Local verification
Output of `git log --show-signature -1`:
```
<paste — should include "Good \"git\" signature for <email>">
```

### GitHub verification
- Direct link to your most recent commit on GitHub: <URL>
- Screenshot of the Verified badge: <inline image OR link to image file in PR>

### One-paragraph reflection (2-3 sentences)
What STRIDE-R (Repudiation) scenario would a forged-author commit enable in a real
team's codebase? How does the Verified badge make that attack visible?
```

---

## Task 2 — Pre-commit + gitleaks (4 pts)

> ⏭️ Optional. Skipping won't affect future labs. But this is the control that prevented Toyota's 5-year T-Connect key leak — worth getting right.

**Objective:** Install the `pre-commit` framework, wire `gitleaks` into it, prove it catches a planted secret, and document the tune-out workflow.

### 3.5: Create the pre-commit config

```bash
# YOUR TASK: create .pre-commit-config.yaml at repo root
```

Required content (see [pre-commit docs](https://pre-commit.com/) for syntax):
- Repo: `https://github.com/gitleaks/gitleaks`
- Rev: a real **v8.x** release tag (check [gitleaks releases](https://github.com/gitleaks/gitleaks/releases) for the latest)
- Hook id: `gitleaks`
- At least one additional hook from `pre-commit/pre-commit-hooks` — recommended: `detect-private-key` and `check-added-large-files`

### 3.6: Install the hook in your local repo

```bash
pre-commit install
# Should print: "pre-commit installed at .git/hooks/pre-commit"

#create nano .pre-commit-config.yaml
nano .pre-commit-config.yaml
#Paste the following content to the file:
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.28.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: detect-private-key
      - id: check-added-large-files

# Sanity check: run all hooks on every file once
pre-commit run --all-files
```

### 3.7: Plant a fake secret and observe the block

```bash
# Create a file with a fake-but-realistic GH PAT
# (AKIAIOSFODNN7EXAMPLE / wJalr... are gitleaks-allowlisted as canonical example values;
#  using a GitHub-PAT-style string actually triggers the gitleaks v8 detector)
cat > /tmp/leak-test.txt <<EOF
# This is a deliberate fake secret for Lab 3 testing
GH_PAT=ghp_16C7e42F292c6912E7710c838347Ae178B4a
EOF
cp /tmp/leak-test.txt submissions/leak-attempt.txt
git add submissions/leak-attempt.txt
git commit -m "test: should be blocked by gitleaks"
# Should ABORT with gitleaks reporting the AWS-key pattern
```

Then **unstage** the test file — don't commit the planted secret even with `--no-verify`:

```bash
git restore --staged submissions/leak-attempt.txt
rm submissions/leak-attempt.txt /tmp/leak-test.txt
```

### 3.8: Document in `submissions/lab3.1.md`

```markdown
## Task 2: Pre-commit + gitleaks

### `.pre-commit-config.yaml` (paste the full content)
```
<paste your YAML>
```

### `pre-commit install` output
```
<paste — should say "pre-commit installed at .git/hooks/pre-commit">
```

### The blocked commit
Output of the `git commit` that gitleaks blocked (the failing hook output):
```
<paste the error block — gitleaks usually shows the rule ID + redacted finding>
```
```

---

## How to Submit

```bash
git add .pre-commit-config.yaml          # Task 2
git add submissions/lab3.1.md
git commit -m "feat(lab3.1): SSH signing + gitleaks pre-commit"
# This commit must be signed — verify with: git log --show-signature -1
git push -u origin feature/lab3.1
```

PR checklist body:

```text
- [x] Task 1 — SSH signing configured + Verified badge on commit
- [ ] Task 2 — .pre-commit-config.yaml + gitleaks demonstrably blocking
```

---

## Acceptance Criteria

### Task 1 (6 pts)
- ✅ `git config --global gpg.format` returns `ssh`
- ✅ `git log --show-signature -1` shows "Good \"git\" signature"
- ✅ On the submitted PR, **every commit by the student** shows the green Verified badge on GitHub
- ✅ Submission includes screenshot/link of Verified badge + STRIDE-R reflection (2-3 sentences, substantive)

### Task 2 (4 pts)
- ✅ `.pre-commit-config.yaml` exists with gitleaks (v8.x tag) + at least one other hook
- ✅ Submission includes actual gitleaks-blocked commit output (rule ID + redacted finding visible)

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — SSH signing | **6** | Local + GitHub verification both working + STRIDE-R reflection |
| **Task 2** — Pre-commit + gitleaks | **4** | Config + install + blocked-commit evidence |
| **Total** | **10** | |

---
