# Lab 8.2 — SBOM + Provenance Attestations

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Supply%20Chain-blue)
![points](https://img.shields.io/badge/points-4-orange)
![tech](https://img.shields.io/badge/tech-Cosign%20%2B%20CycloneDX-informational)

> **Goal:** Attach the Lab 4 CycloneDX SBOM and a minimal SLSA provenance attestation to your signed Juice Shop image, then verify both.
> **Deliverable:** A PR from `feature/lab8.2` with `submissions/lab8.2.md`. Submit PR link via Moodle.
> **Prerequisite:** [Lab 8.1](lab8.1.md) — you need a running local registry, a captured image digest, and a Cosign keypair.

> **Part of Lab 8:** This is the attestation half of Lab 8. Complete **[Lab 8.1](lab8.1.md)** first; **[Lab 8.3](lab8.3.md)** covers blob signing + supply-chain CI.

---

## Overview

In this lab you will practice:
- **In-toto attestation predicates** — CycloneDX SBOM + minimal provenance attached to a signed image digest

> ⏭️ Optional. Skipping won't affect future labs but you lose the Lab 4 → Lab 10 SBOM chain.

---

## Project State

**You should have from Lab 8.1:**
- Local registry (`lab8-registry`) with Juice Shop pushed
- `labs/lab8/results/juice-shop-digest.txt` — registry digest to attest
- Cosign keypair at `labs/lab8/keys/` (private key stays local)

**You should have from Lab 4:**
- `labs/lab4/juice-shop.cdx.json` — CycloneDX SBOM (Lab 4 Task 1)
- `labs/lab4/juice-shop-attestation.json` — sign-ready predicate (Lab 4 Bonus, if completed)

**This lab adds:**
- SBOM attestation attached to the image (Lab 4 SBOM in its final signed form)
- Minimal SLSA provenance attestation + verification output

---

## Setup

You need:
- **Docker** + running `lab8-registry` from Lab 8.1
- **Cosign v3.x**
- **`jq`**

```bash
git switch main && git pull
git switch -c feature/lab8.2

# Restart registry if you stopped it after Lab 8.1
docker start lab8-registry 2>/dev/null || \
  docker run -d --name lab8-registry -p 127.0.0.1:5000:5000 registry:3

cosign version
mkdir -p labs/lab8/results
```

---

## Task 2 — SBOM + Provenance Attestations (4 pts)

**Objective:** Attach the Lab 4 SBOM and a minimal provenance attestation to the image. Verify both.

### 8.2.1: Attach SBOM as a CycloneDX attestation

```bash
DIGEST=$(cat labs/lab8/results/juice-shop-digest.txt)

# Use the Lab 4 SBOM as the predicate
cosign attest \
  --key labs/lab8/keys/cosign.key \
  --type cyclonedx \
  --predicate labs/lab4/juice-shop.cdx.json \
  --yes \
  "$DIGEST"

# Verify the attestation + extract the embedded SBOM
cosign verify-attestation \
  --key labs/lab8/keys/cosign.pub \
  --insecure-ignore-tlog \
  --type cyclonedx \
  "$DIGEST" | jq -r '.payload | @base64d | fromjson | .predicate' \
  > labs/lab8/results/sbom-from-attestation.json

# Compare to Lab 4 source
diff <(jq -S '.components | length' labs/lab4/juice-shop.cdx.json) \
     <(jq -S '.components | length' labs/lab8/results/sbom-from-attestation.json)
# Should print nothing — same content
```

### 8.2.2: Attach a minimal provenance attestation

> **Cosign v3 note:** `cosign attest --type slsaprovenance` expects ONLY the predicate body (not the full in-toto envelope). Cosign wraps your predicate in the envelope automatically.

```bash
# Write the SLSA-provenance-v0.2 predicate body only
cat > /tmp/predicate-only.json <<EOF
{
  "builder": { "id": "https://localhost/lab8-student" },
  "buildType": "https://example.com/lab8/local-build",
  "invocation": {
    "configSource": {
      "uri": "https://github.com/student/repo",
      "digest": { "sha1": "abc123" }
    }
  }
}
EOF

cosign attest \
  --key labs/lab8/keys/cosign.key \
  --type slsaprovenance \
  --predicate /tmp/predicate-only.json \
  --tlog-upload=false \
  --allow-insecure-registry \
  --yes \
  "$DIGEST"

# Verify
cosign verify-attestation \
  --key labs/lab8/keys/cosign.pub \
  --insecure-ignore-tlog \
  --type slsaprovenance \
  "$DIGEST" > labs/lab8/results/provenance-verify.json
```

### 8.2.3: Document in `submissions/lab8.2.md`

````markdown
# Lab 8.2 — Submission

## Task 2: SBOM + Provenance Attestations

### SBOM attestation
- Attached: yes (`cosign attest --type cyclonedx` exit 0)
- Verify-attestation output (first 30 lines of decoded payload):
```json
<paste — must show _type, subject, predicateType, predicate with components>
```
- Component count matches Lab 4 source: yes / no
- diff between Lab 4 SBOM and the extracted-from-attestation SBOM: `<output>` (empty diff = success)

### Provenance attestation
- Attached: yes
- Builder ID in predicate: `<your value>`
- buildType in predicate: `<your value>`

### What this gives a Lab 9 verifier (2-3 sentences)
Lecture 8 slide 12 + Lecture 9 slide 4 — at K8s admission time, a Kyverno verify-images policy
can require BOTH signatures AND specific attestation predicates. What's the operational difference
between a "signed but no SBOM" image and a "signed with SBOM" image when the next Log4Shell hits?
````

---

## How to Submit

```bash
git add submissions/lab8.2.md
git commit -m "feat(lab8.2): SBOM + provenance attestations"
git push -u origin feature/lab8.2
```

> **Do NOT commit** `labs/lab8/results/` or `labs/lab8/keys/cosign.key` — regeneratable / secret.

PR checklist body:

```text
- [ ] Task 2 — SBOM + provenance attestations attached and verified
```

---

## Acceptance Criteria

### Task 2 (4 pts)
- ✅ SBOM attestation attached; `cosign verify-attestation --type cyclonedx` succeeds
- ✅ Decoded predicate matches Lab 4's SBOM (verified with diff)
- ✅ Provenance attestation attached; `cosign verify-attestation --type slsaprovenance` succeeds
- ✅ "Operational difference" answer concretely references the Log4Shell pattern

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 2** — Attestations | **4** | SBOM attest passes + provenance attest passes + Log4Shell operational answer |
| **Total** | **4** | |

---
