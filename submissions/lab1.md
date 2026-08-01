# Lab 1 — Submission

## Triage Report: OWASP Juice Shop

### Scope & Asset

- Asset: OWASP Juice Shop (local lab instance)
- Image: `bkimminich/juice-shop:v20.0.0`
- Image digest: `REPLACE_WITH_OUTPUT_OF_DOCKER_INSPECT`
- Host OS: `REPLACE_WITH_HOST_OS`
- Docker version: `REPLACE_WITH_DOCKER_VERSION`

### Deployment Details

- Run command used:

  ```bash
  docker run -d --name juice-shop \
    -p 127.0.0.1:3000:3000 \
    bkimminich/juice-shop:v20.0.0
  ```

- Access URL: <http://127.0.0.1:3000>
- Network exposure: 127.0.0.1 only? [x] Yes [ ] No
- Container restart policy: `REPLACE_WITH_RESTART_POLICY`

The container is bound only to `127.0.0.1`, so the deliberately vulnerable
application is not exposed on every host network interface.

### Health Check

- HTTP code on `/`: `REPLACE_WITH_HTTP_STATUS`
- Product count returned by `/api/Products`: `REPLACE_WITH_PRODUCT_COUNT`
- Application version: `REPLACE_WITH_APPLICATION_VERSION`

API check — first 200 characters of `/api/Products`:

```json
REPLACE_WITH_FIRST_200_CHARACTERS_OF_PRODUCTS_API_RESPONSE
```

Container uptime:

```text
REPLACE_WITH_DOCKER_PS_OUTPUT
```

### Initial Surface Snapshot

- Login/Registration visible: [ ] Yes [ ] No  
  Notes: `REPLACE_WITH_REAL_OBSERVATION`

- Product listing/search present: [ ] Yes [ ] No  
  Notes: `REPLACE_WITH_REAL_OBSERVATION`

- Admin or account area discoverable: [ ] Yes [ ] No  
  Notes: `REPLACE_WITH_REAL_OBSERVATION`

- Client-side errors in DevTools console: [ ] Yes [ ] No  
  Notes: `REPLACE_WITH_REAL_OBSERVATION`

- Pre-populated local storage/cookies:
  - `REPLACE_WITH_KEY_OR_COOKIE_1`
  - `REPLACE_WITH_KEY_OR_COOKIE_2`
  - `REPLACE_WITH_ADDITIONAL_ITEMS_OR_REMOVE_THIS_LINE`

- Product review request observed:
  - Endpoint: `REPLACE_WITH_REVIEW_ENDPOINT`
  - HTTP status: `REPLACE_WITH_STATUS_CODE`
  - Authentication required: `REPLACE_WITH_YES_OR_NO`
  - Notes: `REPLACE_WITH_REAL_OBSERVATION`

### Security Headers — Quick Look

Command used:

```bash
curl -I http://127.0.0.1:3000 2>&1 | head -20
```

Observed output:

```text
REPLACE_WITH_REAL_CURL_HEADER_OUTPUT
```

Headers missing from the response:

- [ ] `Content-Security-Policy`
- [ ] `Strict-Transport-Security`
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options`

> Mark `[x]` only for headers that were actually missing from your response.

### Top 3 Risks Observed

1. **REPLACE_WITH_RISK_NAME_1** —  
   `Write 2–3 sentences explaining what you observed, why it matters, and map
   it to one OWASP Top 10:2025 category such as A01–A10.`

2. **REPLACE_WITH_RISK_NAME_2** —  
   `Write 2–3 sentences explaining what you observed, why it matters, and map
   it to one OWASP Top 10:2025 category such as A01–A10.`

3. **REPLACE_WITH_RISK_NAME_3** —  
   `Write 2–3 sentences explaining what you observed, why it matters, and map
   it to one OWASP Top 10:2025 category such as A01–A10.`

## PR Template Setup

- File: `.github/PULL_REQUEST_TEMPLATE.md`
- Sections included: Goal / Changes / Testing / Artifacts & Screenshots
- Checklist items:
  - Title is clear and follows the `feat(labN): <topic>` style
  - No secrets or large temporary files are committed
  - Submission file exists at `submissions/labN.md`
- Auto-fill verified: [x] Yes — the PR description showed the template before manual editing
- Draft PR evidence: `REPLACE_WITH_DRAFT_PR_URL_OR_SCREENSHOT_PATH`

## Lab Completion Checklist

- [x] Task 1 done — Juice Shop deployed and triage report created
- [x] Task 2 done — `.github/PULL_REQUEST_TEMPLATE.md` created and auto-fill verified
- [ ] Bonus done — `.github/workflows/lab1-smoke.yml` runs successfully

## Bonus: CI Smoke Test

> Remove this entire section if you did not complete the bonus task.

- Workflow file: `.github/workflows/lab1-smoke.yml`
- Trigger: `pull_request` on `main`
- Workflow permissions: `contents: read`
- Run URL: `REPLACE_WITH_GREEN_ACTIONS_RUN_URL`
- Workflow run duration: `REPLACE_WITH_DURATION`

Curl response excerpt:

```text
REPLACE_WITH_SUCCESSFUL_HTTP_200_EXCERPT
```
