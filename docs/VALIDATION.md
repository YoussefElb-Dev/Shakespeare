# Validation record

This file records observed validation, separately from configuration that still requires accounts or another host. Update it after successful GitHub Actions runs and physical-device review.

## Verified locally

- Flutter `3.38.10` / Dart `3.10.9` dependency resolution with committed lockfile.
- Flutter static analysis without findings.
- Eighty-two Flutter unit/widget tests: persistence and cancellation; provider failures and UTF-8; creation/favorites/copy/library; Hebrew RTL and small-screen large-text layout; stable orb State through generation/regeneration; finite text emergence and Reduce Motion; outside-tap keyboard dismissal; Asechka login, strict confirmations, redirect refusal, secure-session failures, persistent retry IDs, duplicate prevention, and cancellation of pending sign-in.
- Twelve Gemini gateway tests using Node’s built-in test runner, including real Cloudflare runtime/Durable Object SQL concurrency, global quotas, provider free-tier quota handling, and diagnostics that exclude credentials and provider messages.
- Nine CI configuration/package tests: preview defaults, production endpoint gating, URL/tag validation, complete/partial signing credentials, secret handling, valid device IPA packaging, and rejection of simulator SDKs and ARM64 simulator binaries.
- Wrangler `4.61.1` deployment dry run successfully bundles the Worker and Durable Object bindings.
- GitHub workflow syntax and expressions checked with actionlint `1.7.11`.

- Android release-mode universal APK compiled successfully with the debug signing key for offline preview installation.
- Version 1.1 Android API 35 emulator integration passed with the actual shader renderer: idle motion frames, a held generation phase, center-out text emergence, favorites, and Arabic/Hebrew quote direction. Keyboard show/hide was observed in Android IME logs after the outside tap. Updated emulator screenshots, including generating and emerging phases, are included in `docs/screenshots/`. This software-rendered debug emulator run does not measure phone frame rates.
- Android XML and iOS plist/privacy-manifest XML parsed successfully; Python CI scripts passed compilation checks.

The local emulator screenshots show the offline preview. The delivered `dist/Shakespeare-Android.apk` has since been replaced with the GitHub-built live-AI APK, using a disposable debug signing key. The delivered IPA is the GitHub-built live-AI device app, ready for re-signing by a sideloader. Build logs, SHA-256 checksums, and a verification manifest accompany these files in `dist/`.

## Verified on hosted services

- Public repository: https://github.com/YoussefElb-Dev/Shakespeare. The initial private-repository billing block was resolved by switching to public standard runners with the owner’s permission.
- [iOS run 41171666841](https://github.com/YoussefElb-Dev/Shakespeare/actions/runs/41171666841) passed all 82 Flutter tests, simulator compilation, Xcode 26.2 ARM64 device compilation, and unsigned device IPA packaging with live AI enabled. Delivered version: 1.1.0 build 5, iOS 15 minimum, bundle identifier `app.shakespeare.shakespeare`, 8,451,646 bytes.
- The downloaded IPA passed its hosted SHA-256 checksum, ZIP CRC verification, iPhoneOS plist inspection, Mach-O ARM64/platform inspection, and checks for both the live AI gateway and Asechka origin in compiled code. SHA-256: `cd025115c3843af6ebf378601b0d0bb98f55ba5eb9a7ea3af000379e64be644b`.
- [Android run 41171666852](https://github.com/YoussefElb-Dev/Shakespeare/actions/runs/41171666852) passed Flutter checks and compiled the universal APK with live AI enabled. The downloaded 51,948,260-byte APK passed its hosted checksum, `apksigner` verification, embedded Asechka origin check, and package/SDK/ABI inspection: version 1.1.0 build 5, min SDK 24, target SDK 36, ARM64/ARMv7/x86_64. It uses the disposable debug certificate for personal installation; the artifact name includes `preview` to identify this signing mode. SHA-256: `20ec91cd59598e0c2790e43cfa5750930869d7fad6226997e7967f6adee498f6`.
- [Gateway run 41171666830](https://github.com/YoussefElb-Dev/Shakespeare/actions/runs/41171666830) passed all twelve gateway tests, nine CI configuration/package tests, and Worker bundling checks.
- The separate Asechka publishing endpoint is deployed on its canonical origin. Thirty-two focused auth, collection, social, and Shakespeare API tests passed. Live sign-in and negative auth/validation checks passed without posting test content; successful writes, concurrency and lost-response retries were tested against a mocked GitHub store. The website and native apps read the same canonical collection. A real publish is reserved for the user's explicit button click. See [API verification](../backend/ASECHKA_API.md).
- Cloudflare Worker and SQLite Durable Object deployed; both provider credential and rate-limit salt are encrypted Worker secrets. Google AI Studio shows Free tier. The default model is Gemini 3.5 Flash-Lite; Google rejected 2.5 Flash-Lite as unavailable to new users.
- Live HTTPS generation passed in English, Arabic, Egyptian Arabic, Hebrew, French, Russian, Spanish, German, Italian, Turkish, and Chinese. The app’s actual Dart `RemoteQuoteService` also passed English and long Urdu requests with `isPreview: false`, completing live checks across all twelve supported languages.
- The GitHub `QUOTE_API_URL` variable is configured with the deployed endpoint. No AI provider key is supplied to mobile builds.

## Still requires verification

- Apple distribution signing is optional for personal sideloading and has not been configured. The unsigned device IPA must be re-signed by the user’s sideloading tool before installation. Native iOS rendering still needs physical-device review.
- Production Android signing: requires the owner’s release keystore secrets; local preview APKs use the debug signing key.
- Physical-device refresh-rate, energy, accessibility, multilingual editorial quality, Apple privacy/store review, and distribution eligibility require release-owner validation. Emulator checks cannot establish a measured 60 FPS target on phones.

Hosted compilation and live AI access are verified. Apple distribution signing, physical-device behavior, and store distribution remain release-owner checks.
