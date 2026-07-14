# Release pipeline setup — Firebase, Apple, Codemagic

This is a from-scratch, step-by-step walkthrough for getting **Leasely**
(repo/code name `homies_mobile`, bundle id `com.kai.poems`) building and
shipping to TestFlight. It covers the three platforms you need to touch
(Firebase console, Apple Developer / App Stor[text](vscode-webview://12ercnopgftbc11o9lkkihon7hqoqtvvf4s35hgcd0ka8l84vkbp/release-setup/README.md)e Connect, Codemagic) and
exactly what already lives in this repo for each one, so you're not guessing
what's done vs. missing.

**Read this first:** most of this is *already configured* — this app has
shipped TestFlight builds before under this exact bundle id. Every part below
starts with a "confirm it already exists" step before a "create it" step —
do the confirm step first. Don't recreate anything that already exists (a
duplicate Firebase app, a second App Store Connect listing, a new keystore)
— duplicates are the main way this kind of setup gets tangled.

Key identifiers you'll see reused everywhere below:

| Thing | Value |
|---|---|
| Firebase project | `leasely-a11e4` |
| iOS bundle id | `com.kai.poems` |
| Android package name | `com.kai.poems` |
| App Store Connect Apple ID (numeric) | `6781926631` |
| Public app name | Leasely |
| Codemagic App Store Connect integration name | `Leasely` |

## Order of operations

Do these in order — each later part depends on IDs/files produced by the
earlier one:

1. **Firebase console** (Part A) — confirm/create the apps, pull config files.
2. **Apple Developer + App Store Connect** (Part B) — confirm/create the App
   ID and app record, get the API key Codemagic needs.
3. **Codemagic** (Part C) — wire up signing + the App Store Connect API key,
   run a build.
4. **VS Code / the repo** (Part D) — checklist confirming the repo matches
   what you did in steps 1–2.

---

## Part A — Firebase console

This app only uses **Authentication** (email/password), **Cloud Firestore**,
and **Storage** — no Firebase Cloud Messaging/push, so there's no APNs key or
push entitlement to set up anywhere in this guide.

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
   and open project **`leasely-a11e4`**.
2. Click the **gear icon → Project settings**.
3. Scroll to **Your apps**. Confirm you see three entries:
   - An **iOS** app with bundle id `com.kai.poems`
   - An **Android** app with package name `com.kai.poems`
   - A **Web** app
4. **If the iOS app for `com.kai.poems` is missing:**
   1. Click **Add app → iOS** (the Apple icon).
   2. Enter bundle ID `com.kai.poems`, any nickname (e.g. "Leasely iOS"),
      leave App Store ID blank for now.
   3. Click **Register app**, then **Download `GoogleService-Info.plist`**.
   4. Replace the file at
      [`frontend_app/ios/Runner/GoogleService-Info.plist`](../frontend_app/ios/Runner/GoogleService-Info.plist)
      with the one you downloaded.
   5. Click through the remaining "Add Firebase SDK" steps and press
      **Continue to console** — you don't need the code snippets, this repo
      already has the SDK wired up.
5. **If the Android app for `com.kai.poems` is missing:**
   1. Click **Add app → Android**.
   2. Enter package name `com.kai.poems`, any nickname.
   3. Click **Register app**, then **Download `google-services.json`**.
   4. Replace the file at
      [`frontend_app/android/app/google-services.json`](../frontend_app/android/app/google-services.json).
   5. Click **Continue to console**.
6. **If both already exist** (they should — those two files already contain
   `com.kai.poems` entries): click into each app's settings and copy its
   **App ID** (format `1:579052656220:ios:xxxxxxxx` /
   `1:579052656220:android:xxxxxxxx`). You'll cross-check these in Part D.
7. Confirm sign-in is enabled: left sidebar **Build → Authentication →
   Sign-in method** tab → **Email/Password** should show "Enabled". If not,
   click it → toggle **Enable** → **Save**.
8. Confirm Firestore exists: left sidebar **Build → Firestore Database**. If
   it says "Create database", click it, choose **production mode**, pick a
   region, click **Enable**. Then deploy this repo's rules so it's not wide
   open — from `backend/database/`, run:
   ```
   firebase deploy --only firestore:rules --project leasely-a11e4
   ```
9. Confirm Storage exists: left sidebar **Build → Storage**. Same idea — if
   missing, click **Get started**, accept the defaults. Deploy this repo's
   rules from `backend/storage/`:
   ```
   firebase deploy --only storage:rules --project leasely-a11e4
   ```
10. Generate the service-account key the admin backend needs (this is
    separate from the client config files above):
    1. **Project settings → Service accounts** tab.
    2. Click **Generate new private key** → confirm → it downloads a JSON
       file.
    3. Open that JSON file, copy its **entire contents**.
    4. Wherever `backend/admin-api` is deployed (Render dashboard → your
       service → **Environment**), paste the whole JSON as the value of
       `FIREBASE_SERVICE_ACCOUNT`.
    5. **Do not commit this JSON file to the repo** — delete it from your
       Downloads folder once it's pasted in.

---

## Part B — Apple Developer + App Store Connect

### B1. App ID

1. Go to [developer.apple.com/account](https://developer.apple.com/account).
2. **Certificates, IDs & Profiles → Identifiers** (left sidebar).
3. Search for `com.kai.poems`. If it's listed, you're done with B1.
4. If it's not listed:
   1. Click the **+** next to Identifiers.
   2. Select **App IDs → Continue → App**.
   3. Description: "Leasely". Bundle ID: **Explicit**, enter
      `com.kai.poems`.
   4. Leave all Capabilities unchecked (this app doesn't use push, Sign in
      with Apple, or associated domains).
   5. Click **Continue → Register**.

### B2. App Store Connect app record

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) →
   **My Apps**.
2. Look for an app whose bundle id is `com.kai.poems`. Click into it → **App
   Information** (left sidebar) → check the **Apple ID** field near the top.
   Confirm it reads `6781926631` (this is the numeric id
   `codemagic.yaml`'s `APP_STORE_APPLE_ID` refers to — not the bundle id).
3. If no such app exists:
   1. **My Apps → the + in the top-left → New App**.
   2. Platform: **iOS**. Name: `Leasely`. Primary language: your choice.
   3. Bundle ID: select `com.kai.poems` from the dropdown (it only appears
      here after B1 is done).
   4. SKU: any unique string you won't reuse elsewhere, e.g. `leasely-ios-01`.
   5. Click **Create**.
   6. Go to **App Information** and copy the **Apple ID** it was assigned.
      If it isn't `6781926631`, open [codemagic.yaml](../codemagic.yaml) and
      update the `APP_STORE_APPLE_ID` value under the `ios-release` workflow
      to match.
4. Export compliance is already handled without a manual prompt during
   submission — `ITSAppUsesNonExemptEncryption: false` is already set in
   [Info.plist](../frontend_app/ios/Runner/Info.plist), so you can skip any
   encryption questionnaire step here.

### B3. App Store Connect API key (what Codemagic uses)

This is a *different* key from the Firebase service account in A10 — it's
what lets Codemagic act on your behalf in App Store Connect (create signing
certs/profiles, check the latest build number, upload to TestFlight).

1. In App Store Connect, click **Users and Access** (top nav).
2. Go to the **Integrations** tab → **App Store Connect API** (left side).
3. If a key already exists for this purpose, note its **Key ID** and
   **Issuer ID** (shown at the top of the page) and skip to Part C — you
   don't need a new one.
4. If you need a new one: click the **+** to generate a key.
   1. Name: anything, e.g. "Codemagic CI".
   2. Access: **App Manager**.
   3. Click **Generate**.
   4. Click **Download API Key** — **you only get one chance**, Apple won't
      let you re-download the `.p8` file later.
   5. Note the **Key ID** and the **Issuer ID** (top of the Integrations
      page) — you'll need both plus the `.p8` file in Part C2.

---

## Part C — Codemagic

1. Go to [codemagic.io](https://codemagic.io) and sign in to your team.

### C1. Repo connection

1. Left sidebar → **Apps**.
2. Confirm this repo already shows up in the list (it should, given prior
   builds). If not: click **Add application** → pick the Git provider → pick
   this repo → Codemagic will detect the existing
   [`codemagic.yaml`](../codemagic.yaml) and list the `ios-release` and
   `android-release` workflows automatically.

### C2. App Store Connect integration

1. **Team settings** (bottom-left, or your team name) → **Integrations**.
2. Find **App Store Connect**. Confirm an integration named exactly
   **`Leasely`** exists — that's the name `codemagic.yaml` looks up via
   `integrations: app_store_connect: Leasely`.
3. If it's missing:
   1. Click **Connect** (or **Add key**) under App Store Connect.
   2. Paste the **Issuer ID**, **Key ID**, and upload the `.p8` file from
      B3.
   3. Name it exactly `Leasely` — or, if you name it something else, open
      [codemagic.yaml](../codemagic.yaml) and change
      `integrations: app_store_connect: Leasely` to match.

### C3. Environment variable groups

**Team settings → Environment variables**. `codemagic.yaml` references two
groups by name — both need to exist with these exact variable names:

1. Click **Add group**, name it `ios_signing`.
2. Add variable `CERTIFICATE_PRIVATE_KEY`:
   - If one already exists here, leave it — don't regenerate it (that would
     invalidate the certificate tied to it).
   - If it's genuinely missing, generate one locally:
     ```
     openssl genrsa -out cert_key 2048
     base64 -i cert_key
     ```
     Paste the base64 output as the variable's value. Mark it **Secret**.
   - (This key is unrelated to the App Store Connect API key from B3 — it's
     what the "Set up code signing" script in `codemagic.yaml` passes to
     `app-store-connect fetch-signing-files --certificate-key=@file:...` to
     request a new distribution certificate.)
3. Click **Add group** again, name it `android_signing`.
4. Add four variables, all marked **Secret**:
   - `CM_KEYSTORE` — base64 of your `.jks` upload keystore:
     `base64 -i upload-keystore.jks`
   - `CM_KEYSTORE_PASSWORD`
   - `CM_KEY_ALIAS`
   - `CM_KEY_PASSWORD`

   ⚠️ **Before generating a new keystore, check whether this app has ever
   been uploaded to Google Play Console before.** If it has, you must reuse
   that exact `.jks` file and password — Play Store permanently binds a
   package name to the signing key from its first upload and will reject
   any update signed with a different key, with no way to undo it. Only run
   this if it's a genuine first-ever upload for `com.kai.poems`:
   ```
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias <your-alias>
   ```

### C4. Run a build

1. **Apps → Leasely** (or whatever this app is named in Codemagic) →
   **Start new build**.
2. Workflow: **ios-release**. Branch: `main`. Click **Start new build**.
3. Watch the build steps in order:
   - **Get Flutter packages**
   - **Install CocoaPods dependencies**
   - **Set up code signing** ← if B1–B3 or C2–C3 are wrong, it fails *here*
     with a specific Apple API error (missing App ID, invalid key, expired
     cert) — read that error rather than guessing.
   - **Set build number**
   - **Build signed IPA**
4. On success it uploads to TestFlight automatically
   (`submit_to_testflight: true`, `submit_to_app_store: false` — so it won't
   go to the public App Store on its own).
5. Repeat with workflow **android-release** if you also need an Android
   build. It produces a signed `.aab` as a build artifact — there's no
   `publishing:` block for Android yet, so you upload it to Play Console
   manually.

---

## Part D — Verify in the repo (VS Code)

Everything below should already match after the fixes made earlier in this
project — treat this as a checklist to confirm, not a to-do list to redo:

1. Open [`frontend_app/ios/Runner.xcodeproj/project.pbxproj`](../frontend_app/ios/Runner.xcodeproj/project.pbxproj)
   and confirm every `PRODUCT_BUNDLE_IDENTIFIER` is `com.kai.poems` (there
   are several — Debug/Release/Profile × Runner/RunnerTests).
2. Open [`frontend_app/android/app/build.gradle.kts`](../frontend_app/android/app/build.gradle.kts)
   and confirm `applicationId = "com.kai.poems"`.
3. Open [`frontend_app/ios/Runner/GoogleService-Info.plist`](../frontend_app/ios/Runner/GoogleService-Info.plist)
   and confirm `BUNDLE_ID` is `com.kai.poems`.
4. Open [`frontend_app/android/app/google-services.json`](../frontend_app/android/app/google-services.json)
   and confirm there's a `client` entry with `package_name` `com.kai.poems`.
5. Open [`frontend_app/lib/firebase_options.dart`](../frontend_app/lib/firebase_options.dart)
   and confirm `ios.appId` matches the iOS app's App ID from Part A step 6,
   `ios.iosBundleId` is `com.kai.poems`, and `android.appId` matches the
   Android app's App ID — **not** the old `au.com.creyeti.*` ones.
6. Open [`frontend_app/ios/Runner/Info.plist`](../frontend_app/ios/Runner/Info.plist)
   and confirm `CFBundleDisplayName` is `Leasely`,
   `NSLocationWhenInUseUsageDescription` is present, and
   `ITSAppUsesNonExemptEncryption` is `false`.
7. Open [`codemagic.yaml`](../codemagic.yaml) and confirm `BUNDLE_ID` is
   `"com.kai.poems"` and `APP_STORE_APPLE_ID` matches what you found/created
   in Part B2.
8. Open [`frontend_app/lib/main.dart`](../frontend_app/lib/main.dart) and
   confirm the Firebase init / state load / notification setup are wrapped
   so a failure or hang can't permanently block the first frame from
   rendering (this was the black-screen fix from earlier).

**Alternative to steps 3–5 (hand-editing):** if you'd rather regenerate
`firebase_options.dart` the official way instead of trusting the manual edit,
run this from `frontend_app/`:

```
dart pub global activate flutterfire_cli
flutterfire configure --project=leasely-a11e4 --platforms=ios,android,web
```

It detects the existing `com.kai.poems` apps in Firebase and regenerates the
file for you — when it prompts you to select apps, pick the existing ones,
don't let it create new ones.

---

## If a build still fails or the app still shows a black screen

- **Codemagic build fails** → open the failing step's log. The "Set up code
  signing" step surfaces the actual Apple API error text (expired key,
  bundle id not found, etc.) — that's almost always more specific than
  anything in this doc.
- **App installs via TestFlight but shows a black screen** → there's no
  console access from a TestFlight install by default. Connect the iPhone to
  a Mac with a cable, open **Xcode → Window → Devices and Simulators**,
  select the device, and click **Open Console** — this captures OS-level
  logs live as you relaunch the app. `print()` output only shows for
  debug/profile builds, but native crashes and Firebase SDK warnings show up
  regardless of build type.
