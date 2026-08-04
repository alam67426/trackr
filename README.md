# Trackr

Trackr is a local-first Android expense tracker for Indian users. It records expenses, income, transfers, lending, borrowing, split bills, budgets, and UPI/bank transaction alerts without sending financial data to a cloud server.

## What Trackr Does

- Adds expenses, income, and transfers manually.
- Detects completed debit and credit bank/UPI SMS messages and sends them to **Pending Review** before they affect history.
- Supports common Indian bank formats, including HDFC, Canara, IDFC First, Bandhan, SBI, ICICI, Axis, Kotak, and generic bank alerts.
- Can optionally review new visible bank-like notifications from Truecaller, Google Messages, and Samsung Messages.
- Lets you split an expense, record partial or full repayments, and see money still owed to you.
- Tracks category budgets and provides private, rule-based spending insights.
- Creates CSV and professional PDF reports.

All records remain on the device. Sensitive local data is stored using the app's encrypted storage. Trackr does not upload SMS, notification, or transaction content.

## Daily Use

1. Open **Home** to see this month's spending, income, available balance, today's activity, budget status, category mix, and recent transactions.
2. Tap **Add** to enter an expense, income, or transfer manually. Choose the amount, category, description, date/time, optional note, and UPI app.
3. Open **Transactions** to search, filter, edit, or delete confirmed entries.
4. Tap **Pending Review** whenever its counter is non-zero. Confirm a correct transaction, edit its details first, or reject it.
5. Open **Budgets** to set the overall monthly budget and category limits.
6. Use **Analytics** for trends, category spending, and detailed insights.
7. Use **Export** to create a PDF or CSV for the selected date range.

## Automatic Detection

### SMS Detection

1. Go to **More > Settings**.
2. Turn on **SMS auto-detection**.
3. Allow Android's SMS and notification permissions when asked.
4. Make a bank/UPI transaction or wait for its confirmation SMS.
5. Review the detected transaction in **Pending Review**.

Trackr accepts a message only when it has all of the following:

- a currency amount such as `Rs.`, `INR`, or `₹`;
- a completed movement such as `debited`, `deducted`, `Dr.`, `paid`, `credited`, `deposited`, `Cr.`, `received`, or `refund`; and
- bank, account, UPI, IMPS, NEFT, RTGS, UTR, reference, or transaction context.

It rejects OTPs, loan offers, payment/collect requests, failed or declined payments, and obvious promotional messages. It uses the sender, account digits, reference number, amount, and time to avoid duplicate entries. Low-confidence matches remain in Pending Review; they are never silently saved.

### Truecaller and Messages Notifications

Some banks deliver transaction alerts through a business-chat notification instead of a normal SMS. To enable optional support:

1. Go to **More > Settings**.
2. Turn on **Business chat detection**.
3. In the Android **Notification Access** page, allow access for Trackr.
4. Return to Trackr and enable the switch if needed.
5. After a new transaction notification arrives, open or resume Trackr and review it in **Pending Review**.

This feature considers only **new visible**, transaction-like notifications from Truecaller, Google Messages, and Samsung Messages. It cannot read chat history and ignores ordinary conversations.

## Splitting Bills and Repayments

1. Add an **Expense**.
2. Enable **Split among others**.
3. Enter the participants, select equal or custom shares, and decide whether your own share is included.
4. The full bill is deducted immediately. Trackr calculates your share, recoverable amount, received amount, and pending amount.
5. Open the settlement for that expense and tap **Received Amount** for a participant. Partial repayments are supported.

Repayments are recorded separately as reimbursements, linked to their original expense. They add back to your available balance but are not counted as salary or normal income.

## Trusted Automatic Detection

The **Trusted automatic detection** switch is off by default. Keep it off when you want every detected transaction to appear in Pending Review. If you enable it, only very high-confidence bank messages can be saved automatically.

## Profile and Reports

Use **More > Profile** to save your photo, name, age, contact number, and email locally. Every profile field is optional. When entered, age must be 1–120, the phone field uses the Indian `+91` prefix and accepts exactly 10 valid Indian mobile digits, and the email field validates a complete address with a domain picker for Gmail, Yahoo, Outlook, Hotmail, iCloud, Proton, and Rediffmail.

PDF reports include the available profile details, report period, export date, confirmed transactions, split expenses, reimbursements, and pending settlement amounts. Each report also has a colour-coded summary: **Total Expense** in red, **Total Income** in green, and **Total Savings** in teal (or red when savings are negative).

## Updating Without Losing Data

Install a newer APK over the existing Trackr installation. Do **not** uninstall the old app. Android preserves the app's local data when the application ID and signing key remain the same. Export a CSV periodically as an additional backup.

## Testing With the Android Emulator

The emulator can send a dummy SMS, but its sender must be numeric. Put the bank name inside the message body, for example:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" emu sms send 5556 "Bandhan Bank: A/c XX1234 Cr. INR 5,000.00 on 01/08/2026 from Freelance. UPI Ref 3000000010"
```

Turn **Trusted automatic detection** off before this test so the match appears in Pending Review.

## Development

```bash
flutter pub get
flutter run
```

Create a release APK:

```bash
flutter build apk --release
```

The generated APK is at `build/app/outputs/flutter-apk/app-release.apk`.

For Play Console updates, keep your `android/trackr-upload.jks` and `android/key.properties` safe. They are needed to sign future versions of the same application.
