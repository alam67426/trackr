import '../data/sarcastic_insights.dart';
import '../models/transaction_model.dart';
import 'storage_service.dart';

/// Offline intelligence used by Trackr. It only reads encrypted data on the
/// device and never makes a network request.
class LocalIntelligenceService {
  LocalIntelligenceService._();

  static final instance = LocalIntelligenceService._();
  static const _merchantRulesKey = 'trackr_merchant_category_rules';
  final Map<String, String> _merchantCategories = <String, String>{};
  bool _loaded = false;

  Future<void> warmUp() async {
    if (_loaded) return;
    final rows =
        await StorageService.instance.readSecureList(_merchantRulesKey);
    _merchantCategories
      ..clear()
      ..addEntries(rows.map((row) {
        return MapEntry(
          row['merchant'] as String,
          row['categoryId'] as String,
        );
      }));
    _loaded = true;
  }

  String? categoryFor(String merchant) {
    final key = merchantKey(merchant);
    if (key.isEmpty) return null;
    return _merchantCategories[key];
  }

  /// Learns only an explicit manual choice. Auto-detected SMS never train the
  /// model by themselves, preventing a mistaken category from spreading.
  Future<void> learnManualChoice(String merchant, String categoryId) async {
    await warmUp();
    final key = merchantKey(merchant);
    if (key.isEmpty || key == 'upi transaction') return;
    _merchantCategories[key] = categoryId;
    await StorageService.instance.writeSecureList(
      _merchantRulesKey,
      _merchantCategories.entries
          .map((entry) => {
                'merchant': entry.key,
                'categoryId': entry.value,
              })
          .toList(),
    );
  }

  static String merchantKey(String value) {
    var normalized = value.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    normalized = normalized.replaceAll(
        RegExp(r'\b(?:upi|txn|transaction|ref|order)\b'), ' ');
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<LocalInsight> buildInsights(List<TrackrTransaction> transactions) {
    final now = DateTime.now();
    final monthExpenses = transactions.where((item) =>
        item.type == TransactionType.expense &&
        item.dateTime.year == now.year &&
        item.dateTime.month == now.month);
    final total =
        monthExpenses.fold<double>(0, (sum, item) => sum + item.amount);
    if (total == 0) {
      return [
        LocalInsight(
          title: 'Analytics is waiting',
          detail: SarcasticInsights.general(now.day),
          kind: LocalInsightKind.neutral,
        ),
      ];
    }

    final categoryTotals = <String, double>{};
    for (final item in monthExpenses) {
      categoryTotals[item.categoryId] =
          (categoryTotals[item.categoryId] ?? 0) + item.amount;
    }
    final top =
        categoryTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final share = (top.value / total * 100).round();
    final seed = transactions.fold<int>(
        transactions.length + now.day, (sum, item) => sum + item.id.hashCode);
    final insights = <LocalInsight>[
      LocalInsight(
        title: '${top.key.replaceAll('_', ' ')} took centre stage',
        detail: SarcasticInsights.categoryShare(top.key, share / 100, seed),
        kind: LocalInsightKind.focus,
      ),
    ];

    final lastSeven = now.subtract(const Duration(days: 7));
    final recent = transactions
        .where((item) =>
            item.type == TransactionType.expense &&
            item.dateTime.isAfter(lastSeven))
        .fold<double>(0, (sum, item) => sum + item.amount);
    final previous = transactions
        .where((item) =>
            item.type == TransactionType.expense &&
            item.dateTime
                .isAfter(lastSeven.subtract(const Duration(days: 7))) &&
            !item.dateTime.isAfter(lastSeven))
        .fold<double>(0, (sum, item) => sum + item.amount);
    if (previous > 0) {
      final change = ((recent - previous) / previous * 100).round();
      insights.add(LocalInsight(
        title: change > 0
            ? 'This week got expensive'
            : 'Spending took a breather',
        detail: change > 0
            ? '${change.abs()}% up from last week. Wallet is asking for a status meeting. 📅'
            : '${change.abs()}% lower than last week. Budget says, “finally, some peace.” 😌',
        kind: change > 20 ? LocalInsightKind.alert : LocalInsightKind.positive,
      ));
    }
    return insights;
  }
}

enum LocalInsightKind { focus, positive, alert, neutral }

class LocalInsight {
  const LocalInsight(
      {required this.title, required this.detail, required this.kind});

  final String title;
  final String detail;
  final LocalInsightKind kind;
}
