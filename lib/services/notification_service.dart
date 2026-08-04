import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/pending_transaction_model.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<String?> reviewRequest = ValueNotifier<String?>(null);

  Future<void> init() async {
    const android = AndroidInitializationSettings('@drawable/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings,
        onDidReceiveNotificationResponse: (response) {
      reviewRequest.value = response.payload;
    });
  }

  Future<void> budgetAlert(String title, String body) {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'budget_alerts',
        'Budget alerts',
        channelDescription: 'Near-limit and over-budget warnings',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    return _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }

  Future<void> pendingReminder(int count) {
    if (count == 0) return Future.value();
    return budgetAlert('Trackr pending review',
        '$count auto-detected UPI transactions need confirmation.');
  }

  Future<void> transactionDetected(PendingTransaction pending) {
    final transaction = pending.transaction;
    final isCredit = transaction.type == TransactionType.income;
    final bank = transaction.bankName ?? 'bank';
    final person = transaction.description == 'UPI Transaction'
        ? ''
        : ' - ${transaction.description}';
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'transaction_review',
        'Transaction review',
        channelDescription:
            'Detected bank and UPI transactions awaiting review',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
        actions: [
          AndroidNotificationAction('confirm', 'Confirm',
              showsUserInterface: true),
          AndroidNotificationAction('edit', 'Edit', showsUserInterface: true),
          AndroidNotificationAction('ignore', 'Ignore',
              showsUserInterface: true),
        ],
      ),
    );
    return _plugin.show(
      pending.id.hashCode,
      '${isCredit ? 'Credit' : 'Debit'} detected: ${money(transaction.amount)}',
      '$bank$person. Review before saving.',
      details,
      payload: pending.id,
    );
  }
}
