# Lab 1 — Submission

## Triage Report: OWASP Juice Shop

Evidence below was collected on 2026-08-19 at approximately 17:00 ICT.

### Scope & Asset

- Asset: OWASP Juice Shop (local lab instance)
- Image: `bkimminich/juice-shop:v20.0.0`
- Image digest: `sha256:fd58bdc9745416afce8184ee0666278a436574633ea7880365153a63bfd418b0`
- Host OS: macOS 27.0 (build 26A5416b), arm64
- Docker version: `Docker version 29.7.2, build a7dcaa6`

### Deployment Details

- Run command used:

  ```bash
  docker run -d --name juice-shop \
    -p 127.0.0.1:3000:3000 \
    bkimminich/juice-shop:v20.0.0
  ```

- Access URL: <http://127.0.0.1:3000>
- Network exposure: 127.0.0.1 only? [x] Yes [ ] No
- Container restart policy: `no`

### Health Check
- HTTP code on `/`: `200`
- API check — first 200 characters of `/api/Products`:

```json
{"status":"success","data":[{"id":1,"name":"Apple Juice (1000ml)","description":"The all-time classic.","price":1.99,"deluxePrice":0.99,"image":"apple_juice.jpg","createdAt":"2026-08-19T09:46:38.765Z"
```

- Container uptime:

```text
31cc245235b3  bkimminich/juice-shop:v20.0.0  Up 13 minutes  127.0.0.1:3000->3000/tcp
```

### Initial Surface Snapshot

- Login/Registration visible: [x] Yes [ ] No
  Notes: Login page, `User Registration` form.

- Product listing/search present: [x] Yes [ ] No
  Notes: The homepage displays the `All Products` listing with 46 products, pagination (`1 – 15 of 46`), item-count selector, search control.

- Admin or account area discoverable: [x] Yes [ ] No
  Notes: Account menu, Login page. No admin link was visible while unauthenticated.

- Client-side errors in DevTools console: [ ] Yes [x] No
  Notes: No warning or error.

- Pre-populated local storage/cookies:
  - Cookies: `language=en`
  - Cookies: `welcomebanner...=dismiss`
  - Local Storage: no entries observed

- Product review request observed:
  - Endpoint: `/rest/products/1/reviews`
  - HTTP status: `200`
  - Authentication required: No
  - Notes: The v20 endpoint returned two reviews, including reviewer email addresses, without an authentication token. The lab hint's older `/api/Products/1/reviews` path returned HTTP 500 and disclosed a server-side stack trace.

### Security Headers — Quick Look

Command used:

```bash
curl -I http://127.0.0.1:3000 2>&1 | head -20
```

Observed output:

```text
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Feature-Policy: payment 'self'
X-Recruiting: /#/jobs
Accept-Ranges: bytes
Cache-Control: public, max-age=0
Last-Modified: Wed, 19 Aug 2026 09:46:39 GMT
ETag: W/"26af-1a0196a6838"
Content-Type: text/html; charset=UTF-8
Content-Length: 9903
Vary: Accept-Encoding
Date: Wed, 19 Aug 2026 10:00:00 GMT
Connection: keep-alive
Keep-Alive: timeout=5
```

Headers missing from the response:

- [x] `Content-Security-Policy`
- [x] `Strict-Transport-Security`
- [ ] `X-Content-Type-Options: nosniff` — present
- [ ] `X-Frame-Options` — present as `SAMEORIGIN`

### Top 3 Risks Observed
1. Missing security headers — No CSP or HSTS headers. OWASP A06: Security Misconfiguration
2. Unauthenticated review data exposure — Reviewers’ email addresses are publicly accessible. OWASP A01: Broken Access Control
3. Stack-trace disclosure — Error responses reveal internal paths and framework details. OWASP A10: Mishandling of Exceptional Conditions

## PR Template Setup
- File: `.github/PULL_REQUEST_TEMPLATE.md`
- Sections included: Goal / Changes / Testing / Artifacts & Screenshots
- Checklist items:
  - Title is clear and follows the `feat(lab1): complete Juice Shop` style
  - No secrets or large temporary files are committed
  - Submission file exists at `submissions/lab1.md`
 - Auto-fill verified: [x] Yes — PR description showed my template
  - Draft PR evidence: https://github.com/golden-P11/DevSecOps-lab-26/pull/36

## Lab Completion Checklist

- [x] Task 1 — CLI/API triage is complete; .
- [x] Task 2 — PR template exists;
- [ ] Bonus — workflow file exists, Lab 1 Juice Shop Smoke Test is marked disabled.
