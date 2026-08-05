# Lab 5.1 — Submission

## Task 1: SAST with Semgrep

### Semgrep severity breakdown

| Severity | Count |
|----------|------:|
| ERROR | <13> |
| WARNING | <14> |
| INFO | <0> |
| **Total** | <27> |

### Top 10 rules by frequency

| Rule ID | Count | OWASP category |
|---------|------:|----------------|
| javascript.sequelize.security.audit.sequelize-injection-express.express-sequelize-injection | 6 | A03 Injection |
| yaml.github-actions.security.run-shell-injection.run-shell-injection | 5 | A03 Injection |
| javascript.express.security.audit.express-check-directory-listing.express-check-directory-listing | 4 | A05 Security Misconfiguration |
| yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag | 4 | A05 Security Misconfiguration |
| javascript.express.security.audit.express-res-sendfile.express-res-sendfile | 4 | A05 Security Misconfiguration |
| javascript.express.security.audit.express-open-redirect.express-open-redirect | 1 | A05 Security Misconfiguration |
| javascript.jsonwebtoken.security.jwt-hardcode.hardcoded-jwt-secret | 1 | A02 Cryptographic Failures |
| yaml.github-actions.security.gha-curl-pipe-shell.gha-curl-pipe-shell | 1 | A05 Security Misconfiguration |
| javascript.lang.security.audit.code-string-concat.code-string-concat | 1 | A03 Injection |

### Triage shortcut (Lecture 5 slide 8)

Looking at the top 10 — which **one rule** would you fix first if you had time for only one?
Why? (2-3 sentences. Likely answer: the highest-frequency rule that's not a duplicate
of patterns the team already knows about; one fix at the module level closes many findings.)

```text
Fix `javascript.sequelize.security.audit.sequelize-injection-express.express-sequelize-injection` first. 
It's the highest-frequency finding (6 occurrences), 
Fixing the underlying query construction pattern will be resolved multiple SQL injection risks.
```

### False-positive sample

Pick **one** finding you'd suppress as a false positive after review. Quote the file path +
rule + 1-sentence reason. (NOT generic — must reference the specific code.)

`labs/lab5/semgrep/juice-shop/routes/userProfile.ts` — `javascript.lang.security.audit.code-string-concat.code-string-concat`

```text
This finding flags `new Error('Blocked illegal activity by ' + req.socket.remoteAddress)` as string concatenation, but the code is only building an error message from socket metadata rather than constructing executable code or rendering unsafe user input.
```

---

## Cleanup (after submitting)

```bash
rm -rf labs/lab5/semgrep/juice-shop      # 200MB; keep if you'll re-run; delete to save space
```

---

## How to Submit

```bash
git add submissions/lab5-1.md
git commit -m "feat(lab5-1): Semgrep SAST analysis"
git push -u origin feature/lab5-1
```

> **Do NOT commit** `labs/lab5/results/` (scanner outputs are large and regeneratable) or `labs/lab5/semgrep/juice-shop/` (200MB clone). The submission paste-in is the evidence.

PR checklist body:

```text
- [ ] Task 1 — Semgrep severity breakdown + top-10 rules + triage shortcut + false-positive sample
```
