class Reimbursement {
  const Reimbursement({
    required this.id,
    required this.expenseId,
    required this.participantId,
    required this.amount,
    required this.receivedAt,
  });

  final String id;
  final String expenseId;
  final String participantId;
  final double amount;
  final DateTime receivedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'expenseId': expenseId,
        'participantId': participantId,
        'amount': amount,
        'receivedAt': receivedAt.toIso8601String(),
      };

  factory Reimbursement.fromJson(Map<String, dynamic> json) => Reimbursement(
        id: json['id'] as String,
        expenseId: json['expenseId'] as String,
        participantId: json['participantId'] as String,
        amount: (json['amount'] as num).toDouble(),
        receivedAt: DateTime.parse(json['receivedAt'] as String),
      );
}
