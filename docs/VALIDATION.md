# Validation record

This file records observed validation, separately from configuration that still requires accounts or another host. Update it after successful GitHub Actions runs and physical-device review.

## Verified locally

- Flutter `3.38.10` / Dart `3.10.9` dependency resolution with committed lockfile.
- Flutter static analysis without findings.
- Twelve Flutter unit/widget tests: persistent collections/settings, bounded history, damaged storage recovery, cancellation races, provider failures, UTF-8, input options, creation/favorites/copy/library navigation, Hebrew RTL, and small-screen large-text layout.
- Twelve Gemini gateway tests using Node’s built-in test runner, including real Cloudflare runtime/Durable Object SQL concurrency, global quotas, provider free-tier quota handling, and diagnostics that exclude credentials and provider messages.
- Nine CI configuration/package tests: preview defaults, production endpoint gating, URL/tag validation, complete/partial signing credentials, secret handling, valid device IPA packaging, and rejection of simulator SDKs and ARM64 simulator binaries.
- Wrangler `4.61.1` deployment dry run successfully bundles the Worker and Durable Object bindings.
- GitHub workflow syntax and expressions checked with actionlint `1.7.11`.

- Android release-mode universal APK compiled successfully with the debug signing key for offline preview installation.
- Android API 35 emulator device flow passed with the actual shader renderer, screenshot capture, favorites, and Arabic/Hebrew quote direction. Emulator screenshots are included in `docs/screenshots/`.
- Android XML and iOS plist/privacy-manifest XML parsed successfully; Python CI scripts passed compilation checks.

The delivered `dist/Shakespeare-Android.apk` is a labelled offline preview, not a production-signed/live-AI distribution. Its build log and SHA-256 checksum are included alongside the artifact. See the README for enabling production outputs.

## Verified on hosted services

- Public repository: https://github.com/YoussefElb-Dev/Shakespeare. The initial private-repository billing block was resolved by switching to public standard runners with the owner’s permission.
- [iOS run 41168706048](https://github.com/YoussefElb-Dev/Shakespeare/actions/runs/41168706048) passed Flutter checks, simulator compilation, Xcode 26.2 ARM64 device compilation, and unsigned device IPA packaging. This first run used offline preview configuration. A live endpoint rebuild is pending.
- [Gateway run 41168707188](https://github.com/YoussefElb-Dev/Shakespeare/actions/runs/41168707188) passed the CI tests and Worker bundling checks before deployment.
- Cloudflare Worker and SQLite Durable Object deployed; both provider credential and rate-limit salt are encrypted Worker secrets. Google AI Studio shows Free tier. The default model is Gemini 3.5 Flash-Lite; Google rejected 2.5 Flash-Lite as unavailable to new users.
- Live HTTPS generation passed in English, Arabic, Egyptian Arabic, and Hebrew. The app’s actual Dart `RemoteQuoteService` also passed English and long Urdu requests with `isPreview: false`.
- The GitHub `QUOTE_API_URL` variable is configured with the deployed endpoint. No AI provider key is supplied to mobile builds.

## Still requires verification

- The live-configured iPhone IPA rebuild and hosted Android build are pending. The Android workflow was corrected to avoid the obsolete SDK `tools` package.
- Apple distribution signing is optional for personal sideloading and has not been configured. The unsigned device IPA must be re-signed by the user’s sideloading tool before installation. Native iOS rendering still needs physical-device review.
- Production Android signing: requires the owner’s release keystore secrets; local preview APKs use the debug signing key.
- Physical-device refresh-rate, energy, accessibility, multilingual editorial quality, Apple privacy/store review, and distribution eligibility require release-owner validation. Emulator checks cannot establish a measured 60 FPS target on phones.

The repository implements the build pipeline; static checks alone are not presented as proof of hosted signing or native iOS compilation. Use the README’s setup instructions to finish account-dependent verification.
