# Releasing the app

## Signing key

Every version of the app must be signed with the same key, or phones refuse the
update (and the Play Store will need the same key later). Create it once:

```sh
keytool -genkey -v -keystore kamal-bhandar-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias kamal-bhandar
```

Keep `kamal-bhandar-release.jks` and its password in **two** safe places (for
example the owner's Google Drive and a USB stick). Never commit it.

Create `app/android/key.properties` (also never committed):

```properties
storeFile=/full/path/to/kamal-bhandar-release.jks
storePassword=...
keyAlias=kamal-bhandar
keyPassword=...
```

Get the fingerprints for Firebase (see [SETUP.md](SETUP.md#3-register-the-android-app)):

```sh
keytool -list -v -keystore kamal-bhandar-release.jks -alias kamal-bhandar
```

## Building a version

1. Raise the version in `app/pubspec.yaml`, for example `version: 1.0.1+2`
   (the number after `+` must go up every time).
2. Put the live project's `google-services.json` in `app/android/app/`.
3. Deploy server changes first, test project then live:
   `firebase use live && firebase deploy --only firestore,storage,functions`.
4. Build:

   ```sh
   cd app
   flutter build apk --release
   ```

   The file is `app/build/app/outputs/flutter-apk/app-release.apk`.

## Sharing in version 1

Send the APK on WhatsApp or as a Google Drive link. Customers open it and allow
"Install unknown apps" for WhatsApp or Files when Android asks. Updates are
installed the same way, over the old version, and keep the customer signed in.

To make old versions stop working after an important change, set
`minAppVersion` in `settings/store` (the build number after `+`).

## Play Store later

- One-time US$25 developer account in the store's name.
- Build an app bundle with the same key: `flutter build appbundle --release`.
- The listing needs the privacy policy URL (`https://kamal-bhandar.web.app/privacy`),
  the account deletion URL (`https://kamal-bhandar.web.app/delete-account`), the
  Data safety form, screenshots, and the 512 px icon in `docs/app-icon-512.png`.
- New personal developer accounts must run a closed test with at least 12 testers
  for 14 days before going public. Your first customers are ideal testers.
- After launch, turn on App Check (see SETUP.md).
