# Asechka publishing contract

Canonical origin: `https://asechka-website.vercel.app`. The website and existing native apps read the same GitHub-backed `dist/memories.json` collection. Publish directly to its backend; the Shakespeare quote-generation gateway does not hold publishing credentials.

## Login

`POST /api/session`, `Accept: application/json`, `Origin: https://asechka-website.vercel.app`, `Content-Type: application/x-www-form-urlencoded`. Body: `password=<URL-encoded existing Asechka site code>`.

A successful response sets `asechka_session` with a seven-day lifetime. Retain only this signed cookie in platform secure storage. Do not embed a password, session, GitHub token, or publishing key in the app or build settings. Do not retain the entered password. A session expires or becomes invalid if the site's password or signing secret changes. Disable automatic cross-origin redirects on authenticated requests.

## Publish selected quote

`POST /api/shakespeare` with:

```http
Accept: application/json
Content-Type: application/json
Origin: https://asechka-website.vercel.app
X-Asechka-Shakespeare: 1
Cookie: asechka_session=<signed session from login>
```

```json
{"operationId":"<stable quote UUID>","text":"<selected quote>","date":"2026-10-31","language":"en"}
```

Use the same UUID, original date, text, and optional supported language on every retry. A quote's saved creation date is suitable; do not regenerate the date at retry time. Text is capped at 2,400 UTF-16 code units. Supported optional languages: en, ar, arz, fr, ru, he, es, de, it, tr, ur, zh. The backend accepts only these fields and creates a quote attributed to `youssef`, with the note `Created with Shakespeare`. Publishing requires an explicit button click. Never publish automatically on generation, reveal, or login alone; a pending explicit publish can resume after successful login.

After confirmed canonical persistence, HTTP 200:

```json
{"id":"<same UUID>","posted":true,"url":"https://asechka-website.vercel.app/quotes.html"}
```

Errors contain `error`: 400 invalid JSON/fields, 401 expired or absent login, 403 invalid origin or request marker, 405 wrong method, 409 operation-ID collision or collection conflict, 413 oversized request, 503 unavailable server configuration/storage. Keep the draft and operation ID on failure. Treat malformed/non-JSON responses and redirects as failures, never as published. Only show success after checking status, `posted === true`, and returned `id` matches. On 401, clear the stored session and show the existing-code login; retry only the quote the user explicitly selected.

The session grants access to Asechka's existing shared space; it is not an individual account identity. Existing hosting/repository content visibility is unchanged. The GitHub repository currently has public visibility; the Vercel site retains its existing password gate.

## Deployment and verification

The endpoint is live on the canonical origin. [Source commit and tests](https://github.com/YoussefElb-Dev/asechka-website/commit/35630659e9e281a1b88a46afd7dce415fc850d61) are on the separate `asechka-website` repository's `main` branch; successful Vercel production deployment ID: `7454440749`.

No new server secret or gateway deployment is required. It uses the existing `SITE_PASSWORD`, `SESSION_SECRET`, and server-only `MUSIC_GITHUB_TOKEN`. The existing Studio repository-scoped SSH deploy key provided Git access; the configured Vercel Git integration deployed `main` automatically. Future backend changes should fetch and merge the latest `main` before a normal non-force push, because live shared posts also update that branch.

Verification on October 31, 2026: 32 local auth/feed/integration tests passed, including canonical GitHub commit concurrency and lost-response idempotency using a mocked GitHub API. Live login returned HTTP 200 JSON, a signed cookie, and no redirect. Live endpoint checks returned JSON errors with no redirects: absent/forged session 401, wrong method 405, wrong origin/missing marker 403, invalid quote 400, oversized body 413. The existing feed reported `writable:true` and remained at 23 quotes and 19 photos. A real quote was deliberately not posted during verification; successful write behavior was tested against the mocked canonical store. The first real publication should be the user's explicit button click.
