import '../models/reimbursement_model.dart';
import 'storage_service.dart';

class ReimbursementService {
  ReimbursementService(this._storage);
  final StorageService _storage;
  static const _key = 'trackr_reimbursements';

  Future<List<Reimbursement>> load() async => (await _storage.readSecureList(_key))
      .map(Reimbursement.fromJson)
      .toList()
    ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

  Future<void> save(List<Reimbursement> values) => _storage.writeSecureList(
      _key, values.map((item) => item.toJson()).toList());
}
