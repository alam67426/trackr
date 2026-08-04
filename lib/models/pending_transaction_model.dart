import 'transaction_model.dart';

class PendingTransaction {
  const PendingTransaction({
    required this.id,
    required this.transaction,
    required this.rawSms,
    required this.detectedAt,
    required this.needsReview,
  });

  final String id;
  final TrackrTransaction transaction;
  final String rawSms;
  final DateTime detectedAt;
  final bool needsReview;

  PendingTransaction copyWith({TrackrTransaction? transaction}) =>
      PendingTransaction(
        id: id,
        transaction: transaction ?? this.transaction,
        rawSms: rawSms,
        detectedAt: detectedAt,
        needsReview: needsReview,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'transaction': transaction.toJson(),
        'rawSms': rawSms,
        'detectedAt': detectedAt.toIso8601String(),
        'needsReview': needsReview,
      };

  factory PendingTransaction.fromJson(Map<String, dynamic> json) =>
      PendingTransaction(
        id: json['id'] as String,
        transaction: TrackrTransaction.fromJson(
            Map<String, dynamic>.from(json['transaction'] as Map)),
        rawSms: json['rawSms'] as String,
        detectedAt: DateTime.parse(json['detectedAt'] as String),
        needsReview: json['needsReview'] as bool? ?? false,
      );
}
