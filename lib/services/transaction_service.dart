import '../models/transaction_model.dart';
import 'storage_service.dart';

class TransactionService {
  TransactionService(this._storage);

  final StorageService _storage;
  static const _key = 'trackr_transactions';

  Future<List<TrackrTransaction>> load() async {
    final rows = await _storage.readSecureList(_key);
    final transactions = rows.map(TrackrTransaction.fromJson).map((item) {
      return item.categoryId == 'public_transport'
          ? item.copyWith(categoryId: 'commute')
          : item;
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    if (transactions.any((item) => item.categoryId == 'commute') &&
        rows.any((row) => row['categoryId'] == 'public_transport')) {
      await save(transactions);
    }
    return transactions;
  }

  Future<void> save(List<TrackrTransaction> transactions) async {
    final sorted = [...transactions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await _storage.writeSecureList(
        _key, sorted.map((e) => e.toJson()).toList());
  }
}
