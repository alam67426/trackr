import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

import '../models/pending_transaction_model.dart';
import 'sms_parser.dart';
import 'local_intelligence_service.dart';
import 'notification_access_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'transaction_service.dart';

typedef PendingSmsHandler = Future<void> Function(PendingTransaction pending);

const smsDetectionStartStorageKey = 'smsDetectionStartedAt';

String _rawSmsKey(String rawSms) => 'raw:${rawSms
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '')}';

/// The app never backfills the phone's SMS history. This timestamp is set
/// when the user enables detection and forms a hard boundary for all inbox,
/// background-SMS, and business-notification processing.
Future<int> smsDetectionStartMillis() async {
  final prefs = await StorageService.instance.prefs();
  final existing = prefs.getInt(smsDetectionStartStorageKey);
  if (existing != null) return existing;
  final now = DateTime.now().millisecondsSinceEpoch;
  await prefs.setInt(smsDetectionStartStorageKey, now);
  return now;
}

Future<void> beginNewSmsDetectionWindow() async {
  final prefs = await StorageService.instance.prefs();
  await prefs.setInt(
      smsDetectionStartStorageKey, DateTime.now().millisecondsSinceEpoch);
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
    final fingerprint =
        'sms:${parser.transactionFingerprint(pending.transaction)}';
    final identity =
        'sms:identity:${parser.transactionIdentity(pending.transaction)}';

    final handled = await StorageService.instance
        .readSecureStringList(handledSmsStorageKey);
    final rawKey = _rawSmsKey(pending.rawSms);
    if (handled.contains(pending.rawSms) ||
        handled.contains(rawKey) ||
        handled.contains(fingerprint) ||
        handled.contains(identity))
      return;

    final confirmed = await TransactionService(StorageService.instance).load();
    if (confirmed.any(
        (item) => parser.isSameTransaction(item, pending.transaction))) {
      await StorageService.instance.writeSecureStringList(
          handledSmsStorageKey, [...handled, rawKey, fingerprint, identity]);
      return;
    }

    final rows = await StorageService.instance
        .readSecureList(pendingTransactionsStorageKey);
    final queue = rows.map(PendingTransaction.fromJson).toList();
    if (queue.any((item) =>
        item.rawSms == pending.rawSms ||
        parser.isSameTransaction(item.transaction, pending.transaction))) return;

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

  /// Retained for a future manual recovery action. It never reads messages
  /// from before the user enabled detection.
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
