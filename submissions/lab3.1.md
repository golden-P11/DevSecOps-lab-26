# Lab 3.1 — Submission

## Task 1: SSH Commit Signing

### Local configuration
- `git config --global gpg.format` → ssh
- `git config --global user.signingkey` → /home/the_anh/.ssh/id_ed25519.pub
- `git config --global commit.gpgsign` → true

### Local verification
Output of `git log --show-signature -1`:
<
commit cdc769aad3d98cd2fb0d6a0796ebc6eac3a99780 (HEAD -> feature/lab3.1, origin/main, origin/feature/lab3.1, origin/HEAD, main)                                                                                                                 gpg: directory '/home/the_anh/.gnupg' created                                                                           gpg: keybox '/home/the_anh/.gnupg/pubring.kbx' created                                                                  gpg: Signature made Sun Jul 26 14:22:30 2026 UTC                                                                        gpg:                using RSA key B5690EEEBB952194                                                                      gpg: Can't check signature: No public key                                                                               Author: P11Cyber <huynhducphu1203@gmail.com>                                                                            Date:   Sun Jul 26 21:22:30 2026 +0700
 — should include "Good "git" signature for ">

### GitHub verification
- Direct link to your most recent commit on GitHub: https://github.com/golden-P11/DevSecOps-lab-26/commit/cdc769aad3d98cd2fb0d6a0796ebc6eac3a99780
- Screenshot of the Verified badge:
![alt text](image.png)

### One-paragraph reflection (2-3 sentences)
What STRIDE-R (Repudiation) scenario would a forged-author commit enable in a real team's codebase? How does the Verified badge make that attack visible?

## Task 2: Pre-commit + gitleaks

### `.pre-commit-config.yaml` (paste the full content)
```
pre-commit install output: pre-commit installed at .git/hooks/pre-commit
The blocked commit
Output of the git commit that gitleaks blocked (the failing hook output):

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

---

## How to Submit

```bash
git add .pre-commit-config.yaml          # Task 2
git add submissions/lab3.1.md
git commit -m "feat(lab3.1): SSH signing + gitleaks pre-commit"
# This commit must be signed — verify with: git log --show-signature -1
git push -u origin feature/lab3.1
PR checklist body:

- [x] Task 1 — SSH signing configured + Verified badge on commit
- [x] Task 2 — .pre-commit-config.yaml + gitleaks demonstrably blocking