# Lab 8.1 — Local Registry + Cosign Sign + Tamper Demo

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Supply%20Chain-blue)
![points](https://img.shields.io/badge/points-6-orange)
![tech](https://img.shields.io/badge/tech-Cosign%20%2B%20Sigstore-informational)

> **Goal:** Run a local OCI registry, push Juice Shop into it, sign the image digest with Cosign, and demonstrate that re-tagging a different image breaks the signature.
> **Deliverable:** A PR from `feature/lab8.1` with `labs/lab8/keys/cosign.pub` and `submissions/lab8.1.md`. Submit PR link via Moodle.

> **Part of Lab 8:** This is the first part of Lab 8. Complete **[Lab 8.2](lab8.2.md)** (SBOM + provenance attestations) and **[Lab 8.3](lab8.3.md)** (blob signing + CI) separately.

---

## Overview

In this lab you will practice:
- **Local Distribution v3 registry** — running your own OCI registry
- **Cosign v3.x** — keyed signing of an image digest + tamper demonstration

> Recall Lecture 8 slide 1 — xz-utils 2024 narrowly missed shipping a backdoor to millions of sshd daemons. The signing + attestation pattern you build today is the discipline (not silver bullet) that supply-chain attacks bypass when absent.

---

## Project State

**You should have from Labs 1, 4, 7:**
- Juice Shop v20.0.0 image (Lab 1)
- `labs/lab4/juice-shop.cdx.json` — CycloneDX SBOM (Lab 4 Task 1)
- Trivy image scan output (Lab 7 Task 1)

**This lab adds:**
- A local registry holding the image
- A Cosign keypair + signature + saved verification output

---

## Setup

You need:
- **Docker**
- **Cosign v3.x** — `brew install cosign` or [GitHub releases](https://github.com/sigstore/cosign/releases) (course pins v2.4.x as of April 2026)
- **`jq`**

```bash
git switch main && git pull
git switch -c feature/lab8.1

cosign version    # Should print 2.x.x
docker --version

mkdir -p labs/lab8/keys labs/lab8/results
```

---

## Task 1 — Local Registry + Cosign Sign + Tamper Demo (6 pts)

**Objective:** Run a local OCI registry, push Juice Shop into it, sign with Cosign, and demonstrate that re-tagging breaks the signature.

### 8.1.1: Start the local registry + push Juice Shop

```bash
# Distribution v3 — the modern reference registry (replaces v2)
docker run -d --name lab8-registry \
  -p 127.0.0.1:5000:5000 \
  registry:3

# Pull Juice Shop (if not already present)
docker pull bkimminich/juice-shop:v20.0.0

# Tag and push to local registry
docker tag bkimminich/juice-shop:v20.0.0 localhost:5000/juice-shop:v20.0.0
docker push localhost:5000/juice-shop:v20.0.0

# Capture the registry digest — you'll sign this, not the tag
docker inspect localhost:5000/juice-shop:v20.0.0 \
  --format '{{index .RepoDigests 0}}' > labs/lab8/results/juice-shop-digest.txt
cat labs/lab8/results/juice-shop-digest.txt
# Should be: localhost:5000/juice-shop@sha256:abc... (KEEP THIS — used in every step)
```

### 8.1.2: Generate a Cosign keypair

```bash
cd labs/lab8/keys
cosign generate-key-pair    # Will prompt for a passphrase; use something memorable
cd -

# Verify both files exist
ls labs/lab8/keys/
# Should show: cosign.key (private — DO NOT COMMIT) and cosign.pub
```

> **The `cosign.key` is a private key. Your pre-commit hook (Lab 3 gitleaks) should refuse to commit it.** Test this — try `git add labs/lab8/keys/cosign.key` and watch gitleaks block the commit.

### 8.1.3: Sign the image (digest, not tag)

```bash
# Read the digest captured above
DIGEST=$(cat labs/lab8/results/juice-shop-digest.txt)
echo "Signing: $DIGEST"

# Sign with your private key
COSIGN_PASSWORD="<your-passphrase>" cosign sign \
  --key labs/lab8/keys/cosign.key \
  --yes \
  "$DIGEST"

# Verify
cosign verify \
  --key labs/lab8/keys/cosign.pub \
  --insecure-ignore-tlog \
  "$DIGEST" | tee labs/lab8/results/verify-original.json
# Should print verification claims; exit 0
```

> **Why `--insecure-ignore-tlog`?** We're not pushing to the public Rekor transparency log for this lab (no upstream identity for the local registry). For real keyless signing in CI (Lecture 8 slide 7), Rekor handles this automatically.

### 8.1.4: Tamper demonstration

```bash
# Pull a different image
docker pull alpine:3.20
# Re-tag it to LOOK like Juice Shop
docker tag alpine:3.20 localhost:5000/juice-shop:v20.0.0-tampered

# Push under the same name
docker push localhost:5000/juice-shop:v20.0.0-tampered

# Re-resolve digest — it's DIFFERENT (alpine is not juice-shop)
docker inspect localhost:5000/juice-shop:v20.0.0-tampered \
  --format '{{index .RepoDigests 0}}'
# Should be a different sha256:...

# Verify the tampered image — should FAIL
cosign verify \
  --key labs/lab8/keys/cosign.pub \
  --insecure-ignore-tlog \
  "localhost:5000/juice-shop@$(docker inspect localhost:5000/juice-shop:v20.0.0-tampered --format '{{index .RepoDigests 0}}' | cut -d@ -f2)" \
  > labs/lab8/results/verify-tampered.txt 2>&1 || true

# The verify-tampered.txt should contain "no matching signatures" or similar
cat labs/lab8/results/verify-tampered.txt
```

### 8.1.5: Sanity — original still works

```bash
# Original digest still verifies
cosign verify \
  --key labs/lab8/keys/cosign.pub \
  --insecure-ignore-tlog \
  "$DIGEST"
# Should succeed — the signature is digest-bound, not tag-bound
```

### 8.1.6: Document in `submissions/lab8.1.md`

````markdown
# Lab 8.1 — Submission

## Task 1: Sign + Tamper Demo

### Registry + image push
- Registry container: `lab8-registry` running on `localhost:5000`
- Image pushed: `localhost:5000/juice-shop:v20.0.0`
- Image digest: <paste contents of labs/lab8/results/juice-shop-digest.txt>

### Signing
- Output of `cosign sign` (just the success line is fine):
```
<paste>
```

### Verification (PASSED)
Output of `cosign verify` on original digest:
```json
<paste labs/lab8/results/verify-original.json>
```

### Tamper Demo (FAILED — correctly)
Output of `cosign verify` on tampered digest:
```
<paste labs/lab8/results/verify-tampered.txt — must contain "no matching signatures">
```

### Sanity — original still verifies
```
<paste the second cosign verify success>
```

### Why digest binding matters (Lecture 8 slide 6)
2-3 sentences. The tampered re-tag pointed to a DIFFERENT digest; your signature was bound to the
ORIGINAL digest. What would have broken if Cosign had signed the tag instead?
````

---

## How to Submit

```bash
git add labs/lab8/keys/cosign.pub          # PUBLIC key OK to commit (private key is gitignored)
git add submissions/lab8.1.md
git commit -m "feat(lab8.1): cosign sign + tamper demo"
git push -u origin feature/lab8.1

# Cleanup
docker stop lab8-registry && docker rm lab8-registry
```

> **CRITICAL: NEVER commit `labs/lab8/keys/cosign.key`** — gitleaks should already block it. Verify your `.gitignore` excludes `*.key` patterns.

PR checklist body:

```text
- [x] Task 1 — Image signed + tamper demo (both shown)
```

---

## Acceptance Criteria

### Task 1 (6 pts)
- ✅ Local registry running; Juice Shop pushed with a captured registry digest
- ✅ `cosign verify` succeeds on original digest; output saved in submission
- ✅ `cosign verify` fails on tampered (re-tagged) image; output saved
- ✅ Original digest still verifies after the tamper attempt (defense-in-depth proof)
- ✅ "Why digest binding matters" answer demonstrates understanding of tag-mutation attack

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — Sign + Tamper | **6** | Registry + signed image + verify pass + tamper fail + sanity recheck + digest-binding explanation |
| **Total** | **6** | |

---
