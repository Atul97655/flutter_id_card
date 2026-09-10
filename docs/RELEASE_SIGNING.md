# Release Signing

Every Android app must be signed. Right now the release build falls back to the
**debug key**, which is fine for handing an APK to the client to install, but:

- the Play Store **rejects** debug-signed uploads, and
- an APK signed with a different key **cannot upgrade over** one already
  installed — the user has to uninstall first, losing local data.

So the switch has to happen before the first Play Store upload, and ideally
before the client installs a build they will want to upgrade later.

Creating the key is **free**. It is generated on this machine; nothing is
purchased and no account is needed.

---

## 1. Create the keystore

`keytool` ships with the JDK, which is already installed here. Run this from
the project root and choose your own password when prompted:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It asks for a password, then some identity fields (name, organisation, city,
country code). Those appear only in the certificate, not in the app — for the
country code use `IN`.

> **Do this yourself rather than having it generated for you.** The password is
> the one credential nobody else should ever hold.

## 2. Point the build at it

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties` and replace both `CHANGE_ME` values with the
password you just chose:

```properties
storeFile=../upload-keystore.jks
storePassword=your-password
keyAlias=upload
keyPassword=your-password
```

Both files are gitignored (`android/key.properties`, `*.jks`), and the build is
written so that when `key.properties` is absent it silently falls back to the
debug key. A fresh checkout still builds.

## 3. Build

```bash
flutter build apk --release
```

Confirm it picked up the real key:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

The owner line should show what you typed in step 1, **not**
`CN=Android Debug`.

---

## ⚠️ Back the keystore up

If `upload-keystore.jks` or its password is lost, **you can never update the
app on the Play Store again** under the same listing. There is no recovery and
no support path — a new key means a new app listing, and existing users do not
carry over.

Keep a copy somewhere that is not this laptop and not the git repo: a password
manager, an encrypted drive, or the client's own safekeeping.

---

## Still outstanding before Play Store

The application ID is still `com.example.flutter_id_card`. Google rejects any
package starting `com.example`, so publishing also needs:

1. A real application ID in `android/app/build.gradle.kts` (both `namespace`
   and `applicationId`).
2. That exact package re-registered in the **ID CardX** Firebase console, and a
   fresh `google-services.json` downloaded into `android/app/`.

Both are free. Do them together — changing the ID without re-registering breaks
Firebase sign-in and sync. This is deliberately left until you are actually
ready to publish, because changing it also forces every existing installation
to be removed and reinstalled.
