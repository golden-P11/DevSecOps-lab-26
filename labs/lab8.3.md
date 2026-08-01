# Lab 8.3 — Blob Signing + Supply Chain CI

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Supply%20Chain-blue)
![points](https://img.shields.io/badge/points-2%2B4-orange)
![tech](https://img.shields.io/badge/tech-Cosign%20%2B%20GitHub%20Actions-informational)

> **Goal:** Sign a release tarball with `cosign sign-blob` (Codecov 2021 mitigation pattern), then automate Cosign sign + attest + blob-verify in a GitHub Actions workflow.
> **Deliverable:** A PR from `feature/lab8.3` with `.github/workflows/lab8-supply-chain-security.yml` and `submissions/lab8.3.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 8.1](lab8.1.md) recommended — you should understand Cosign keyed signing before automating it in CI. Lab 4 SBOM (`labs/lab4/juice-shop.cdx.json`) must exist for the attestation job to pass.

> **Part of Lab 8:** This is the blob signing + CI half of Lab 8. Complete **[Lab 8.1](lab8.1.md)** and **[Lab 8.2](lab8.2.md)** separately.

---

## Overview

In this lab you will practice:
- **`cosign sign-blob`** — what would have stopped the Codecov 2021 attack
- **CI automation** — Cosign image sign/verify, SBOM + provenance attestation, and blob signing on every push and pull request

Reference workflow: [`.github/workflows/lab8-supply-chain-security.yml`](../.github/workflows/lab8-supply-chain-security.yml)

---

## Project State

**You should have from Lab 8.1:**
- Cosign keypair at `labs/lab8/keys/` (for local blob signing)
- Familiarity with digest-bound signing and tamper demos

**You should have from Lab 4:**
- `labs/lab4/juice-shop.cdx.json` — required by the CI attestation job

**This lab adds:**
- Local blob signing + tamper verification
- A reusable supply-chain CI pipeline on GitHub-hosted runners

---

## Setup

You need:
- **Cosign v3.x** (local blob signing)
- A fork of the course repo with **Actions enabled** (GitHub → Settings → Actions → General → Allow all actions)

```bash
git switch main && git pull
git switch -c feature/lab8.3

cosign version
mkdir -p labs/lab8/results
```

---

## Bonus Task — Blob Signing (Codecov 2021 Mitigation) (2 pts)

> 🌟 **Practical & directly maps to a real incident.** The Codecov bash uploader was distributed via `curl | bash` without verification. `cosign sign-blob` is the API that would have stopped it.

**Objective:** Sign a tarball with `cosign sign-blob`, distribute the signature alongside it, and verify on a fresh download.

### 8.3.1: Make a "release" artifact

```bash
# Pretend this is your release script
cat > /tmp/install.sh <<'EOF'
#!/bin/bash
echo "Welcome to my-cool-tool installer"
echo "Running setup..."
EOF
chmod +x /tmp/install.sh

# Tar + gzip it
tar -czf labs/lab8/results/my-tool.tar.gz -C /tmp install.sh
```

### 8.3.2: Sign the blob

```bash
# Sign — produces a .sig file and a .pem certificate (for keyless) or just .sig (for keyed)
cosign sign-blob \
  --key labs/lab8/keys/cosign.key \
  --yes \
  --bundle labs/lab8/results/my-tool.tar.gz.bundle \
  labs/lab8/results/my-tool.tar.gz

# Show what was produced
ls labs/lab8/results/my-tool.tar.gz*
```

### 8.3.3: Distribute + verify (simulating a fresh download)

```bash
# Copy to a "fresh" directory as if downloaded
mkdir -p /tmp/fresh-download
cp labs/lab8/results/my-tool.tar.gz \
   labs/lab8/results/my-tool.tar.gz.bundle \
   labs/lab8/keys/cosign.pub \
   /tmp/fresh-download/

cd /tmp/fresh-download/

# Verify
cosign verify-blob \
  --key cosign.pub \
  --bundle my-tool.tar.gz.bundle \
  --insecure-ignore-tlog \
  my-tool.tar.gz
# Should print "Verified OK" and exit 0
cd -
```

### 8.3.4: Tamper test for the blob

```bash
# Modify the blob (simulating an attacker re-distributing a malicious version)
cp labs/lab8/results/my-tool.tar.gz /tmp/fresh-download/my-tool.tar.gz
echo "MALICIOUS PAYLOAD" >> /tmp/fresh-download/my-tool.tar.gz

cd /tmp/fresh-download/
cosign verify-blob \
  --key cosign.pub \
  --bundle my-tool.tar.gz.bundle \
  --insecure-ignore-tlog \
  my-tool.tar.gz 2>&1 | tee /tmp/blob-tamper.txt || true
# Should FAIL — signature was bound to the original byte stream
cd -

cat /tmp/blob-tamper.txt    # paste this into submission
```

### 8.3.5: Document in `submissions/lab8.3.md`

````markdown
# Lab 8.3 — Submission

## Bonus: Blob Signing (Codecov 2021 mitigation)

### Sign + verify
- Signed: `my-tool.tar.gz` + `my-tool.tar.gz.bundle`
- Verify-blob success output:
```
<paste — must include "Verified OK">
```

### Tamper test failed (correctly)
```
<paste /tmp/blob-tamper.txt — must show "Error: ..." or "signature was invalid">
```

### Codecov 2021 mitigation (2-3 sentences)
Codecov's bash uploader was distributed via `curl | bash` without signature verification.
If their CI consumers had been running `cosign verify-blob` before `bash`-ing the script,
how would the attack have failed? Reference Lecture 8 slide 14 + the specific cosign command
that would have caught it.
````

---

## Task 3 — GitHub Actions: Supply Chain Security Pipeline (4 pts)

**Objective:** Copy the reference workflow into your fork, push it, trigger a run, and document what each job and step does.

> **Green status requirement:** This pipeline is designed to **pass with green status** when `labs/lab4/juice-shop.cdx.json` is present in your fork. Each job uses an **ephemeral Cosign keypair** generated on the runner (CI demo keys — not your Lab 8.1 local keys). All three jobs must complete successfully.

### 8.3.6: Create the workflow file

Create the directory and file:

```bash
mkdir -p .github/workflows
nano .github/workflows/lab8-supply-chain-security.yml
```

Paste the following content (matches the [course reference workflow](../.github/workflows/lab8-supply-chain-security.yml)):

```yaml
name: lab8-Supply Chain Security

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  actions: write

env:
  IMAGE: bkimminich/juice-shop:v20.0.0
  LOCAL_IMAGE: localhost:5000/juice-shop:v20.0.0
  RESULTS_DIR: labs/lab8/results
  COSIGN_PASSWORD: ci-lab8-passphrase

jobs:
  cosign-sign-verify:
    name: Cosign — Sign + Verify Image
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.7.0
        with:
          cosign-release: v2.4.1

      - name: Start local registry
        run: |
          docker run -d --name lab8-registry \
            -p 127.0.0.1:5000:5000 \
            registry:2
          sleep 3

      - name: Push Juice Shop to local registry
        run: |
          mkdir -p "${RESULTS_DIR}"
          docker pull "${IMAGE}"
          docker tag "${IMAGE}" "${LOCAL_IMAGE}"
          docker push "${LOCAL_IMAGE}"
          docker inspect "${LOCAL_IMAGE}" \
            --format '{{index .RepoDigests 0}}' > "${RESULTS_DIR}/juice-shop-digest.txt"
          cat "${RESULTS_DIR}/juice-shop-digest.txt"

      - name: Generate ephemeral Cosign keypair
        run: cosign generate-key-pair

      - name: Sign and verify image digest
        run: |
          DIGEST=$(cat "${RESULTS_DIR}/juice-shop-digest.txt")
          cosign sign \
            --key cosign.key \
            --yes \
            --allow-insecure-registry \
            "${DIGEST}"
          cosign verify \
            --key cosign.pub \
            --insecure-ignore-tlog \
            --allow-insecure-registry \
            "${DIGEST}"

      - name: Upload sign-verify artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab8-cosign-sign-verify
          path: |
            ${{ env.RESULTS_DIR }}/juice-shop-digest.txt
            cosign.pub
          if-no-files-found: warn
          retention-days: 30

  sbom-provenance-attest:
    name: Cosign — SBOM + Provenance Attestation
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.7.0
        with:
          cosign-release: v2.4.1

      - name: Start local registry
        run: |
          docker run -d --name lab8-registry \
            -p 127.0.0.1:5000:5000 \
            registry:2
          sleep 3

      - name: Push Juice Shop to local registry
        run: |
          mkdir -p "${RESULTS_DIR}"
          docker pull "${IMAGE}"
          docker tag "${IMAGE}" "${LOCAL_IMAGE}"
          docker push "${LOCAL_IMAGE}"
          docker inspect "${LOCAL_IMAGE}" \
            --format '{{index .RepoDigests 0}}' > "${RESULTS_DIR}/juice-shop-digest.txt"

      - name: Generate ephemeral Cosign keypair
        run: cosign generate-key-pair

      - name: Attach CycloneDX SBOM attestation
        run: |
          DIGEST=$(cat "${RESULTS_DIR}/juice-shop-digest.txt")
          cosign attest \
            --key cosign.key \
            --type cyclonedx \
            --predicate labs/lab4/juice-shop.cdx.json \
            --allow-insecure-registry \
            --yes \
            "${DIGEST}"
          cosign verify-attestation \
            --key cosign.pub \
            --insecure-ignore-tlog \
            --type cyclonedx \
            --allow-insecure-registry \
            "${DIGEST}" | jq -r '.payload | @base64d | fromjson | .predicate' \
            > "${RESULTS_DIR}/sbom-from-attestation.json"

      - name: Attach SLSA provenance attestation
        run: |
          DIGEST=$(cat "${RESULTS_DIR}/juice-shop-digest.txt")
          jq -n \
            --arg repo "${{ github.repository }}" \
            --arg sha "${{ github.sha }}" \
            '{
              builder: { id: ("https://github.com/" + $repo + "/actions") },
              buildType: "https://example.com/lab8/ci-build",
              invocation: {
                configSource: {
                  uri: ("https://github.com/" + $repo),
                  digest: { sha1: $sha }
                }
              }
            }' > /tmp/predicate-only.json
          cosign attest \
            --key cosign.key \
            --type slsaprovenance \
            --predicate /tmp/predicate-only.json \
            --tlog-upload=false \
            --allow-insecure-registry \
            --yes \
            "${DIGEST}"
          cosign verify-attestation \
            --key cosign.pub \
            --insecure-ignore-tlog \
            --type slsaprovenance \
            --allow-insecure-registry \
            "${DIGEST}" > "${RESULTS_DIR}/provenance-verify.json"

      - name: Upload attestation artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab8-sbom-provenance-attest
          path: ${{ env.RESULTS_DIR }}/
          if-no-files-found: warn
          retention-days: 30

  blob-sign-verify:
    name: Cosign — Blob Sign + Verify
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.7.0
        with:
          cosign-release: v2.4.1

      - name: Create release artifact
        run: |
          mkdir -p "${RESULTS_DIR}"
          cat > /tmp/install.sh <<'EOF'
          #!/bin/bash
          echo "Welcome to my-cool-tool installer"
          echo "Running setup..."
          EOF
          chmod +x /tmp/install.sh
          tar -czf "${RESULTS_DIR}/my-tool.tar.gz" -C /tmp install.sh

      - name: Generate ephemeral Cosign keypair
        run: cosign generate-key-pair

      - name: Sign and verify blob
        run: |
          cosign sign-blob \
            --key cosign.key \
            --yes \
            --bundle "${RESULTS_DIR}/my-tool.tar.gz.bundle" \
            "${RESULTS_DIR}/my-tool.tar.gz"
          cosign verify-blob \
            --key cosign.pub \
            --bundle "${RESULTS_DIR}/my-tool.tar.gz.bundle" \
            --insecure-ignore-tlog \
            "${RESULTS_DIR}/my-tool.tar.gz"

      - name: Upload blob signing artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab8-blob-sign-verify
          path: |
            ${{ env.RESULTS_DIR }}/my-tool.tar.gz
            ${{ env.RESULTS_DIR }}/my-tool.tar.gz.bundle
            cosign.pub
          if-no-files-found: warn
          retention-days: 30
```

Commit and push:

```bash
git add .github/workflows/lab8-supply-chain-security.yml
git commit -m "feat(lab8.3): supply chain security CI workflow"
git push -u origin feature/lab8.3
```

### 8.3.7: Trigger and verify the workflow

The workflow runs automatically when you:
- **Push** this branch and open a **pull request** to `main`, or
- **Merge/push to `main`**, or
- Manually trigger it: **Actions** tab → **lab8-Supply Chain Security** → **Run workflow**

1. Open your fork on GitHub → **Actions** tab
2. Find the **lab8-Supply Chain Security** workflow run triggered by your push or PR
3. Confirm all three jobs complete with **green status** (✅):
   - `Cosign — Sign + Verify Image`
   - `Cosign — SBOM + Provenance Attestation`
   - `Cosign — Blob Sign + Verify`
4. Download the `lab8-cosign-sign-verify`, `lab8-sbom-provenance-attest`, and `lab8-blob-sign-verify` artifacts

> **Note:** CI uses ephemeral keys (`COSIGN_PASSWORD` in the workflow env) — separate from your Lab 8.1 local keypair. The pipeline fails if `labs/lab4/juice-shop.cdx.json` is missing from your fork.

### 8.3.8: Document in `submissions/lab8.3.md`

Append to your submission file:

```markdown
## Task 3: GitHub Actions Supply Chain Security Pipeline

### Workflow file
Paste the full content of `.github/workflows/lab8-supply-chain-security.yml`:

### Workflow run
- Direct link to a **green** workflow run (all three jobs passed): <URL>
- Confirm artifacts `lab8-cosign-sign-verify`, `lab8-sbom-provenance-attest`, and `lab8-blob-sign-verify` were uploaded

### Job: `cosign-sign-verify` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Triggers (`on:`)
What events start this workflow, and why run supply-chain checks on both `push` and `pull_request`?

#### Step: Sign and verify image digest
Why sign by **digest** instead of tag? Why use `--allow-insecure-registry` for the local registry?

#### Step: Upload sign-verify artifacts
What artifact is uploaded, and why use `if: always()`?

### Job: `sbom-provenance-attest` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Step: Attach CycloneDX SBOM attestation
How does this CI step relate to your Lab 8.2 local attestation work?

#### Step: Attach SLSA provenance attestation
What build metadata does the predicate capture from `${{ github.repository }}` and `${{ github.sha }}`?

### Job: `blob-sign-verify` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Step: Sign and verify blob
How does this CI job mirror the Bonus task's Codecov 2021 mitigation pattern?

### One-paragraph reflection (2-3 sentences)
How does this CI pipeline complement the local Cosign work from Lab 8.1, Lab 8.2, and the Bonus task?
When would you still run signing locally instead of (or in addition to) CI?
```

---

## How to Submit

```bash
git add .github/workflows/lab8-supply-chain-security.yml
git add submissions/lab8.3.md
git commit -m "feat(lab8.3): blob signing + supply chain CI + submission"
git push -u origin feature/lab8.3
```

Open a PR to `main` and confirm the **lab8-Supply Chain Security** workflow appears on the PR with **green status**.

> **Do NOT commit** `labs/lab8/results/` or `labs/lab8/keys/cosign.key` — CI generates artifacts on the runner. The submission paste-in and **green workflow run URL** are the evidence.

PR checklist body:

```text
- [ ] Bonus — Blob signed + verify-blob success + tamper failure
- [ ] Task 3 — lab8-supply-chain-security.yml committed
- [ ] lab8-Supply Chain Security workflow: all three jobs green + artifacts uploaded
- [ ] Submission includes green workflow run URL + job step explanations + CI vs local reflection
```

---

## Acceptance Criteria

### Bonus Task (2 pts)
- ✅ `cosign verify-blob` succeeds on the original tarball
- ✅ `cosign verify-blob` fails on the tampered tarball
- ✅ Codecov 2021 mitigation answer correctly identifies the role of `cosign verify-blob`

### Task 3 (4 pts)
- ✅ `.github/workflows/lab8-supply-chain-security.yml` exists and matches the reference structure (three jobs: sign/verify, SBOM+provenance attest, blob sign/verify)
- ✅ Submission includes a direct link to a **green** workflow run where all three jobs passed
- ✅ Sign/verify job steps explained accurately (digest binding, `--allow-insecure-registry`, triggers)
- ✅ SBOM attestation job explained with connection to Lab 8.2
- ✅ Blob signing job explained with Codecov mitigation mapping
- ✅ Reflection addresses how CI complements local Lab 8.1 / Lab 8.2 / Bonus work

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Bonus Task** — Blob signing | **2** | sign-blob pass + verify-blob pass on original + fail on tampered + Codecov mapping |
| **Task 3** — Supply Chain CI | **4** | Workflow committed + green run URL + job explanations + reflection |
| **Total** | **6** | |

---
