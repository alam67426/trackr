import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reimbursement_model.dart';
import '../services/reimbursement_service.dart';
import '../services/storage_service.dart';

final reimbursementServiceProvider =
    Provider((ref) => ReimbursementService(StorageService.instance));

final reimbursementProvider =
    StateNotifierProvider<ReimbursementNotifier, List<Reimbursement>>((ref) {
  return ReimbursementNotifier(ref.watch(reimbursementServiceProvider))..load();
});

class ReimbursementNotifier extends StateNotifier<List<Reimbursement>> {
  ReimbursementNotifier(this._service) : super(const []);
  final ReimbursementService _service;

  Future<void> load() async => state = await _service.load();

  Future<void> add(Reimbursement reimbursement) async {
    state = [reimbursement, ...state];
    await _service.save(state);
  }

  Future<void> clear() async {
    state = const [];
    await _service.save(state);
  }
}
