import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import '../services/transaction_service.dart';
import '../services/local_intelligence_service.dart';

final transactionServiceProvider =
    Provider((ref) => TransactionService(StorageService.instance));

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, List<TrackrTransaction>>((ref) {
  return TransactionNotifier(ref.watch(transactionServiceProvider))..load();
});

class TransactionNotifier extends StateNotifier<List<TrackrTransaction>> {
  TransactionNotifier(this._service) : super(const []);

  final TransactionService _service;
  Future<void>? _loadInProgress;
  bool _loaded = false;

  Future<void> load() {
    if (_loaded) return Future.value();
    final active = _loadInProgress;
    if (active != null) return active;
    final future = _service.load().then((transactions) {
      state = transactions;
      _loaded = true;
    });
    _loadInProgress = future.whenComplete(() => _loadInProgress = null);
    return _loadInProgress!;
  }

  Future<void> add(TrackrTransaction transaction) async {
    await load();
    if (state.any((item) => item.id == transaction.id)) return;
    state = [...state, transaction]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await _service.save(state);
    if (!transaction.isAutoDetected) {
      await LocalIntelligenceService.instance
          .learnManualChoice(transaction.description, transaction.categoryId);
    }
  }

  Future<void> update(TrackrTransaction transaction) async {
    await load();
    state = [
      for (final item in state)
        if (item.id == transaction.id) transaction else item,
    ]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await _service.save(state);
    await LocalIntelligenceService.instance
        .learnManualChoice(transaction.description, transaction.categoryId);
  }

  Future<void> delete(String id) async {
    await load();
    state = state.where((item) => item.id != id).toList();
    await _service.save(state);
  }

  Future<void> clear() async {
    await load();
    state = const [];
    await _service.save(state);
  }
}

final currentMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthTransactionsProvider = Provider<List<TrackrTransaction>>((ref) {
  final month = ref.watch(currentMonthProvider);
  final transactions = ref.watch(transactionProvider);
  return transactions
      .where((t) =>
          t.dateTime.year == month.year && t.dateTime.month == month.month)
      .toList();
});

final lastTenTransactionsProvider = Provider<List<TrackrTransaction>>((ref) {
  return ref.watch(transactionProvider).take(10).toList();
});
