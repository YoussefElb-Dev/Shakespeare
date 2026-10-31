# Shakespeare AI gateway

Cloudflare Worker with a SQLite-backed Durable Object quota gate. AI provider keys never enter the mobile app. The gateway uses the Google Gemini generateContent API with a JSON quote schema, original writing instructions for every language, bounded inputs/outputs, refusal detection, timeouts, and no automatic provider retries that could multiply costs.

The owner’s gateway is deployed at `https://shakespeare-gateway.youssef-elboraei-2010.workers.dev/v1/quotes`, with the dedicated Shakespeare Google AI Studio key stored as an encrypted Worker secret. Live English, Arabic, Egyptian Arabic, Hebrew, and Urdu generation has been verified. Gemini 3.5 Flash-Lite is used because Google rejects the older 2.5 Flash-Lite model for new users.

## Deploy

Use Node `22.16.0` and pnpm `10.28.0`:

```sh
cd backend
pnpm install --frozen-lockfile
pnpm test
pnpm check
pnpm exec wrangler login
pnpm exec wrangler secret put GEMINI_API_KEY
pnpm exec wrangler secret put RATE_LIMIT_SALT
pnpm deploy
```

`GEMINI_API_KEY` is your server-side Google AI Studio API credential. `RATE_LIMIT_SALT` must be at least 32 random characters (for example, generate it using `openssl rand -hex 32`). Both are **Cloudflare Worker secrets**, not Flutter defines or files committed to Git. The deployment creates the quota namespace using the included `v1` migration. A Cloudflare account with Workers/Durable Objects support and a Google AI Studio account eligible for Gemini API free-tier access are required. Keep billing disabled on the Google project for free-tier use. Free access has project/model quotas and is not unlimited.

After deployment, verify `GET https://YOUR-WORKER/health` returns `{"status":"ok"}`. Set GitHub `QUOTE_API_URL` to `https://YOUR-WORKER/v1/quotes`, then build the apps. A health response proves routing, not AI credentials; verify a live generation separately.

The server’s `GEMINI_MODEL` variable defaults to `gemini-3.5-flash-lite`. Set it to a Gemini 3 Flash-Lite model available in your project that supports JSON-schema output and thinkingLevel: minimal. No model can be selected by the mobile request. Review multilingual writing with native speakers before release.

## Limits and privacy

The single quota coordinator atomically reserves usage before contacting the provider: 10 creations per minute and 100 per UTC day per hashed client IP; `GLOBAL_DAILY_LIMIT` defaults to 1,000 requests/day across the service. Failures consume a reservation. A salted HMAC includes the UTC day, so raw IPs are never stored and client hashes rotate daily. Old usage rows are deleted on the next successful reservation. Users on a shared network share the same IP allowance. Misconfigured quotas fail closed.

Only Cloudflare’s `CF-Connecting-IP` identity header is used. The Worker is intended to run directly behind Cloudflare’s edge. Do not expose it behind an untrusted proxy that can forge that identity. Native mobile clients need no embedded shared password. This is a public, anonymous, rate-limited service; it does not claim user authentication or device attestation. Configure provider billing limits for your deployment. The global reservation cap and token bound limit exposure but do not express a dollar budget.

Requests are limited to 12 KB, prompts to 500 characters, and quote text to 2,400 characters. The provider gets at most 1,024 output tokens. Quote content and prompts are not stored by the gateway; provider-side handling is governed by the provider account’s retention settings and policies. Google may use free-tier prompts and responses to improve its products. Do not submit sensitive information. See [Google pricing and data use](https://ai.google.dev/gemini-api/docs/pricing). Provider quota exhaustion returns 429; no paid fallback is configured. Worker application observability is disabled by default. Infrastructure providers may still process service metadata.

Browser CORS is disabled by default; native apps have no browser Origin header. If needed, set `ALLOWED_ORIGINS` to an exact comma-separated allowlist, with no wildcard. CORS does not authenticate native clients.

## API

`POST /v1/quotes`, `Content-Type: application/json`:

```json
{"language":"arz","category":"romance","length":"short","tone":"poetic","prompt":"coming home after a long day","previous":"optional previous quote"}
```

Languages: `en`, `ar`, `arz`, `fr`, `ru`, `he`, `es`, `de`, `it`, `tr`, `ur`, `zh`. Categories: `romance`, `life`, `motivation`, `friendship`, `success`, `nature`, `philosophy`, `art`, `random`. Lengths: `veryShort`, `short`, `medium`, `long`. Tones: `poetic`, `romantic`, `deep`, `motivational`, `funny`, `philosophical`, `modern`, `classic`.

```json
{"id":"server-generated-uuid","text":"Ø¥Ù†Øª Ø±Ø§Ø­Ø© Ù‚Ù„Ø¨ÙŠ.","language":"arz"}
```

Errors use an `error` string and appropriate status: 400 input, 403 browser origin, 404 route, 405 method, 429 quota, 502 provider response/failure, 503 missing config or unavailable quota service. Provider errors and credentials are never returned to clients.

For local testing, copy `.dev.vars.example` to ignored `.dev.vars` and replace its values. Run `pnpm dev`. Local HTTP is useful for testing the gateway directly; production mobile builds deliberately require HTTPS, so use a deployed endpoint or an HTTPS tunnel for a live device. Do not place private provider keys in `QUOTE_API_URL`.
