import 'package:flutter/services.dart';

class BusinessNotification {
  const BusinessNotification(
      {required this.sender, required this.body, required this.timestamp});
  final String sender;
  final String body;
  final int timestamp;
}

class NotificationAccessService {
  static const _channel = MethodChannel('trackr/notification_access');

  Future<void> openSettings() => _channel.invokeMethod('openSettings');
  Future<bool> isEnabled() async =>
      await _channel.invokeMethod<bool>('isEnabled') ?? false;

  Future<List<BusinessNotification>> consume() async {
    final rows =
        await _channel.invokeListMethod<dynamic>('consume') ?? const [];
    return rows.map((row) {
      final value = Map<Object?, Object?>.from(row as Map);
      return BusinessNotification(
        sender: value['sender'] as String? ?? '',
        body: value['body'] as String? ?? '',
        timestamp: (value['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
    }).toList();
  }
}
