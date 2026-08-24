# Lab 8.3 — Blob Signing + Supply Chain CI

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Supply%20Chain-blue)
![points](https://img.shields.io/badge/points-2%2B4-orange)
![tech](https://img.shields.io/badge/tech-Cosign%20%2B%20GitHub%20Actions-informational)

> **Goal:** Sign a release tarball with `cosign sign-blob` locally (Codecov 2021 mitigation pattern), then automate a release-style supply-chain pipeline in GitHub Actions: gate on Labs 4–7 checks, keyless Cosign sign + SBOM attestation to GHCR, and SLSA Level 3 provenance.
> **Deliverable:** A PR from `feature/lab8.3` with `.github/workflows/lab8-supply-chain-security.yml` and `submissions/lab8.3.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 8.1](lab8.1.md) recommended — you should understand Cosign keyed signing before automating it in CI.

> **Part of Lab 8:** This is the blob signing + CI half of Lab 8. Complete **[Lab 8.1](lab8.1.md)** and **[Lab 8.2](lab8.2.md)** separately.

---

## Overview

In this lab you will practice:
- **`cosign sign-blob`** — what would have stopped the Codecov 2021 attack (local Bonus task)
- **CI automation** — a release-style supply-chain pipeline that gates on Labs 4–7 checks, pushes to GHCR, then **keyless Cosign** sign + CycloneDX SBOM attestation + **SLSA Level 3** provenance via OIDC

Reference workflow: [`.github/workflows/lab8-supply-chain-security.yml`](../.github/workflows/lab8-supply-chain-security.yml)

---

## Project State

**You should have from Lab 8.1:**
- Cosign keypair at `labs/lab8/keys/` (for local blob signing)
- Familiarity with digest-bound signing and tamper demos

**This lab adds:**
- Local blob signing + tamper verification (Bonus)
- A reusable supply-chain CI pipeline on GitHub-hosted runners: gate jobs → GHCR push → keyless sign + attest → SLSA provenance

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

> **Green status requirement:** This pipeline is designed to **pass with green status** on any fork with Actions enabled and **GitHub Packages (GHCR) write** permission for `GITHUB_TOKEN`. No pre-committed SBOM file is required — Syft generates CycloneDX at runtime. Signing uses **Cosign keyless** via GitHub OIDC (not your Lab 8.1 local keypair). All gate jobs plus `sign-and-attest` and `slsa-provenance` must complete successfully.

### 8.3.6: Create the workflow file

Create the directory and file:

```bash
mkdir -p .github/workflows
nano .github/workflows/lab8-supply-chain-security.yml
```

Paste the following content (matches the [course reference workflow](../.github/workflows/lab8-supply-chain-security.yml)):

```yaml
# Supply-chain release pipeline — runs after L4/L5/L6/L7 gate jobs pass
name: lab8-Supply Chain Security

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

env:
  IMAGE: bkimminich/juice-shop:v20.0.0
  IMAGE_TAG: v20.0.0
  RESULTS_DIR: labs/lab8/results

jobs:
  test:
    name: Gate — Base CI (Lab 1)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Base CI gate
        run: |
          test -f .github/workflows/lab1-smoke.yml
          echo "Base CI gate passed (Lab 1 smoke workflow present)"

  sast:
    name: Gate — SAST (Lab 5)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: SAST gate
        run: |
          test -f .github/workflows/lab5-sast-dast.yml
          test -f labs/lab5/scripts/security_gate.py
          echo "SAST gate passed (Lab 5 workflow + security gate present)"

  dast:
    name: Gate — DAST (Lab 5)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: DAST gate
        run: |
          test -f labs/lab5/scripts/zap-auth.yaml
          test -f labs/lab5/scripts/compare_zap.sh
          echo "DAST gate passed (Lab 5 ZAP automation present)"

  image-scan:
    name: Gate — Image Scan (Lab 4 / Lab 7)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Scan Juice Shop image with Trivy
        uses: aquasecurity/trivy-action@v0.36.0
        with:
          scan-type: image
          image-ref: ${{ env.IMAGE }}
          scanners: vuln
          severity: HIGH,CRITICAL
          exit-code: "0"

      - name: Image scan gate
        run: |
          test -f .github/workflows/lab4-sbom-sca.yml
          test -f .github/workflows/lab7-container-security.yml
          echo "Image scan gate passed (Lab 4 + Lab 7 workflows present)"

  sign-and-attest:
    name: Cosign — Keyless Sign + SBOM Attestation
    needs: [test, sast, dast, image-scan]
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      id-token: write
      contents: read
      packages: write
      attestations: write
    outputs:
      digest: ${{ steps.build.outputs.digest }}
      image: ${{ steps.ghcr.outputs.image }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set GHCR image name (lowercase)
        id: ghcr
        run: |
          # GHCR requires lowercase repository paths (github.repository may be mixed case)
          GHCR_IMAGE="ghcr.io/$(echo '${{ github.repository }}' | tr '[:upper:]' '[:lower:]')/juice-shop"
          echo "GHCR_IMAGE=${GHCR_IMAGE}" >> "$GITHUB_ENV"
          echo "image=${GHCR_IMAGE}" >> "$GITHUB_OUTPUT"
          echo "Using GHCR image: ${GHCR_IMAGE}"

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Juice Shop to GHCR
        id: build
        run: |
          mkdir -p "${RESULTS_DIR}"
          docker pull "${IMAGE}"
          docker tag "${IMAGE}" "${GHCR_IMAGE}:${IMAGE_TAG}"
          docker push "${GHCR_IMAGE}:${IMAGE_TAG}"
          DIGEST=$(docker inspect "${GHCR_IMAGE}:${IMAGE_TAG}" \
            --format='{{index .RepoDigests 0}}' | cut -d@ -f2)
          echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"
          echo "${GHCR_IMAGE}@${DIGEST}" | tee "${RESULTS_DIR}/juice-shop-digest.txt"

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.7.0
        with:
          cosign-release: v2.4.1

      - name: Cosign keyless sign
        id: cosign-sign
        continue-on-error: true
        run: |
          cosign sign --yes "${GHCR_IMAGE}@${{ steps.build.outputs.digest }}" \
            2>&1 | tee "${RESULTS_DIR}/cosign-sign.log"

      - name: Generate CycloneDX SBOM with Syft
        id: syft-sbom
        continue-on-error: true
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.IMAGE }}
          format: cyclonedx-json
          output-file: ${{ env.RESULTS_DIR }}/juice-shop.cdx.json
          upload-artifact: false

      - name: Attach SBOM attestation
        id: cosign-sbom-attest
        continue-on-error: true
        run: |
          cosign attest --yes \
            --type cyclonedx \
            --predicate "${RESULTS_DIR}/juice-shop.cdx.json" \
            "${GHCR_IMAGE}@${{ steps.build.outputs.digest }}" \
            2>&1 | tee "${RESULTS_DIR}/sbom-attest.log"
          cosign verify-attestation \
            --type cyclonedx \
            "${GHCR_IMAGE}@${{ steps.build.outputs.digest }}" \
            | jq -r '.[0].payload | @base64d | fromjson | .predicate' \
            > "${RESULTS_DIR}/sbom-from-attestation.json"

      - name: Verify keyless signature
        id: cosign-verify
        continue-on-error: true
        run: |
          cosign verify "${GHCR_IMAGE}@${{ steps.build.outputs.digest }}" \
            2>&1 | tee "${RESULTS_DIR}/cosign-verify.json"

      - name: Upload sign-and-attest artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lab8-sign-and-attest
          path: |
            ${{ env.RESULTS_DIR }}/
          if-no-files-found: warn
          retention-days: 30

      - name: Fail on sign or attestation error
        if: |
          steps.cosign-sign.outcome == 'failure' ||
          steps.syft-sbom.outcome == 'failure' ||
          steps.cosign-sbom-attest.outcome == 'failure' ||
          steps.cosign-verify.outcome == 'failure'
        run: exit 1

  slsa-provenance:
    name: SLSA — Container Provenance (Level 3)
    needs: sign-and-attest
    permissions:
      actions: read
      id-token: write
      packages: write
      attestations: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.0.0
    with:
      image: ${{ needs.sign-and-attest.outputs.image }}
      digest: ${{ needs.sign-and-attest.outputs.digest }}
      registry-username: ${{ github.actor }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
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
3. Confirm all jobs complete with **green status** (✅):
   - `Gate — Base CI (Lab 1)`
   - `Gate — SAST (Lab 5)`
   - `Gate — DAST (Lab 5)`
   - `Gate — Image Scan (Lab 4 / Lab 7)`
   - `Cosign — Keyless Sign + SBOM Attestation`
   - `SLSA — Container Provenance (Level 3)`
4. Download the `lab8-sign-and-attest` artifact
5. Confirm the image appears under **Packages** on your fork (`ghcr.io/<owner>/<repo>/juice-shop` — path is **lowercase** even if your repo name is mixed case)

> **Note:** CI uses **Cosign keyless** signing via GitHub OIDC — separate from your Lab 8.1 local keypair. Signatures and attestations are bound to the **GHCR digest** (`ghcr.io/<lowercase-repo>/juice-shop@sha256:…`). GHCR rejects uppercase in image paths, so the workflow lowercases `${{ github.repository }}` before push. Ensure **Settings → Actions → General → Workflow permissions** allows `Read and write permissions` so `GITHUB_TOKEN` can push to GHCR.

### 8.3.8: Document in `submissions/lab8.3.md`

Append to your submission file:

```markdown
## Task 3: GitHub Actions Supply Chain Security Pipeline

### Workflow file
Paste the full content of `.github/workflows/lab8-supply-chain-security.yml`:

### Workflow run
- Direct link to a **green** workflow run (all gate jobs + sign-and-attest + slsa-provenance passed): <URL>
- Confirm artifact `lab8-sign-and-attest` was uploaded
- Confirm GHCR package `juice-shop` exists on your fork

### Gate jobs (`test`, `sast`, `dast`, `image-scan`) — explanation
Explain the purpose of each gate job (2-3 sentences each):
- Why does `sign-and-attest` use `needs: [test, sast, dast, image-scan]`?
- How do these gates map to Labs 1, 4, 5, and 7?
- In production, would these be separate workflows or jobs in one release pipeline?

### Job: `sign-and-attest` — step explanation
Explain the purpose of each step (2-3 sentences each):

#### Triggers (`on:`)
What events start this workflow, and why run supply-chain checks on both `push` and `pull_request`?

#### Permissions (`id-token`, `packages`, `attestations`)
Why does keyless Cosign require `id-token: write`? What does `packages: write` enable?

#### Step: Set GHCR image name (lowercase)
Why is this step required? What happens if `${{ github.repository }}` contains uppercase letters (e.g. `DevSecOps-lab-26`)?

#### Step: Build and push Juice Shop to GHCR
Why push to `ghcr.io/<lowercase-repo>/juice-shop` instead of a local registry? Why capture digest after push?

#### Step: Cosign keyless sign
How does keyless signing differ from the keyed signing you did in Lab 8.1? Why sign by **digest** instead of tag?

#### Step: Generate CycloneDX SBOM with Syft
Why generate the SBOM in CI instead of relying on a committed `labs/lab4/juice-shop.cdx.json`?

#### Step: Attach SBOM attestation
How does this CI step relate to your Lab 8.2 local attestation work?

#### Step: Verify keyless signature
What trust root does `cosign verify` use in keyless mode (vs `--key cosign.pub` locally)?

#### Step: Upload sign-and-attest artifacts
What artifact is uploaded when sign/attest **fails**, and why use `continue-on-error` + `if: always()`?

### Job: `slsa-provenance` — explanation
Explain (2-3 sentences each):
- Why is SLSA provenance a **separate reusable workflow job** instead of a shell step?
- What does `generator_container_slsa3.yml@v2.0.0` add beyond the manual provenance predicate from Lab 8.2?
- How do `image` and `digest` inputs tie this job to `sign-and-attest`?

### Bonus vs CI (blob signing)
How does the Bonus task's local `cosign sign-blob` differ from this CI pipeline's image signing? When would you use each?

### One-paragraph reflection (2-3 sentences)
How does this CI pipeline complement the local Cosign work from Lab 8.1 and Lab 8.2?
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
- [ ] Bonus — Blob signed + verify-blob success + tamper failure (local)
- [ ] Task 3 — lab8-supply-chain-security.yml committed
- [ ] lab8-Supply Chain Security workflow: all gate jobs + sign-and-attest + slsa-provenance green
- [ ] GHCR package visible + lab8-sign-and-attest artifact uploaded
- [ ] Submission includes green workflow run URL + gate/sign/SLSA explanations + CI vs local reflection
```

---

## Acceptance Criteria

### Bonus Task (2 pts)
- ✅ `cosign verify-blob` succeeds on the original tarball
- ✅ `cosign verify-blob` fails on the tampered tarball
- ✅ Codecov 2021 mitigation answer correctly identifies the role of `cosign verify-blob`

### Task 3 (4 pts)
- ✅ `.github/workflows/lab8-supply-chain-security.yml` exists and matches the reference structure (four gate jobs + `sign-and-attest` + `slsa-provenance`)
- ✅ Submission includes a direct link to a **green** workflow run where all jobs passed
- ✅ Gate jobs explained with mapping to Labs 1/4/5/7 and `needs:` dependency rationale
- ✅ Keyless sign + SBOM attestation steps explained (OIDC, GHCR digest, Syft in CI)
- ✅ SLSA reusable workflow job explained with connection to Lab 8.2
- ✅ Bonus vs CI blob signing distinction addressed
- ✅ Reflection addresses how CI complements local Lab 8.1 / Lab 8.2 work

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Bonus Task** — Blob signing | **2** | sign-blob pass + verify-blob pass on original + fail on tampered + Codecov mapping |
| **Task 3** — Supply Chain CI | **4** | Workflow committed + green run URL + gate/sign/SLSA explanations + reflection |
| **Total** | **6** | |

---
