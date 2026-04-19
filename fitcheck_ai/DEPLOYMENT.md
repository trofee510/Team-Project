# GRWM deployment checklist

One-time setup to get the 1M-ready infrastructure live. After the first pass,
`ci.yml` + `build-internal.yml` + `release.yml` handle everything incrementally.

## 1. Supabase

1. Run `supabase_schema.sql` against a fresh project (or the idempotent
   `supabase/migrations/20260418000000_hardening.sql` on top of an existing DB).
2. Set function secrets:
   ```
   supabase secrets set \
     SB_URL=https://<ref>.supabase.co \
     SB_SERVICE_ROLE_KEY=... \
     GEMINI_API_KEY=... \
     OPENAI_API_KEY=... \
     CLAUDE_API_KEY=... \
     RC_WEBHOOK_SECRET=<pick a 32-char random string>
   ```
3. Deploy the Edge Functions:
   ```
   supabase functions deploy ai-proxy
   supabase functions deploy rc-webhook
   ```
4. Confirm the bucket split:
   - `grwm-private` = **private** (used for wardrobe + personal fit checks)
   - `grwm-public` = **public** (used for battles + opted-in public fits)

## 2. RevenueCat

1. Create RC project. Add iOS + Android apps.
2. Create entitlement `pro`.
3. Create products `grwm_pro_weekly` ($6.99/wk, 3-day trial) and
   `grwm_pro_annual` ($59.99/yr), attach both to the `pro` entitlement.
4. Create "default" offering containing both packages.
5. In RC → Integrations → Webhooks:
   - URL: `https://<ref>.functions.supabase.co/rc-webhook`
   - Authorization header: `Bearer <RC_WEBHOOK_SECRET from step 1.2>`
6. Copy iOS + Android **public** SDK keys into the app's `.env`:
   ```
   REVENUECAT_IOS_KEY=...
   REVENUECAT_ANDROID_KEY=...
   ```

## 3. Observability

1. Create Sentry project (Flutter). Copy DSN → `.env`:
   ```
   SENTRY_DSN=https://...@sentry.io/...
   ```
2. Create PostHog project. Copy project API key + host → `.env`:
   ```
   POSTHOG_KEY=phc_...
   POSTHOG_HOST=https://us.i.posthog.com
   ```
3. Verify Sentry receives a test event (`flutter run`, throw once, check inbox).
4. In PostHog, build the core funnel dashboard:
   `onboarding_started → instant_fit_scored → sign_up_completed →
    fit_check_succeeded → paywall_viewed → paywall_purchase_succeeded`.

## 4. App store product setup

- Apple App Store Connect:
  - Bundle ID: `app.grwm`
  - Create matching IAP products (weekly + annual), link RC's StoreKit config.
- Google Play Console:
  - Package: `app.grwm`
  - Create matching subscriptions, publish RC integration.
- Deep link for battle invites:
  - iOS Associated Domain: `applinks:grwm.app` (App Links).
  - Android intent-filter for `https://grwm.app/b/*`.

## 5. GitHub Actions secrets

Required:

| Secret | Purpose |
|---|---|
| `ENV_FILE` (base64 of `.env`) | used by internal builds |
| `ENV_FILE_PROD` | used by release builds |
| `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` | Edge Function deploys |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASS`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASS` | Android signing |
| `FIREBASE_APP_ID_ANDROID`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_TESTER_GROUPS` | Internal Android distribution |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console upload |
| `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64` | iOS signing |
| `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_KEY_BASE64` | App Store upload |

## 6. Release cadence

- **PR → main:** `ci.yml` runs analyze + test + Deno check.
- **Push to main:** `build-internal.yml` ships internal Android to Firebase App
  Distribution + iOS to TestFlight, and deploys Edge Functions.
- **Tag `v*.*.*`:** `release.yml` pushes to Play (staged rollout, default 1%)
  and App Store Connect. Ramp via `workflow_dispatch` with
  `rollout_percent=10`, then `50`, then `100`.

## 7. Kill switches

- `public.feature_flags.kill_ai_proxy = true` → clients stop calling the proxy
  (wire this in future — currently the flag table exists and is readable; the
  client-side check is a one-liner on the fit_check entry point).
- `public.feature_flags.force_upgrade_build.payload = {"min_build": N}` → client
  compares to `PackageInfo.buildNumber` and blocks with an upgrade screen.

## 8. Post-launch migration TODOs

Still using raw API keys directly from the client (not yet on the proxy):

- `features/wardrobe/add_item_screen.dart` (item auto-naming)
- `features/my_outfits/my_outfits_screen.dart` (outfit generation)
- `features/style_my_day/style_my_day_screen.dart` (reads bucket)
- `services/background_removal_service.dart`
- `services/claude_service.dart`

Migrate these to `AiProxyService` before you turn up paid-acquisition volume —
every call through them still burns the key in the app bundle.
