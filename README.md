# DEPAR

Flutter and Firebase football match organizer.

## Local configuration

Run `flutter pub get`. Flutter no longer loads or bundles `.env`. Places search, place photos and Static Maps use the authenticated `placesProxy` backend, whose API key belongs in Secret Manager. The proxy is disabled until separately configured and deployed; cached venues remain usable and the app explains when live search is unavailable. Existing ignored `.env` files are not modified.

For Android Maps, set `MAPS_API_KEY` in `android/local.properties`. Restrict that key to the Android package `com.depar.app` and the appropriate signing certificate fingerprints.

For iOS Maps, copy `ios/Flutter/Secrets.xcconfig.example` to `ios/Flutter/Secrets.xcconfig` and set `MAPS_API_KEY` to an iOS bundle ID restricted Maps SDK key for `com.depar.app`. This file is gitignored. Without it, the app can build, but its map will report that it is unavailable. Both Debug and Release xcconfigs include the local file. The app version and build number come from `pubspec.yaml` through Flutter's generated xcconfig.

## Android release signing

Create an upload keystore and keep its password and file outside the repository. Add `android/key.properties` locally:

```properties
storeFile=path/to/upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

`storeFile` is resolved relative to `android/`, or may be an absolute path. `android/key.properties` and keystores are gitignored. `flutter build appbundle --release` requires all four properties and an existing keystore; it stops with a setup message if either is missing. Debug builds do not require release signing. Before first Play upload, verify the upload and Play app-signing SHA-1 values in Firebase and refresh `google-services.json` if needed.

## iOS build and distribution

The current publication target is iOS/App Store only. Google Play setup and Android signing are not prerequisites for this release.

The manual GitHub Actions workflow uses Flutter 3.41.4, matching the locally verified SDK, and runs `flutter build ios --release --no-codesign` on macOS. It uploads an **unsigned `Runner.app` build check**. It does not produce an IPA suitable for TestFlight or the App Store. The optional `IOS_MAPS_API_KEY` repository secret supplies the native Maps SDK key; restrict it to the iOS bundle ID and Maps SDK API. `APP_ENV` is no longer read. The workflow never logs key values. Server proxy secrets must never be supplied as mobile build secrets.

For distribution, configure an Apple Developer team, distribution certificate, provisioning profile, and App Store Connect credentials on a trusted Mac or signing runner, then use Flutter's signed `flutter build ipa`. Keep the archive and dSYMs. When Crashlytics reporting is enabled, add and verify Firebase's iOS Crashlytics dSYM upload run script in Xcode with its required Xcode 15 input files, or upload archive dSYMs manually. This has not been configured or verified on Windows. Crashlytics native automatic collection defaults to off on both platforms; app code must explicitly enable it when approved. Review the generated Xcode privacy report and App Store Connect privacy answers before submission, including Crashlytics data if enabled and SDK manifests. The `ITSAppUsesNonExemptEncryption=NO` declaration assumes only exempt standard platform/Firebase transport encryption; recheck it if cryptography dependencies change.
