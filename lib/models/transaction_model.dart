enum TransactionType { expense, income, transfer }

enum UpiApp { gpay, phonePe, paytm, bhim, other, none }

class SplitParticipant {
  const SplitParticipant({
    required this.id,
    required this.name,
    required this.amount,
  });

  final String id;
  final String name;
  final double amount;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount};

  factory SplitParticipant.fromJson(Map<String, dynamic> json) =>
      SplitParticipant(
        id: json['id'] as String? ?? json['name'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}

class TrackrTransaction {
  const TrackrTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.dateTime,
    this.note,
    this.upiApp = UpiApp.none,
    this.isAutoDetected = false,
    this.confidence = 1,
    this.splitWith = const [],
    this.splitIncludesUser = true,
    this.userShare = 0,
    this.bankName,
    this.accountLastDigits,
    this.referenceNumber,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final String categoryId;
  final DateTime dateTime;
  final String? note;
  final UpiApp upiApp;
  final bool isAutoDetected;
  final double confidence;
  final List<SplitParticipant> splitWith;
  final bool splitIncludesUser;
  final double userShare;
  final String? bankName;
  final String? accountLastDigits;
  final String? referenceNumber;

  TrackrTransaction copyWith({
    TransactionType? type,
    double? amount,
    String? description,
    String? categoryId,
    DateTime? dateTime,
    String? note,
    UpiApp? upiApp,
    bool? isAutoDetected,
    double? confidence,
    List<SplitParticipant>? splitWith,
    bool? splitIncludesUser,
    double? userShare,
    String? bankName,
    String? accountLastDigits,
    String? referenceNumber,
  }) {
    return TrackrTransaction(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      upiApp: upiApp ?? this.upiApp,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
      confidence: confidence ?? this.confidence,
      splitWith: splitWith ?? this.splitWith,
      splitIncludesUser: splitIncludesUser ?? this.splitIncludesUser,
      userShare: userShare ?? this.userShare,
      bankName: bankName ?? this.bankName,
      accountLastDigits: accountLastDigits ?? this.accountLastDigits,
      referenceNumber: referenceNumber ?? this.referenceNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'description': description,
        'categoryId': categoryId,
        'dateTime': dateTime.toIso8601String(),
        'note': note,
        'upiApp': upiApp.name,
        'isAutoDetected': isAutoDetected,
        'confidence': confidence,
        'splitWith': splitWith.map((e) => e.toJson()).toList(),
        'splitIncludesUser': splitIncludesUser,
        'userShare': userShare,
        'bankName': bankName,
        'accountLastDigits': accountLastDigits,
        'referenceNumber': referenceNumber,
      };

  factory TrackrTransaction.fromJson(Map<String, dynamic> json) =>
      TrackrTransaction(
        id: json['id'] as String,
        type: TransactionType.values.byName(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        categoryId: json['categoryId'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        note: json['note'] as String?,
        upiApp:
            UpiApp.values.byName(json['upiApp'] as String? ?? UpiApp.none.name),
        isAutoDetected: json['isAutoDetected'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
        splitWith: ((json['splitWith'] as List?) ?? [])
            .map((e) =>
                SplitParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        splitIncludesUser: json['splitIncludesUser'] as bool? ?? true,
        userShare: (json['userShare'] as num?)?.toDouble() ?? 0,
        bankName: json['bankName'] as String?,
        accountLastDigits: json['accountLastDigits'] as String?,
        referenceNumber: json['referenceNumber'] as String?,
      );
}
