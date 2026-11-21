import '../services/sms_parser.dart';
import 'pending_transaction_model.dart';

class ResolvedRecord {
  final String? reference;
  final String identity;
  final String? transactionDate;
  final String rawKey;
  final String fingerprint;
  final String action;
  final DateTime resolvedAt;

  const ResolvedRecord({
    this.reference,
    required this.identity,
    this.transactionDate,
    required this.rawKey,
    required this.fingerprint,
    required this.action,
    required this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        if (reference != null && reference!.isNotEmpty) 'reference': reference,
        'identity': identity,
        if (transactionDate != null && transactionDate!.isNotEmpty)
          'transactionDate': transactionDate,
        'rawKey': rawKey,
        'fingerprint': fingerprint,
        'action': action,
        'resolvedAt': resolvedAt.toIso8601String(),
      };

  factory ResolvedRecord.fromJson(Map<String, dynamic> json) {
    return ResolvedRecord(
      reference: json['reference'] as String?,
      identity: json['identity'] as String? ?? '',
      transactionDate: json['transactionDate'] as String?,
      rawKey: json['rawKey'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      action: json['action'] as String? ?? 'resolved',
      resolvedAt: json['resolvedAt'] != null
          ? (DateTime.tryParse(json['resolvedAt'] as String) ??
              DateTime.fromMillisecondsSinceEpoch(0))
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String normalizeRaw(String raw) =>
      'raw:${raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

  static ResolvedRecord fromPending(
    PendingTransaction pending, {
    required String action,
    DateTime? resolvedAt,
    SMSParser? parser,
  }) {
    final p = parser ?? SMSParser();
    final ref = pending.transaction.referenceNumber?.trim().toLowerCase();
    final identity = p.transactionIdentity(pending.transaction);
    final date = pending.transaction.dateTime;
    final dateStr = '${date.year}-${date.month}-${date.day}';
    final rawKey = normalizeRaw(pending.rawSms);
    final fingerprint = 'sms:${p.transactionFingerprint(pending.transaction)}';

    return ResolvedRecord(
      reference: (ref != null && ref.isNotEmpty) ? ref : null,
      identity: identity,
      transactionDate: dateStr,
      rawKey: rawKey,
      fingerprint: fingerprint,
      action: action,
      resolvedAt: resolvedAt ?? DateTime.now(),
    );
  }

  static ResolvedRecord fromLegacyString(String key, {DateTime? migratedAt}) {
    final now = migratedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (key.startsWith('raw:')) {
      return ResolvedRecord(
        identity: '',
        rawKey: key,
        fingerprint: '',
        action: 'legacy',
        resolvedAt: now,
      );
    }
    if (key.startsWith('sms:ref:')) {
      final ref = key.substring('sms:ref:'.length).trim().toLowerCase();
      return ResolvedRecord(
        reference: ref,
        identity: '',
        rawKey: '',
        fingerprint: key,
        action: 'legacy',
        resolvedAt: now,
      );
    }
    if (key.startsWith('sms:identity:')) {
      return ResolvedRecord(
        identity: key.substring('sms:identity:'.length),
        rawKey: '',
        fingerprint: '',
        action: 'legacy',
        resolvedAt: now,
      );
    }
    if (key.startsWith('sms:fallback:')) {
      final parts = key.substring('sms:fallback:'.length).split('|');
      final identity = parts.length >= 6
          ? parts.take(parts.length - 1).join('|')
          : '';
      final dateStr = parts.length >= 6 ? parts.last : null;
      return ResolvedRecord(
        identity: identity,
        transactionDate: dateStr,
        rawKey: '',
        fingerprint: key,
        action: 'legacy',
        resolvedAt: now,
      );
    }
    final rawKey = normalizeRaw(key);
    return ResolvedRecord(
      identity: '',
      rawKey: rawKey,
      fingerprint: '',
      action: 'legacy',
      resolvedAt: now,
    );
  }
}
