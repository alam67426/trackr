# Trackr Handover

## Project Snapshot

- **Product:** Trackr, a local-first Android expense tracker for Indian users.
- **Framework:** Flutter/Dart with Riverpod state management.
- **Current version:** `1.6.20+34`.
- **Android package:** `com.trackr.app`.
- **Latest release APK:** `build/app/outputs/flutter-apk/app-release.apk`.
- **Data model:** local only. Transaction, pending, profile, reimbursement, budget, and merchant-learning records use `flutter_secure_storage` with Android encrypted shared preferences.
- **Cloud/online AI:** none. Insights and categorisation are rule based and local.

## How To Run

1. Open `C:\Users\Alpha\Documents\New project\Trackr` as the Flutter project.
2. Ensure Flutter and Android SDK are configured:
   ```powershell
   flutter doctor
   ```
3. Fetch dependencies:
   ```powershell
   flutter pub get
   ```
4. Start an Android emulator or connect an Android phone with USB debugging enabled.
5. Run the app:
   ```powershell
   flutter run
   ```
6. Run focused regression tests:
   ```powershell
   flutter test test\sms_filters_test.dart test\insight_engine_test.dart
   ```
7. Build a release APK:
   ```powershell
   flutter build apk --release --android-skip-build-dependency-validation
   ```

The resulting APK is at `build\app\outputs\flutter-apk\app-release.apk`.

## Updating Existing Phones

- Increase `version` in `pubspec.yaml` for every release.
- Install the new APK over the existing Trackr app. Do **not** uninstall first.
- Keeping the same `applicationId` (`com.trackr.app`) and the same release signing key preserves local app data.
- Release signing uses `android/key.properties` and `android/trackr-upload.jks`. These must be kept private and backed up securely. They are intentionally ignored by `.gitignore`.

## Architecture

```text
lib/
  main.dart                         App bootstrap; notifications and local AI warm-up
  app.dart                          Application shell, navigation, detection orchestration
  models/                           Transaction, pending, profile, budget, reimbursement models
  providers/                        Riverpod state and persistence coordination
  screens/                          Home, Transactions, Pending, Budgets, Analytics, Export, Settings, Profile
  services/                         Storage, parsing, detection, notifications, reports, insights
  widgets/                          Shared UI and screen-specific widgets
  data/sarcastic_insights.dart      Local Hinglish/English insight messages
  utils/                            Categories, formatting, validators, SMS filtering
android/
  app/src/main/AndroidManifest.xml  SMS and notification permissions/components
  app/src/main/kotlin/...           Notification listener bridge and Android activity
third_party/telephony/              Local patched telephony package used for SMS background handling
test/
  sms_filters_test.dart             SMS filtering/parser regression coverage
  insight_engine_test.dart          Local insight-engine coverage
```

## Main Features Already Implemented

- Manual expense, income, and transfer entry.
- Split expenses with equal/custom participant shares and reimbursement tracking.
- Dashboard: selected-month summary, today total, category chart, budget status, recent ten transactions, local sarcastic insights.
- Transactions: search, filter, sort, edit, delete.
- Budgets: overall and category budgets with alerts.
- Analytics: trends, category breakdown, local insight cards and detail views.
- PDF and CSV export. PDFs contain optional profile information and red/green/teal expense/income/savings totals.
- Optional local profile, with validation only when age, Indian phone number, or email is supplied.
- SMS detection for generic Indian-bank/UPI debit and credit alerts.
- Optional business-notification detection from Truecaller, Google Messages, and Samsung Messages.
- Pending Review workflow with Confirm, Edit, Reject, Confirm All, and Reject All.
- Android notification for qualifying Pending SMS, including a background SMS handler.

## SMS Detection Flow

1. User enables **SMS auto-detection** in Settings and grants SMS/notification permissions.
2. `SMSListener` receives SMS in foreground or `backgroundSmsHandler` receives it while Trackr is inactive.
3. `SMSFilter` rejects OTPs, promotions, failures, collect/payment requests, and future e-mandate reminders.
4. `SMSParser` extracts amount, direction, merchant, date/time, bank, account digits, and UPI/UTR/reference number.
5. Qualifying transactions go to encrypted Pending storage.
6. The user must confirm them unless trusted automatic detection is enabled and confidence is at least `0.97`.

Important files:

- `lib/utils/sms_filters.dart`: qualification and rejection rules.
- `lib/services/sms_parser.dart`: amount/date/merchant/reference parsing and deduplication fingerprints.
- `lib/services/sms_listener.dart`: foreground/background SMS paths.
- `lib/providers/pending_provider.dart`: Pending lifecycle, history checks, Confirm/Reject ledger.

## Deduplication Design

Current deduplication uses:

1. UPI reference/UTR/transaction reference when both messages expose it.
2. Fallback identity: transaction direction, amount, normalized merchant, bank, account digits, and date.
3. Normalized raw SMS body.
4. A resolved ledger recorded on Confirm and Reject.
5. Cleanup on Pending load: removes rows already resolved, already confirmed in history, duplicate Pending records, and mandate reminders.

### Current Known Issue / Highest-Priority Follow-Up

Users have still reported occasional stale Pending entries after several Confirm/Reject actions. The latest code (`1.6.20+34`) adds a stronger resolved identity ledger and e-mandate filtering, but this must be verified on a real phone after installation.

Recommended Antigravity task:

1. Add a dedicated `pending_provider_test.dart` using an injectable storage fake.
2. Test foreground and background flows for:
   - same raw SMS twice;
   - same reference with different SMS delivery time;
   - Confirm then resend;
   - Reject then resend;
   - old Pending row that remains after an action;
   - e-mandate reminder followed by an actual debit.
3. Consider replacing the string-set ledger with a small structured resolved-record model containing reference, identity, action, and resolution time.
4. Apply retention limits by oldest timestamp, not `Set.first`, because `Set` order should not be relied on for audit retention.

## Current Financial Calculation Rule

- **Spent:** expense transactions in the selected month.
- **Income:** income transactions in the selected month.
- **Available/Savings:** income minus expense.
- **Transfers:** excluded from normal income/expense totals.
- **Reimbursements:** tracked separately and shown in settlement figures; they do not become salary/normal income.

If a credit transaction is not included in Income, inspect:

1. `SMSParser.isReceived()` and `SMSFilter.hasCreditSignal()`.
2. The parsed transaction type in Pending Review.
3. Whether its transaction date falls in the currently selected month.
4. Any manual edit that changed its type to Transfer or Expense.

## Android Permissions And Native Components

- `READ_SMS` and `RECEIVE_SMS`: required for auto-detection.
- `POST_NOTIFICATIONS`: used for Pending Review and budget alerts.
- `TrackrNotificationListener`: optional Android Notification Listener for supported business chat apps.
- Native notification-access bridge: `android/app/src/main/kotlin/com/trackr/app/MainActivity.kt`.

## Security Notes

- Main app records use encrypted shared preferences via `flutter_secure_storage`.
- No cloud request or external AI provider is configured.
- PDFs/CSVs are produced locally, then shared only by user action.
- The notification listener currently keeps up to 50 bank-like notification bodies in native standard SharedPreferences until Trackr consumes them. This is a security improvement target: only store while the business-chat setting is enabled, use encrypted storage, and wipe the queue when disabled or when Clear All Data is selected.
- Add optional biometric/PIN lock and screenshot protection before a public release handling sensitive financial data.
- Set explicit Android backup rules/disable backup after deciding the desired recovery policy.

## Test SMS In Android Emulator

The Android emulator uses a numeric SMS sender, so include the bank name in the SMS body:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" emu sms send 5556 "Central Bank of India: A/c XX6789 debited by Rs. 1,500.00 on 01-08-2026 at 14:30 to Amazon. UPI Ref 4000000001"
```

For a credit example:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" emu sms send 5556 "Bandhan Bank: A/c XX1234 Cr. INR 5,000.00 on 01/08/2026 from Freelance. UPI Ref 3000000010"
```

Keep Trusted automatic detection disabled while testing so valid SMS messages appear in Pending Review.

## Suggested First Antigravity Prompt

```text
Open the Flutter project at C:\Users\Alpha\Documents\New project\Trackr.
Read HANDOVER.md and README.md first. Preserve the local-first architecture,
existing UI theme, encrypted storage, Riverpod providers, and current Android
package/signing configuration. Do not replace existing working features.

First, add provider-level automated tests for Pending deduplication using fake
storage. Reproduce and fix any case where a confirmed or rejected SMS can be
added to Pending again, including a resent SMS with the same UPI Ref and a
stale Pending row left by a background write. Run flutter test and build a
release APK only after the tests pass.
```

## Do Not Accidentally Break

- `third_party/telephony` is a path dependency, not a pub.dev dependency. Keep it available.
- Keep `com.trackr.app` unchanged for updates that must preserve installed data.
- Never commit `android/key.properties` or the `.jks` signing key.
- Do not remove the SMS detection start timestamp guard: it intentionally avoids importing older inbox history after a permission grant.
- Keep transaction confirmation as the default. Trusted automatic detection must remain opt-in.
