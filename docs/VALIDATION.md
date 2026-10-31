# Validation record

This file records observed validation, separately from configuration that still requires accounts or another host. Update it after successful GitHub Actions runs and physical-device review.

## Verified locally

- Flutter `3.38.10` / Dart `3.10.9` dependency resolution with committed lockfile.
- Flutter static analysis without findings.
- Twelve Flutter unit/widget tests: persistent collections/settings, bounded history, damaged storage recovery, cancellation races, provider failures, UTF-8, input options, creation/favorites/copy/library navigation, Hebrew RTL, and small-screen large-text layout.
- Eleven Gemini gateway tests using Node’s built-in test runner, including real Cloudflare runtime/Durable Object SQL concurrency, global quotas, and provider free-tier quota handling.
- Nine CI configuration/package tests: preview defaults, production endpoint gating, URL/tag validation, complete/partial signing credentials, secret handling, valid device IPA packaging, and rejection of simulator SDKs and ARM64 simulator binaries.
- Wrangler `4.61.1` deployment dry run successfully bundles the Worker and Durable Object bindings.
- GitHub workflow syntax and expressions checked with actionlint `1.7.11`.

- Android release-mode universal APK compiled successfully with the debug signing key for offline preview installation.
- Android API 35 emulator device flow passed with the actual shader renderer, screenshot capture, favorites, and Arabic/Hebrew quote direction. Emulator screenshots are included in `docs/screenshots/`.
- Android XML and iOS plist/privacy-manifest XML parsed successfully; Python CI scripts passed compilation checks.

The delivered `dist/Shakespeare-Android.apk` is a labelled offline preview, not a production-signed/live-AI distribution. Its build log and SHA-256 checksum are included alongside the artifact. See the README for enabling production outputs.

## Requires external setup

- GitHub-hosted execution: repository created at https://github.com/YoussefElb-Dev/Shakespeare. The initial Android, iOS, and gateway jobs were rejected before any steps ran: GitHub reported failed account payments or a spending-limit block. No hosted IPA has been compiled from these runs.
- iOS compilation/export: the workflow builds an unsigned device IPA for sideloader re-signing without Apple distribution secrets. Hosted compilation and native rendering still need verification.
- Live AI: Gemini free-tier integration is implemented and tested against mocked provider responses. Cloudflare hosting login and a dedicated Google AI Studio key are needed for deployment and a live generation check. Offline builds use clearly labelled sample quotes.
- Production Android signing: requires the owner’s release keystore secrets; local preview APKs use the debug signing key.
- Physical-device refresh-rate, energy, accessibility, multilingual editorial quality, Apple privacy/store review, and distribution eligibility require release-owner validation. Emulator checks cannot establish a measured 60 FPS target on phones.

The repository implements the build pipeline; static checks alone are not presented as proof of hosted signing or native iOS compilation. Use the README’s setup instructions to finish account-dependent verification.
