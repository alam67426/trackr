import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:trackr/models/pending_transaction_model.dart';
import 'package:trackr/models/resolved_record_model.dart';
import 'package:trackr/providers/pending_provider.dart';
import 'package:trackr/providers/transaction_provider.dart';
import 'package:trackr/services/notification_service.dart';
import 'package:trackr/services/resolved_ledger.dart';
import 'package:trackr/services/sms_listener.dart';
import 'package:trackr/services/sms_parser.dart';
import 'package:trackr/services/storage_service.dart';
import 'package:trackr/services/transaction_service.dart';
import 'package:trackr/utils/sms_filters.dart';

class FakeStorageService extends StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<List<Map<String, dynamic>>> readSecureList(String key) async {
    final val = _data[key];
    if (val == null) return [];
    final decoded = val is String ? jsonDecode(val) as List : val as List;
    return decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<void> writeSecureList(
      String key, List<Map<String, dynamic>> value) async {
    _data[key] = value.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<List<String>> readSecureStringList(String key) async {
    final val = _data[key];
    if (val == null) return [];
    final decoded = val is String ? jsonDecode(val) as List : val as List;
    return List<String>.from(decoded);
  }

  @override
  Future<void> writeSecureStringList(String key, List<String> value) async {
    _data[key] = List<String>.from(value);
  }

  @override
  Future<void> clearSecureData() async {
    _data.clear();
  }

  @override
  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
}

class FakeNotificationService extends NotificationService {
  final List<PendingTransaction> detected = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> budgetAlert(String title, String body) async {}

  @override
  Future<void> pendingReminder(int count) async {}

  @override
  Future<void> transactionDetected(PendingTransaction pending) async {
    detected.add(pending);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageService fakeStorage;
  late FakeNotificationService fakeNotifications;
  late ProviderContainer container;
  late SMSParser parser;

  setUp(() {
    fakeStorage = FakeStorageService();
    fakeNotifications = FakeNotificationService();
    StorageService.instance = fakeStorage;
    NotificationService.instance = fakeNotifications;
    SharedPreferences.setMockInitialValues({'smsAutoDetection': true});
    parser = SMSParser();

    container = ProviderContainer(
      overrides: [
        pendingStorageServiceProvider.overrideWithValue(fakeStorage),
        transactionServiceProvider
            .overrideWithValue(TransactionService(fakeStorage)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Pending Deduplication and Lifecycle', () {
    test('rejects the exact same raw SMS twice in foreground', () async {
      const smsBody =
          'Central Bank of India: A/c XX6789 debited by Rs. 1,500.00 on 01-08-2026 at 14:30 to Amazon. UPI Ref 4000000001';
      final parsed =
          parser.parseRawMessage(body: smsBody, sender: 'AD-CBIND-T');
      expect(parsed, isNotNull);

      final notifier = container.read(pendingProvider.notifier);
      await notifier.load();

      final firstAdded = await notifier.add(parsed!);
      expect(firstAdded, isTrue);
      expect(container.read(pendingProvider).length, equals(1));

      // Same SMS again
      final secondAdded = await notifier.add(parsed);
      expect(secondAdded, isFalse);
      expect(container.read(pendingProvider).length, equals(1));
    });

    test('deduplicates matching reference with different delivery timestamp',
        () async {
      const sms1 =
          'Central Bank of India: A/c XX6789 debited by Rs. 1,500.00 on 01-08-2026 at 14:30 to Amazon. UPI Ref 4000000001';
      const sms2 =
          'Central Bank of India: A/c XX6789 debited by Rs. 1,500.00 on 01-08-2026 at 14:35 to Amazon. UPI Ref 4000000001';

      final parsed1 = parser.parseRawMessage(body: sms1, sender: 'AD-CBIND-T');
      final parsed2 = parser.parseRawMessage(body: sms2, sender: 'AD-CBIND-T');
      expect(parsed1, isNotNull);
      expect(parsed2, isNotNull);

      final notifier = container.read(pendingProvider.notifier);
      await notifier.load();

      final firstAdded = await notifier.add(parsed1!);
      expect(firstAdded, isTrue);

      final secondAdded = await notifier.add(parsed2!);
      expect(secondAdded, isFalse);
      expect(container.read(pendingProvider).length, equals(1));
    });

    test('Confirm then resend: confirmed SMS cannot return to Pending',
        () async {
      const sms =
          'Central Bank of India: A/c XX6789 debited by Rs. 1,500.00 on 01-08-2026 at 14:30 to Amazon. UPI Ref 4000000001';
      final parsed = parser.parseRawMessage(body: sms, sender: 'AD-CBIND-T');
      expect(parsed, isNotNull);

      final notifier = container.read(pendingProvider.notifier);
      await notifier.load();

      await notifier.add(parsed!);
      expect(container.read(pendingProvider).length, equals(1));

      // User confirms
      await notifier.confirm(parsed.id);
      expect(container.read(pendingProvider), isEmpty);

      // Verify transaction is now confirmed in history
      final confirmed = container.read(transactionProvider);
      expect(confirmed.length, equals(1));
      expect(confirmed.first.referenceNumber, equals('4000000001'));

      // Resend foreground
      final resendAdded = await notifier.add(parsed);
      expect(resendAdded, isFalse);
      expect(container.read(pendingProvider), isEmpty);

      // Resend via background SMS handler
      final message = SmsMessage.fromMap({
        'originating_address': 'AD-CBIND-T',
        'message_body': sms,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'service_center': '',
        'status': '0',
      }, INCOMING_SMS_COLUMNS);
      await backgroundSmsHandler(message);

      // Reload pending and verify still empty
      await notifier.load();
      expect(container.read(pendingProvider), isEmpty);
    });

    test('Reject then resend: rejected SMS cannot return to Pending', () async {
      const sms =
          'Central Bank of India: A/c XX6789 debited by Rs. 1,500.00 on 01-08-2026 at 14:30 to Amazon. UPI Ref 4000000001';
      final parsed = parser.parseRawMessage(body: sms, sender: 'AD-CBIND-T');
      expect(parsed, isNotNull);

      final notifier = container.read(pendingProvider.notifier);
      await notifier.load();

      await notifier.add(parsed!);
      expect(container.read(pendingProvider).length, equals(1));

      // User rejects
      await notifier.reject(parsed.id);
      expect(container.read(pendingProvider), isEmpty);

      // Not in transaction history
      expect(container.read(transactionProvider), isEmpty);

      // Resend foreground
      final resendAdded = await notifier.add(parsed);
      expect(resendAdded, isFalse);
      expect(container.read(pendingProvider), isEmpty);

      // Resend background
      final message = SmsMessage.fromMap({
        'originating_address': 'AD-CBIND-T',
        'message_body': sms,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'service_center': '',
        'status': '0',
      }, INCOMING_SMS_COLUMNS);
      await backgroundSmsHandler(message);

      await notifier.load();
      expect(container.read(pendingProvider), isEmpty);
    });

    test('Reject then resend reference-free alert: does not return to Pending',
        () async {
      // Alert without UPI Ref
      const sms =
          'Sent Rs. 250.00 from HDFC Bank A/C *1234 to Chai Point on 01/08/26';
      final parsed =
          parser.parseRawMessage(body: sms, sender: 'AD-HDFCBK-T');
      expect(parsed, isNotNull);

      final notifier = container.read(pendingProvider.notifier);
      await notifier.load();

      await notifier.add(parsed!);
      expect(container.read(pendingProvider).length, equals(1));

      await notifier.reject(parsed.id);
      expect(container.read(pendingProvider), isEmpty);

      // Resend same reference-free SMS
      final resendAdded = await notifier.add(parsed);
      expect(resendAdded, isFalse);
      expect(container.read(pendingProvider), isEmpty);
    });

    test('stale Pending row left by background write is purged on load',
        () async {
      const sms =
          'Central Bank of India: A/c XX6789 debited by Rs. 1,500.00 on 01-08-2026 at 14:30 to Amazon. UPI Ref 4000000001';
      final parsed = parser.parseRawMessage(body: sms, sender: 'AD-CBIND-T')!;

      final notifier = container.read(pendingProvider.notifier);
      await notifier.load();
      await notifier.add(parsed);
      await notifier.confirm(parsed.id);

      // Simulate a concurrent background write that placed the pending row into storage
      final stalePending = parsed.copyWith();
      await fakeStorage.writeSecureList(
          pendingTransactionsStorageKey, [stalePending.toJson()]);

      // Load should discard the stale row because it is resolved in the ledger
      await notifier.load();
      expect(container.read(pendingProvider), isEmpty);

      // Storage should be cleaned
      final inStorage =
          await fakeStorage.readSecureList(pendingTransactionsStorageKey);
      expect(inStorage, isEmpty);
    });

    test('e-mandate reminder is ignored, then actual debit qualifies and adds',
        () async {
      const mandateReminder =
          'Dear Customer, your Mandate for Rs 499.00 towards NETFLIX will be debited from A/c XX1234 on 05-Aug-26';
      const actualDebit =
          'Central Bank of India: A/c XX1234 debited by Rs. 499.00 on 05-08-2026 at 10:00 to NETFLIX. UPI Ref 4000000099';

      // Mandate reminder should not qualify
      expect(SMSFilter.isScheduledDebit(mandateReminder), isTrue);
      expect(parser.parseRawMessage(body: mandateReminder, sender: 'AD-CBIND-T'),
          isNull);

      // Actual debit should qualify
      expect(SMSFilter.isScheduledDebit(actualDebit), isFalse);
      final parsedDebit =
          parser.parseRawMessage(body: actualDebit, sender: 'AD-CBIND-T');
      expect(parsedDebit, isNotNull);

      final notifier = container.read(pendingProvider.notifier);
      await notifier.load();

      final added = await notifier.add(parsedDebit!);
      expect(added, isTrue);
      expect(container.read(pendingProvider).length, equals(1));
      expect(container.read(pendingProvider).first.transaction.amount,
          equals(499.00));
    });

    test('audit retention trims oldest entries by timestamp beyond limit',
        () async {
      final ledger = ResolvedLedger();
      final baseTime = DateTime(2026, 1, 1);

      // Add 2005 records with increasing timestamps
      for (var i = 0; i < 2005; i++) {
        ledger.add(ResolvedRecord(
          reference: 'ref_$i',
          identity: 'identity_$i',
          rawKey: 'raw_$i',
          fingerprint: 'fp_$i',
          action: 'confirm',
          resolvedAt: baseTime.add(Duration(minutes: i)),
        ));
      }

      expect(ledger.records.length, equals(2005));

      // Trim retention
      ledger.trimRetention(maxRecords: 2000);
      expect(ledger.records.length, equals(2000));

      // The 5 oldest records (i=0..4) should be pruned
      for (var i = 0; i < 5; i++) {
        expect(ledger.records.any((r) => r.reference == 'ref_$i'), isFalse);
      }
      // The newest 2000 records (i=5..2004) should remain
      expect(ledger.records.first.reference, equals('ref_5'));
      expect(ledger.records.last.reference, equals('ref_2004'));
    });

    test('migrates legacy handled strings from handledSmsStorageKey', () async {
      final legacyStrings = [
        'raw:testrawbody',
        'sms:ref:999888777',
        'sms:identity:expense|100.00|swiggy|hdfc|1234',
        'sms:fallback:expense|200.00|zomato|icici|5678|2026-8-1',
      ];
      await fakeStorage.writeSecureStringList(
          handledSmsStorageKey, legacyStrings);

      final ledger = await ResolvedLedger.load(fakeStorage);
      expect(ledger.records.length, equals(4));

      // Check reference was parsed
      expect(ledger.records.any((r) => r.reference == '999888777'), isTrue);

      // Check migration saved structured ledger
      final inStorage =
          await fakeStorage.readSecureList(resolvedLedgerStorageKey);
      expect(inStorage.length, equals(4));
    });
  });
}
