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

The local emulator screenshots show the offline preview. The delivered `dist/Shakespeare-Android.apk` has since been replaced with the GitHub-built live-AI APK, using a disposable debug signing key. The delivered IPA is the GitHub-built live-AI device app, ready for re-signing by a sideloader. Build logs, SHA-256 checksums, and a verification manifest accompany these files in `dist/`.

## Verified on hosted services

- Public repository: https://github.com/YoussefElb-Dev/Shakespeare. The initial private-repository billing block was resolved by switching to public standard runners with the owner’s permission.
- [iOS run 41169525385](https://github.com/YoussefElb-Dev/Shakespeare/actions/runs/41169525385) passed Flutter checks, simulator compilation, Xcode 26.2 ARM64 device compilation, and unsigned device IPA packaging with live AI enabled. Delivered version: 1.0.0 build 4, iOS 15 minimum, bundle identifier `app.shakespeare.shakespeare`, 8,338,653 bytes.
- The downloaded IPA passed its hosted SHA-256 checksum, ZIP CRC verification, iPhoneOS plist inspection, Mach-O ARM64/platform inspection, and embedded live endpoint check. SHA-256: `46473993f48399f39675f35f930649e05f72613c9bb2083ec865cad1b90499a0`.
- [Android run 41169525387](https://github.com/YoussefElb-Dev/Shakespeare/actions/runs/41169525387) passed Flutter checks and compiled the universal APK with live AI enabled. The downloaded APK passed its hosted checksum, `apksigner` verification, and package/SDK/ABI inspection: version 1.0.0 build 4, min SDK 24, target SDK 36, ARM64/ARMv7/x86_64. It uses the disposable debug certificate for personal installation; the artifact name includes `preview` to identify this signing mode.
- [Gateway run 41169525557](https://github.com/YoussefElb-Dev/Shakespeare/actions/runs/41169525557) passed all twelve gateway tests, nine CI configuration/package tests, and Worker bundling checks.
- Cloudflare Worker and SQLite Durable Object deployed; both provider credential and rate-limit salt are encrypted Worker secrets. Google AI Studio shows Free tier. The default model is Gemini 3.5 Flash-Lite; Google rejected 2.5 Flash-Lite as unavailable to new users.
- Live HTTPS generation passed in English, Arabic, Egyptian Arabic, Hebrew, French, Russian, Spanish, German, Italian, Turkish, and Chinese. The app’s actual Dart `RemoteQuoteService` also passed English and long Urdu requests with `isPreview: false`, completing live checks across all twelve supported languages.
- The GitHub `QUOTE_API_URL` variable is configured with the deployed endpoint. No AI provider key is supplied to mobile builds.

## Still requires verification

- Apple distribution signing is optional for personal sideloading and has not been configured. The unsigned device IPA must be re-signed by the user’s sideloading tool before installation. Native iOS rendering still needs physical-device review.
- Production Android signing: requires the owner’s release keystore secrets; local preview APKs use the debug signing key.
- Physical-device refresh-rate, energy, accessibility, multilingual editorial quality, Apple privacy/store review, and distribution eligibility require release-owner validation. Emulator checks cannot establish a measured 60 FPS target on phones.

Hosted compilation and live AI access are verified. Apple distribution signing, physical-device behavior, and store distribution remain release-owner checks.
