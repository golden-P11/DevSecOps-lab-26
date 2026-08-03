# Lab 3.1 — Submission

## Task 1: SSH Commit Signing

### Local configuration

- `git config --global gpg.format` → ssh
- `git config --global user.signingkey` → /home/the_anh/.ssh/id_ed25519.pub
- `git config --global commit.gpgsign` → true

### Local verification

Output of `git log --show-signature -1`:

```text
Good "git" signature with ED25519 key SHA256:aibHGAtkOR8....
Merge: 14d8b83 b781b65
Author: theanh1709 <vu.theanh1709@gmail.com>
Date:   Sat Aug 1 05:27:03 2026 +0000
```

### GitHub verification

- Direct link to your most recent commit on GitHub: 
    `https://github.com/theanh1709/DevSecOps-Intro/commit/711818f74230f7839e5cc79c639699a308071447`
- Screenshot of the Verified badge:
    ![alt text](image.png)

### Reflection

What STRIDE-R (Repudiation) scenario would a forged-author commit enable in a real team's codebase? How does the Verified badge make that attack visible?

```text
- A forged-author commit lets an attacker inject malicious changes while posing as a trusted developer, breaking non‑repudiation.
- The green "Verified" badge provides cryptographic proof of the signing key

```

## Task 2: Pre-commit + gitleaks

### `.pre-commit-config.yaml` (paste the full content)

pre-commit install output: pre-commit installed at .git/hooks/pre-commit

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: detect-private-key
      - id: check-added-large-files
```

`pre-commit install` output

```text
pre-commit installed at .git/hooks/pre-commit
```

### Blocked Commit Output

Output of the git commit that gitleaks blocked (the failing hook output):

```json
[
 {
  "RuleID": "github-pat",
  "Description": "Uncovered a GitHub Personal Access Token, potentially leading to unauthorized repository access and sensitive content exposure.",
  "StartLine": 1,
  "EndLine": 1,
  "File": "submissions/leak-attempt.txt",
  "SymlinkFile": "",
  "Commit": "",
  "Entropy": 4.143943,
  "Author": "",
  "Email": "",
  "Date": "",
  "Message": "",
  "Tags": [],
  "Fingerprint": "submissions/leak-attempt.txt:github-pat:1"
 }
]
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

```text
PR checklist body:

- [x] Task 1 — SSH signing configured + Verified badge on commit
- [x] Task 2 — .pre-commit-config.yaml + gitleaks demonstrably blocking
```
