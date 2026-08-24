# Lab 10 — Vulnerability Management with DefectDojo: The Capstone

![difficulty](https://img.shields.io/badge/difficulty-intermediate-yellow)
![topic](https://img.shields.io/badge/topic-Vuln%20Management-blue)
![points](https://img.shields.io/badge/points-6%2B2-orange)
![tech](https://img.shields.io/badge/tech-DefectDojo-informational)

> **Goal:** Spin up DefectDojo locally, import scan reports from Labs 4–7 into a single product/engagement, verify cross-tool deduplication, and (bonus) produce a 5-minute interview-walkthrough script.
> **Deliverable:** A PR from `feature/lab10` with `submissions/lab10.md` (import + dedup report) and (bonus) `submissions/lab10-walkthrough.md` (interview script). Submit PR link via Moodle.

---

## Overview

This is the **capstone**. You have nine labs of scan output. Lab 10 turns them into a **unified vulnerability program view** in DefectDojo.

In this lab you will practice:
- **DefectDojo v2.58.x** (Lecture 10 slide 9) — local setup, importers, dedup
- **Cross-tool dedup** — same CVE found by Trivy + Grype collapsing into one finding
- **Centralized triage** — one dashboard for SAST, DAST, SCA, IaC, and container findings
- (Bonus) **5-minute interview walkthrough** — the deliverable that gets you hired

> If you've kept your Lab 4–7 outputs locally, this lab is doable in one sitting. If not, regenerate them from the local lab steps or download CI artifacts from your fork's GitHub Actions runs before starting.

---

## Project State

**You should have from Labs 4–7** (regenerate or copy from CI artifacts if missing):

| Lab | Expected files (repo-relative) | Produced by |
|-----|--------------------------------|-------------|
| [4.1](lab4.1.md) / [4.2](lab4.2.md) | `labs/lab4/grype-from-sbom.json`, `labs/lab4/trivy.json` | Local scan or [lab4-sbom-sca.yml](../.github/workflows/lab4-sbom-sca.yml) artifact (`labs/lab4/reports/`) |
| [5.1](lab5-1.md) / [5.2](lab5-2.md) | `labs/lab5/results/semgrep.json`, `labs/lab5/results/auth-report.json` | Local scan or [lab5-sast-dast.yml](../.github/workflows/lab5-sast-dast.yml) artifact |
| [6.1](lab6.1.md) / [6.3](lab6.3.md) | `labs/lab6/results/checkov-terraform/results_json.json`, `labs/lab6/results/kics-ansible/results.json`, `labs/lab6/results/kics-pulumi/results.json` | Local scan or [lab6-iac-scanning.yml](../.github/workflows/lab6-iac-scanning.yml) artifact |
| [7.1](lab7.1.md) / [7.3](lab7.3.md) | `labs/lab7/results/trivy-image.json`, `labs/lab7/results/trivy-k8s.json` | Local scan or [lab7-container-security.yml](../.github/workflows/lab7-container-security.yml) artifact |

**Optional context (not imported by the batch script):**
- Lab 8: Cosign verify output (`labs/lab8/results/verify-original.json`) — supply-chain evidence, not a DefectDojo parser target in this course
- Lab 9: Falco alerts (`labs/lab9/falco/logs/falco.log`) — runtime detections; document manually if DefectDojo has no matching parser

**This lab adds:**
- A working DefectDojo instance under `labs/lab10/work/`
- A unified Product + Engagement with Lab 4–7 imports and dedup applied
- A capstone submission documenting import counts and one cross-tool dedup example
- (Bonus) An interview-ready walkthrough script

---

## Setup

You need:
- **Docker + docker compose** (DefectDojo runs as 7+ containers)
- **`jq`** + **`curl`**
- ~4 GB free memory (DefectDojo is heavyweight)

```bash
git switch main && git pull
git switch -c feature/lab10

mkdir -p labs/lab10/work
```

> **Plumbing provided** (in `labs/lab10/imports/`):
> - [`run-imports.sh`](lab10/imports/run-imports.sh) — batch-imports every Lab 4–7 report that exists on disk; auto-creates Product + Engagement; discovers scan_type names from your DefectDojo instance
> - [`env.sample`](lab10/imports/env.sample) — environment variables the script reads (`DD_URL`, `DD_TOKEN`, …)

If your CI artifacts use different filenames (e.g. `labs/lab4/reports/grype-report.json`), copy or symlink them to the paths expected by `run-imports.sh` before importing.

---

## Task 1 — DefectDojo Setup + Import All Prior Findings (6 pts)

**Objective:** Run DefectDojo locally, obtain admin credentials, create (or auto-create) a Product + Engagement for "Juice Shop", import every Lab 4–7 report, and prove dedup works.

### 10.1: Clone + start DefectDojo

```bash
# DefectDojo's official compose deployment
cd labs/lab10/work
git clone https://github.com/DefectDojo/django-DefectDojo dd
cd dd

# Write the .env file for dev mode
./docker/setEnv.sh release

# Pull + start (first run takes 5–10 minutes)
docker compose up -d

# Watch initializer logs until you see "Admin password: ..."
docker compose logs initializer | grep -i password

# UI: http://localhost:8080
```

### 10.2: Extract admin token

```bash
# Login UI at http://localhost:8080 — admin / <password from initializer logs>
# Go to: Profile → API v2 Key → copy your token

export DD_URL="http://localhost:8080"
export DD_TOKEN="<your-api-token>"

# Verify connectivity
curl -s -H "Authorization: Token $DD_TOKEN" \
  "$DD_URL/api/v2/products/" | jq .count
# Should print 0 (no products yet) on a fresh install
```

### 10.3: Create Product + Engagement (optional if using batch importer)

The batch script (`run-imports.sh`) sets `auto_create_context=true`, so you can skip manual creation and go straight to **10.4**. If you prefer the API explicitly (from repo root):

```bash
PRODUCT_ID=$(curl -s -X POST "$DD_URL/api/v2/products/" \
  -H "Authorization: Token $DD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "OWASP Juice Shop",
    "description": "DevSecOps-Intro capstone product",
    "prod_type": 1
  }' | jq -r .id)
echo "Product: $PRODUCT_ID"

ENGAGEMENT_ID=$(curl -s -X POST "$DD_URL/api/v2/engagements/" \
  -H "Authorization: Token $DD_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Course Semester Run\",
    \"product\": $PRODUCT_ID,
    \"target_start\": \"2026-09-01\",
    \"target_end\": \"2026-12-15\",
    \"engagement_type\": \"CI/CD\",
    \"status\": \"In Progress\"
  }" | jq -r .id)
echo "Engagement: $ENGAGEMENT_ID"
```

Defaults used by `run-imports.sh` (override via env vars): Product type **Engineering**, Product **OWASP Juice Shop**, Engagement **Course Semester Run**.

### 10.4: Import scan files

**Recommended — batch import from repo root:**

```bash
# After exporting DD_URL and DD_TOKEN (step 10.2)
bash labs/lab10/imports/run-imports.sh
```

The script skips any file that is missing and saves each API response under `labs/lab10/imports/import-*.json`.

**Manual template** (repeat per scan type if you prefer one-by-one control):

```bash
curl -X POST "$DD_URL/api/v2/import-scan/" \
  -H "Authorization: Token $DD_TOKEN" \
  -F "scan_type=Trivy Scan" \
  -F "engagement=$ENGAGEMENT_ID" \
  -F "file=@labs/lab7/results/trivy-image.json"
```

Scan types and file paths (must match `run-imports.sh`):

| Lab | File | DefectDojo `scan_type` |
|-----|------|------------------------|
| 4 | `labs/lab4/grype-from-sbom.json` | `Anchore Grype` |
| 4 | `labs/lab4/trivy.json` | `Trivy Scan` |
| 5 | `labs/lab5/results/semgrep.json` | `Semgrep JSON Report` |
| 5 | `labs/lab5/results/auth-report.json` | `ZAP Scan` |
| 6 | `labs/lab6/results/checkov-terraform/results_json.json` | `Checkov Scan` |
| 6 | `labs/lab6/results/kics-ansible/results.json` | `KICS Scan` |
| 6 | `labs/lab6/results/kics-pulumi/results.json` | `KICS Scan` |
| 7 | `labs/lab7/results/trivy-image.json` | `Trivy Scan` |
| 7 | `labs/lab7/results/trivy-k8s.json` | `Trivy Operator Scan` |

> **Note:** Lab 8 (Cosign) and Lab 9 (Falco) outputs are part of your overall program story but are **not** included in `run-imports.sh`. Mention them in your submission's program overview; import manually only if your DefectDojo build supports a matching parser.

### 10.5: Verify import + dedup

```bash
# Resolve engagement ID (if you used the batch importer, find it in the UI or API)
ENGAGEMENT_ID=$(curl -s -H "Authorization: Token $DD_TOKEN" \
  "$DD_URL/api/v2/engagements/?name=Course%20Semester%20Run" | jq -r '.results[0].id')

# Total findings linked to the engagement
curl -s -H "Authorization: Token $DD_TOKEN" \
  "$DD_URL/api/v2/findings/?engagement=$ENGAGEMENT_ID&limit=1" | jq .count
# Expect hundreds after all imports

# Dedup is automatic — same CVE from multiple Trivy/Grype imports should collapse
curl -s -H "Authorization: Token $DD_TOKEN" \
  "$DD_URL/api/v2/findings/?engagement=$ENGAGEMENT_ID&cve=CVE-2024-21626" | jq '.results | length'
# Should be 1 if your scans included this CVE (runc "Leaky Vessels")
```

In the DefectDojo UI, open a duplicated finding and confirm **Similar Findings** / multiple test references on one record.

### 10.6: Document in `submissions/lab10.md`

```markdown
# Lab 10 — Submission

## Task 1: DefectDojo Setup + Import

### DefectDojo version
- Version installed: <output of `docker compose -f labs/lab10/work/dd/docker-compose.yml images` or UI footer>

### Product + Engagement
- Product ID: <n>
- Product name: OWASP Juice Shop
- Engagement ID: <n>
- Engagement status: In Progress
- Import method: batch (`run-imports.sh`) / manual API / mixed

### Imports completed
| Lab | Scan type | File | Findings imported |
|-----|-----------|------|------------------:|
| 4 | Anchore Grype | grype-from-sbom.json | <n> |
| 4 | Trivy Scan | trivy.json | <n> |
| 5 | Semgrep JSON Report | semgrep.json | <n> |
| 5 | ZAP Scan | auth-report.json | <n> |
| 6 | Checkov Scan | checkov-terraform/results_json.json | <n> |
| 6 | KICS Scan | kics-ansible/results.json | <n> |
| 6 | KICS Scan | kics-pulumi/results.json | <n> |
| 7 | Trivy Scan (image) | trivy-image.json | <n> |
| 7 | Trivy Operator Scan | trivy-k8s.json | <n> |
| **Total raw imports** | | | <SUM> |
| **After dedup** | | | <n unique active findings> |

### Severity breakdown (active findings)
| Severity | Count |
|----------|------:|
| Critical | <n> |
| High | <n> |
| Medium | <n> |
| Low | <n> |
| Info | <n> |

### Dedup example (Lecture 10 slide 11)
Find ONE finding that DefectDojo dedupped across tools (same CVE/issue from ≥2 scanners). Quote:
- CVE/ID: <e.g. CVE-2024-21626>
- Number of source tools: <e.g. 3 — Trivy image, Trivy k8s, Grype>
- DefectDojo's single finding ID: <n>
- Why dedup matters for your program (2–3 sentences)

### Program layers (capstone reflection)
Briefly map which labs fed which layer of your Juice Shop program:
- Pre-commit / secrets (Lab 3)
- Build: SBOM + SCA (Lab 4)
- Code + runtime app testing: SAST + DAST (Lab 5)
- IaC (Lab 6), containers + K8s (Lab 7), supply chain (Lab 8), runtime (Lab 9)
- Aggregation: DefectDojo (Lab 10)
```

---

## Bonus Task — 5-Minute Interview Walkthrough Script (2 pts)

> 🌟 **The deliverable that gets you hired.** Many DevSecOps interviews are "talk me through your last program" for 5 minutes. This bonus produces exactly that script.

**Objective:** Write a 5-minute walkthrough following Lecture 10 slide 15 structure, using your DefectDojo import counts and dedup example from Task 1.

### B.1: Write the script

Create `submissions/lab10-walkthrough.md`:

```markdown
# 5-Minute DevSecOps Program Walkthrough — Juice Shop

## (0:00–0:30) Context
[1 sentence: I built a DevSecOps program around OWASP Juice Shop as the target...
1 sentence: Tools used, scope, what's signed/scanned/verified.]

## (0:30–2:00) Layers
[Draw the diagram from Lecture 9 slide 18 in your words. Talk through:
- Pre-commit: gitleaks for secrets + SSH-signed commits (Lab 3)
- Build: SBOM (Syft), SCA (Grype/Trivy), SAST (Semgrep), DAST (ZAP)
- Pre-deploy: Checkov/KICS on IaC, Cosign sign + Conftest gate (Labs 6–8)
- Runtime: Falco eBPF detection (Lab 9)
- Program: DefectDojo aggregation + dedup (Lab 10)]

## (2:00–3:00) Findings + Closures
[Talk through:
- Total open findings in DefectDojo after dedup: <n>
- One deduped CVE across multiple scanners (from Task 1)
- Strongest correlated finding (optional): caught by both Semgrep and ZAP — fix was <X>]

## (3:00–4:00) What the dashboard tells you
[Talk through:
- Top severity bucket driving risk: <Critical/High count>
- Which tool contributed the most *unique* findings vs duplicates removed by dedup
- One finding you would triage first and why]

## (4:00–4:30) Next Steps
[1 sentence: "If I had another quarter, I'd ship..."
1 sentence: tied to OWASP SAMM ladder progression — e.g. mature Defect Management or Detection.]

## (4:30–5:00) Q&A Anticipation
Anticipate 2 likely questions and answer them in your script:
1. "How would you handle a Log4Shell scenario?" → 1-paragraph answer referencing the SBOM
2. "Why didn't you use IAST/paid tools?" → honest tradeoff
```

### B.2: Practice it

Read it out loud. Time yourself. If you're over 5 minutes, **cut something** — interviews don't pause.

### B.3: Document in `submissions/lab10.md`

```markdown
## Bonus: Interview Walkthrough

- Walkthrough script: see `submissions/lab10-walkthrough.md`
- Practiced runtime: <n minutes:seconds>
- Two anticipated Q&A questions covered: yes / no
- Strongest claim in the script (most-quoted-by-interviewer line, in your view): <quote>
```

---

## How to Submit

```bash
git add submissions/lab10.md
git add submissions/lab10-walkthrough.md     # Bonus only
git commit -m "feat(lab10): defectdojo import report + capstone walkthrough"
git push -u origin feature/lab10

# Cleanup (after screenshots / submission paste-in)
cd labs/lab10/work/dd && docker compose down -v
```

> **Do NOT commit:**
> - `labs/lab10/work/dd/` — upstream DefectDojo clone (add to `.gitignore`)
> - Scan outputs under `labs/lab4/`, `labs/lab5/results/`, etc. — large and regeneratable; CI uploads them as artifacts
> - `labs/lab10/imports/import-*.json` — API responses from import runs

PR checklist body:

```text
- [ ] Task 1 — DefectDojo setup + imports + dedup proof + severity breakdown
- [ ] Bonus — 5-minute walkthrough script with timed practice
```

---

## Acceptance Criteria

### Task 1 (6 pts)
- ✅ DefectDojo running locally; admin password documented
- ✅ Product + Engagement created (IDs in submission)
- ✅ ≥6 scan types imported from Labs 4–7 (9 imports if all files present)
- ✅ Imports table populated with real counts
- ✅ Severity breakdown table populated from DefectDojo
- ✅ ONE cross-tool dedup example documented (specific CVE/ID + N source tools + finding ID)
- ✅ Program layers reflection connects Labs 3–10

### Bonus Task (2 pts)
- ✅ `submissions/lab10-walkthrough.md` exists with all 6 timed sections
- ✅ Script timed to ≤5 minutes when read aloud
- ✅ Anticipates ≥2 Q&A questions with answers prepared
- ✅ Uses real numbers from your DefectDojo instance (not placeholder zeros)

---

## Rubric

| Task | Points | Criteria |
|------|-------:|----------|
| **Task 1** — Setup + import | **6** | DefectDojo running + 6+ imports + dedup proof + counts + severity + program reflection |
| **Bonus Task** — Walkthrough | **2** | Timed-to-5-min script + Q&A preparation + real dashboard data |
| **Total** | **8** | 6 main + 2 bonus |
