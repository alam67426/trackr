import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

import '../models/pending_transaction_model.dart';
import '../models/resolved_record_model.dart';
import 'local_intelligence_service.dart';
import 'notification_access_service.dart';
import 'notification_service.dart';
import 'resolved_ledger.dart';
import 'sms_parser.dart';
import 'storage_service.dart';
import 'transaction_service.dart';

typedef PendingSmsHandler = Future<void> Function(PendingTransaction pending);

const smsDetectionStartStorageKey = 'smsDetectionStartedAt';

/// Lookback window when enabling SMS detection (default 30 days) so recent
/// transactions can be reviewed without backfilling years of history.
const defaultSmsLookback = Duration(days: 30);

Future<int> smsDetectionStartMillis({Duration lookback = defaultSmsLookback}) async {
  final prefs = await StorageService.instance.prefs();
  final existing = prefs.getInt(smsDetectionStartStorageKey);
  if (existing != null) return existing;
  final start = DateTime.now().subtract(lookback).millisecondsSinceEpoch;
  await prefs.setInt(smsDetectionStartStorageKey, start);
  return start;
}

Future<void> beginNewSmsDetectionWindow({Duration lookback = defaultSmsLookback}) async {
  final prefs = await StorageService.instance.prefs();
  final start = DateTime.now().subtract(lookback).millisecondsSinceEpoch;
  await prefs.setInt(smsDetectionStartStorageKey, start);
}

/// Runs in a separate Flutter isolate when Android delivers an SMS while
/// Trackr is not visible. It intentionally writes only to the pending queue;
/// users must still review a detected transaction before it reaches history.
@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await LocalIntelligenceService.instance.warmUp();
    final prefs = await StorageService.instance.prefs();
    if (prefs.getBool('smsAutoDetection') != true) return;
    final startedAt = prefs.getInt(smsDetectionStartStorageKey) ??
        DateTime.now().millisecondsSinceEpoch;
    if (message.date != null && message.date! < startedAt) return;

    final parser = SMSParser();
    final pending = parser.parseUPISMS(message);
    if (pending == null) return;

    final ledger = await ResolvedLedger.load(StorageService.instance);
    if (ledger.isResolved(pending)) return;

    final confirmed = await TransactionService(StorageService.instance).load();
    if (confirmed.any(
        (item) => parser.isSameTransaction(item, pending.transaction))) {
      ledger.add(ResolvedRecord.fromPending(
        pending,
        action: 'auto_confirmed',
        parser: parser,
      ));
      await ResolvedLedger.save(StorageService.instance, ledger);
      return;
    }

    final rows = await StorageService.instance
        .readSecureList(pendingTransactionsStorageKey);
    final queue = rows.map(PendingTransaction.fromJson).toList();
    final rawKey = ResolvedRecord.normalizeRaw(pending.rawSms);
    if (queue.any((item) =>
        ResolvedRecord.normalizeRaw(item.rawSms) == rawKey ||
        parser.isSameTransaction(item.transaction, pending.transaction))) {
      return;
    }

    queue.add(pending);
    queue.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    await StorageService.instance.writeSecureList(
      pendingTransactionsStorageKey,
      queue.map((item) => item.toJson()).toList(),
    );

    // A background SMS callback has no foreground Riverpod state to notify.
    // Post the same review alert here so the pending item is visible in the
    // Android notification shade even while Trackr is closed.
    await NotificationService.instance.init();
    await NotificationService.instance.transactionDetected(pending);
  } catch (error) {
    debugPrint('Background SMS processing failed: $error');
  }
}

class SMSListener {
  SMSListener({SMSParser? parser}) : _parser = parser ?? SMSParser();

  final SMSParser _parser;

  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return false;
    await Permission.notification.request();
    return true;
  }

  Future<bool> start(PendingSmsHandler onDetected) async {
    if (!await requestPermission()) return false;
    // Read the singleton again whenever the foreground app registers. The
    // telephony plugin can initialise a separate instance for background SMS.
    Telephony.instance.listenIncomingSms(
      listenInBackground: true,
      onNewMessage: (message) async {
        final startedAt = await smsDetectionStartMillis();
        if (message.date != null && message.date! < startedAt) return;
        final pending = _parser.parseUPISMS(message);
        if (pending != null) await onDetected(pending);
      },
      onBackgroundMessage: backgroundSmsHandler,
    );
    return true;
  }

  /// Scans recent SMS from the inbox matching bank transaction formats.
  Future<void> scanRecentInbox(
    PendingSmsHandler onDetected, {
    int maxTransactions = 500,
  }) async {
    if (!await requestPermission()) return;
    final startedAt = await smsDetectionStartMillis();

    final messages = await Telephony.instance.getInboxSms(
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    var detectedCount = 0;
    for (final message in messages) {
      if (message.date == null || message.date! < startedAt) continue;
      final pending = _parser.parseUPISMS(message);
      if (pending == null) continue;

      await onDetected(pending);
      detectedCount++;
      if (detectedCount >= maxTransactions) break;
    }
  }

  /// Explicit user-triggered or lookback scan for the past [lookback] period.
  Future<int> rescanRecentInbox(
    PendingSmsHandler onDetected, {
    int maxTransactions = 500,
    Duration lookback = const Duration(days: 30),
  }) async {
    if (!await requestPermission()) return 0;
    final cutoff = DateTime.now().subtract(lookback).millisecondsSinceEpoch;
    final prefs = await StorageService.instance.prefs();
    final existing = prefs.getInt(smsDetectionStartStorageKey);
    if (existing == null || existing > cutoff) {
      await prefs.setInt(smsDetectionStartStorageKey, cutoff);
    }

    final messages = await Telephony.instance.getInboxSms(
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    var detectedCount = 0;
    for (final message in messages) {
      if (message.date == null || message.date! < cutoff) continue;
      final pending = _parser.parseUPISMS(message);
      if (pending == null) continue;

      await onDetected(pending);
      detectedCount++;
      if (detectedCount >= maxTransactions) break;
    }
    return detectedCount;
  }

  Future<void> scanBusinessNotifications(PendingSmsHandler onDetected) async {
    final access = NotificationAccessService();
    if (!await access.isEnabled()) return;
    final startedAt = await smsDetectionStartMillis();
    for (final notification in await access.consume()) {
      if (notification.timestamp < startedAt) continue;
      final pending = _parser.parseRawMessage(
        body: notification.body,
        sender: notification.sender,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(notification.timestamp),
      );
      if (pending != null) await onDetected(pending);
    }
  }
}
