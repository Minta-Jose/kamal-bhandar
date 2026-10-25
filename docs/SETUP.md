# Setting up Firebase for Kamal Bhandar

Do this once for the test project (`kamal-bhandar-test`) and once for the live
project (`kamal-bhandar`). Everything stays inside the free limits at the
store's size; the card is only needed to turn on Cloud Functions.

You need: a Google account for the store (for example kamalbhandar.store@gmail.com),
a computer with Node.js 22, Java 21 and Flutter 3.47.8, and the Firebase CLI
(`npm install -g firebase-tools`).

## 1. Create the project

1. Go to https://console.firebase.google.com and sign in with the store's Google account.
2. **Add project** → name it `kamal-bhandar-test` (later `kamal-bhandar`). Google Analytics is not needed.
3. **Build › Firestore Database › Create database** → Native mode, location **asia-south1 (Mumbai)**, start in production mode.
4. **Build › Storage › Get started** → location **asia-south1**.
5. **Build › Authentication › Get started › Sign-in method** → enable **Google**. Set the support email to the store's email.

## 2. Turn on pay-as-you-go with a ₹0 guard

1. **Project settings (gear) › Usage and billing › Details and settings › Modify plan** → **Blaze**. Add the card.
2. Open https://console.cloud.google.com/billing → **Budgets and alerts › Create budget**:
   - Scope: this project. Amount: **₹10** per month.
   - Alert thresholds: 50%, 90%, 100%. Email alerts to the store's email.
   - **Connect a Pub/Sub topic**: create a topic called `billing-alerts` in this project.
3. Give the functions permission to switch billing off: in https://console.cloud.google.com/iam-admin/iam,
   find the **Default compute service account** (`…-compute@developer.gserviceaccount.com`) and add the role
   **Project Billing Manager**.

When spend passes ₹10 the `billingKillSwitch` function detaches billing, so no
charge can happen. The app then stops working until billing is turned back on
in the Cloud console (**Billing › Link a billing account**). The limit can be
changed with `KILL_SWITCH_LIMIT_INR` in `functions/.env.<project>`.

## 3. Register the Android app

1. **Project settings › General › Add app › Android**. Package name: `com.kamalbhandar.app`. Nickname: Kamal Bhandar.
2. Add the **SHA-1** and **SHA-256** fingerprints of the signing key (see [RELEASE.md](RELEASE.md#signing-key)).
   Google sign-in fails without them. Add the debug key's fingerprints too while testing:
   `keytool -list -v -keystore ~/.android/debug.keystore -storepass android`.
3. Download `google-services.json` and put it at `app/android/app/google-services.json`.
   It is not committed, because the test and live projects each have their own.
4. For GitHub test builds, add the file's contents as a repository secret named
   `GOOGLE_SERVICES_JSON` (**Settings › Secrets and variables › Actions**).

## 4. Deploy rules, indexes, functions and pages

```sh
firebase login                      # with the store's Google account
firebase use test                   # or: firebase use live
cd functions && npm ci && cd ..
firebase deploy --only firestore,storage,functions,hosting
```

The first functions deploy asks to enable a few Google APIs (Cloud Functions,
Cloud Build, Artifact Registry, Eventarc, Pub/Sub, Cloud Scheduler). Say yes.
Hosting gives you the privacy policy at `https://<project>.web.app/privacy`
and the deletion page at `https://<project>.web.app/delete-account`.

## 5. Nightly backup bucket

```sh
gcloud storage buckets create gs://<project>-backups --location=asia-south1 --project=<project>
# Delete backups older than 30 days
echo '{"rule":[{"action":{"type":"Delete"},"condition":{"age":30}}]}' > lifecycle.json
gcloud storage buckets update gs://<project>-backups --lifecycle-file=lifecycle.json
# Let the functions write exports
gcloud projects add-iam-policy-binding <project> \
  --member=serviceAccount:<project-number>-compute@developer.gserviceaccount.com \
  --role=roles/datastore.importExportAdmin
gcloud storage buckets add-iam-policy-binding gs://<project>-backups \
  --member=serviceAccount:service-<project-number>@gcp-sa-firestore.iam.gserviceaccount.com \
  --role=roles/storage.admin
```

## 6. Make the owner's account the owner

1. Install the app on the owner's phone and sign in with Google once (it will ask for the registration form; just close the app).
2. In the Firebase console, **Project settings › Service accounts › Generate new private key**. Keep this file safe and never commit it.
3. Run:

   ```sh
   cd scripts && npm ci
   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node set-owner-role.mjs owner@gmail.com
   ```

4. On the phone, open the app, sign out and sign in again. The owner screens appear.

Repeat for a staff phone if needed. Remove with `--remove`.

## 7. Starter catalogue (optional)

```sh
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node scripts/seed-catalogue.mjs
```

This adds 7 categories and 23 common products with placeholder prices and no
photos. The owner then sets real prices and takes photos in the **Catalogue** tab.
Fill in the store's address, phone and pickup hours in **Settings**.

## 8. Owner's phone

So order alerts ring straight away, on the owner's phone:

- Allow notifications when the app asks.
- **Settings › Apps › Kamal Bhandar › Battery** → **Unrestricted** (Xiaomi, Oppo, Vivo, Realme: also turn on **Autostart**).
- **Settings › Apps › Kamal Bhandar › Notifications › New orders** → sound on, show on lock screen.

## App Check

The plan uses App Check with Play Integrity to refuse requests from anything but
the genuine app. Play Integrity only recognises apps installed from the Play
Store, so while the app file is shared directly, App Check stays **off**
(security rules and server checks still protect all data). After the Play Store
launch:

1. **Build › App Check** → register the Android app with Play Integrity.
2. Set `ENFORCE_APP_CHECK=true` in `functions/.env.<project>` and redeploy functions.
3. Watch the App Check metrics for a week, then press **Enforce** for Firestore and Storage.
