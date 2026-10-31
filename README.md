# Shakespeare

A Flutter quote studio for iOS and Android, based on the supplied dark, liquid-orb reference. One shared interface: near-black surfaces, restrained typography, translucent controls, and an interactive GPU-rendered orb. No oversized app title on the home screen.

Includes original AI quote generation through a server-side gateway; nine categories; twelve languages; four lengths; eight tones; regeneration; copy and native sharing; haptics; local favorites, history, and settings. Arabic and Hebrew have translated interfaces and RTL layouts. Egyptian Arabic uses its own original colloquial generation instructions. Urdu quotes also use RTL. Other languages use the English interface. Fonts and icons are bundled; no runtime font downloads.

**Start with GitHub Actions:** push this repository to a GitHub repository’s `main` branch. Open **Actions → Android APK / iOS IPA → Run workflow**. Download successful outputs from the run’s **Artifacts** section. You do not need a local Android or Apple development environment to use these workflows.

This checkout is published at [YoussefElb-Dev/Shakespeare](https://github.com/YoussefElb-Dev/Shakespeare). Its public repository uses standard GitHub runners. The Gemini free-tier gateway is deployed, and the repository’s `QUOTE_API_URL` variable is configured for live generation. The Google AI Studio key is an encrypted Cloudflare Worker secret; it is absent from source and mobile binaries.

Without a gateway endpoint, both apps use a clearly labelled offline preview. Without Android signing secrets, the APK uses a disposable debug signing key. Without Apple distribution secrets, iOS validates a simulator app and builds an unsigned ARM64 **device IPA** for re-signing with Sideloadly or AltStore Classic. The separate simulator ZIP cannot run on an iPhone. A configured endpoint enables live AI independently of distribution signing. See [validation status](docs/VALIDATION.md) for what has actually been tested.

Rendered Android screens: [home](docs/screenshots/home.png), [categories](docs/screenshots/categories.png), [customization](docs/screenshots/customize.png), [English](docs/screenshots/english.png), [Arabic](docs/screenshots/arabic.png), [Hebrew](docs/screenshots/hebrew.png).

For personal sideloading, no Apple certificate is needed in GitHub. Download the `Shakespeare-iOS-Unsigned-Sideload` artifact, extract the IPA, and import it into your sideloading tool. That tool must sign it using your Apple account. AI access still needs the Gemini gateway endpoint.

## GitHub build setup

1. Create an empty GitHub repository. Commit these files (`git add .` then `git commit -m "Build Shakespeare"`), add the repository as `origin`, and push to `main` (`git push -u origin HEAD:main`). If using the source ZIP, run `git init` first. No account credentials or remote repository are included.
2. The workflows run on pushes to `main`, pull requests, manual dispatch, and `v*` tags. Pull requests never install signing credentials. Fork PRs use preview mode when secrets are unavailable.
3. Deploy the [AI gateway](backend/README.md). Set `QUOTE_API_URL` in **Settings → Secrets and variables → Actions**, as a secret or repository variable, to the full HTTPS endpoint, e.g. `https://your-worker.your-subdomain.workers.dev/v1/quotes`. This is a public endpoint, not an AI provider key.
4. Configure the signing secrets below for production outputs. Incomplete signing configurations fail with a clear error. With no signing secrets, validation and preview builds still run. Signed builds fail if `QUOTE_API_URL` is missing; offline previews are never attached as production releases.
5. Download `Shakespeare-Android.apk` and `Shakespeare-iOS-Unsigned.ipa` for sideloading (or `Shakespeare-iOS.ipa` when Apple distribution signing is configured) from Actions artifacts. The workflow summary explains exactly what was built and how it was signed. SHA-256 checksums accompany production outputs and Android previews.

### Android signing secrets

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 of the **release** `.jks` keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing key alias |
| `ANDROID_KEY_PASSWORD` | Signing key password |

Keep a secure backup of the release keystore. A preview APK uses a disposable debug key, so uninstall an older preview if Android reports a signing conflict. Preview builds are not Play Store releases. The release APK is built in release mode with shrinking enabled by Flutter’s toolchain.

To create a new release keystore locally, use `keytool -genkeypair -v -keystore shakespeare-release.jks -alias shakespeare -keyalg RSA -keysize 2048 -validity 10000` and follow its password prompts. Never commit the resulting file. For Google Play, use the manual workflow’s `build_aab` option; signed tag builds also generate `Shakespeare-Android.aab` automatically.

### Apple signing secrets

| Secret | Value |
|---|---|
| `IOS_CERTIFICATE_BASE64` | Base64 of an Apple Distribution certificate **and its private key**, exported as `.p12` |
| `IOS_CERTIFICATE_PASSWORD` | The `.p12` export password |
| `IOS_PROVISION_PROFILE_BASE64` | Base64 of a matching distribution `.mobileprovision` profile |
| `APPLE_TEAM_ID` | Your Apple Developer team ID |

The workflow validates the profile’s expiration, team, bundle identifier, and distribution method; imports the certificate into an ephemeral keychain; signs Runner; and exports the IPA. Cleanup always removes signing files and restores the keychain search list.

Optional repository variables:

| Variable | Default / purpose |
|---|---|
| `IOS_BUNDLE_ID` | `app.shakespeare.shakespeare`; register this ID with Apple or set your own |
| `IOS_EXPORT_METHOD` | `release-testing` for an Ad Hoc profile with registered device UDIDs; `app-store-connect` for an App Store distribution profile |

Manual runs can override the export method. For `release-testing`, only devices listed in the provisioning profile can install the IPA. Use Apple Configurator or another Apple-supported Ad Hoc distribution method. An `app-store-connect` IPA is for upload to App Store Connect; it is not directly installable. Upload it with Apple Transporter, then distribute through TestFlight/App Store review. This repository does not automatically submit builds to TestFlight. That optional integration would require an App Store Connect API key ID, issuer ID, and private `.p8` key; none are required for IPA export itself.

To encode a file on macOS/Linux: `base64 < file.p12 | tr -d '\n'`. On PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\file.p12'))`. Paste that value into the matching GitHub secret; do not save it in the repository.

### Versioned releases

Set `version:` in `pubspec.yaml` for regular builds. Push a tag such as `v1.0.0` to override the app version for that release; tags must use `vMAJOR.MINOR.PATCH`. Each platform uses its workflow run number as the build number.

Successful **signed** tag builds create or update the corresponding GitHub Release and attach their APK/AAB/IPA plus checksums. Each platform publishes independently as its build finishes, so a release can temporarily contain only one platform. Actions artifacts are uploaded even without a tag. No production release is created from unsigned simulator or debug-key preview outputs. Release jobs use the built-in `GITHUB_TOKEN` with narrowly scoped `contents: write`; no personal access token is required. Organization policies must permit workflow-created releases.

## Pinned toolchains

| Component | Version |
|---|---|
| Flutter / bundled Dart | `3.38.10` / `3.10.9` |
| Android CI runner | `ubuntu-24.04` |
| Java (CI) | Temurin `17.0.17+10` |
| Android SDK / build tools | API `36` / `36.0.0` (AGP may also resolve its default build tools) |
| NDK / Gradle / AGP / Kotlin | `28.2.13676358` / `8.14` / `8.11.1` / `2.2.20` |
| iOS runner / Xcode / CocoaPods | `macos-26` / `26.2` / `1.16.2` |
| Node / pnpm / Wrangler | `22.16.0` / `10.28.0` / `4.61.1` |

Minimums: Android 7.0/API 24 and iOS 15. Native UIKit `UIGlassEffect` is used for eligible iOS 26+ surfaces; earlier iOS and Android use the shared Flutter-rendered glass treatment. Xcode 26+ is required to compile the native integration. Hosted runner images change: if a pinned Xcode is retired, update its path/version deliberately; the job will fail clearly instead of silently changing toolchains.

Application dependencies are committed in `pubspec.lock`; gateway dependencies in `backend/pnpm-lock.yaml`. CI enforces both locks. CocoaPods resolves native plugin dependencies on macOS; this Windows-authored repository does not claim a validated CocoaPods lockfile. Commit the generated `ios/Podfile.lock` after the first successful macOS run if strict native dependency reproduction is needed.

## Local development

Install the pinned Flutter SDK and the platform toolchain. A Mac with Xcode is required for local iOS builds.

```sh
flutter pub get --enforce-lockfile
flutter run --dart-define=PREVIEW_MODE=true
```

Preview mode is an explicitly labelled, small offline collection of romance samples in all twelve languages. Category, tone, length, and custom inspiration become generation controls when connected to the gateway. Preview samples are never claimed to be AI-generated. With no URL, local builds default to preview mode; you can explicitly disable it to test missing-configuration handling.

```sh
flutter run --dart-define=PREVIEW_MODE=false --dart-define=QUOTE_API_URL=https://YOUR-HOST/v1/quotes
flutter build apk --release --dart-define=PREVIEW_MODE=false --dart-define=QUOTE_API_URL=https://YOUR-HOST/v1/quotes
# On macOS, after installing your Apple signing assets:
flutter build ipa --release --export-options-plist=/path/to/ExportOptions.plist --dart-define=PREVIEW_MODE=false --dart-define=QUOTE_API_URL=https://YOUR-HOST/v1/quotes
```

For local Android release signing, create ignored `android/key.properties` with `storeFile` (absolute keystore path), `storePassword`, `keyAlias`, and `keyPassword`. Without this file, local release-mode APKs use the debug key for testing. The workflow writes this file securely from secrets.

Install an Android APK using `adb install -r Shakespeare-Android.apk`, or download it on the device and allow installation from the browser/file manager when prompted. The Android app requires internet access only for live generation; local collections remain available offline.

## Validation

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze --fatal-infos
flutter test --coverage
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d YOUR_DEVICE_ID
cd backend
pnpm install --frozen-lockfile
pnpm test
pnpm check
```

The device integration test captures home, categories, customization, generation, and English/Arabic/Hebrew quote screens into ignored `artifacts/screenshots/`. Do not run native builds and device tests simultaneously in the same checkout: Flutter regenerates native plugin registrations per build mode.

Run `python3 -m unittest discover -s scripts/ci -p '*_test.py'` to check signing/build configuration gates without credentials. Workflow validation also runs these checks. Optional asset maintenance tools use Pillow/NumPy for icons and fonttools to freeze quote fonts at readable regular weights. These tools are not needed to compile the committed application.

The orb uses a custom fragment shader, isolated repainting, pointer response, and a procedural fallback. Animation stops in the background and honors Reduce Motion. It targets native display refresh where practical; real-device GPU profiling is still required before making a measured 60 FPS claim. See [architecture](docs/ARCHITECTURE.md) and [validation status](docs/VALIDATION.md).

## Repository layout

```text
lib/                 Flutter domain, persistence, generation client, and shared UI
shaders/             GPU liquid orb
assets/              Bundled fonts, font licenses, and app icon
android/  ios/       Complete native projects and iOS glass bridge
backend/             Deployable Cloudflare Worker and persistent quota gate
.github/workflows/   Android, iOS, and gateway validation workflows
scripts/ci/          Signing, build configuration, release publishing, cleanup
test/                Service, persistence, cancellation, and UI tests
integration_test/    Device flow and renderer screenshots
tool/                Optional procedural icon generator
docs/                Architecture, deployment limitations, and validation record
```

Favorites and history remain on the device; history retains the latest 200 quotes. Prompts/options are sent only when generating live quotes. The backend uses Gemini and does not log quote content or raw client IPs. Google may use free-tier prompts and responses to improve its products; avoid sensitive prompts. Publish your own privacy policy and complete platform privacy disclosures for your deployed service before store submission. The in-app privacy explanation is included.

Implementation references: [Flutter shader documentation](https://docs.flutter.dev/ui/design/graphics/fragment-shaders), [Gemini structured outputs](https://ai.google.dev/gemini-api/docs/generate-content/structured-output), [Gemini free-tier pricing](https://ai.google.dev/gemini-api/docs/pricing), [Apple Liquid Glass](https://developer.apple.com/documentation/uikit/uiglasseffect), [GitHub hosted runners](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).
