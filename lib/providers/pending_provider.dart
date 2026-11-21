import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pending_transaction_model.dart';
import '../models/resolved_record_model.dart';
import '../models/transaction_model.dart';
import '../services/resolved_ledger.dart';
import '../services/sms_parser.dart';
import '../services/storage_service.dart';
import '../utils/sms_filters.dart';
import 'transaction_provider.dart';

final pendingStorageServiceProvider =
    Provider<StorageService>((ref) => StorageService.instance);

final pendingProvider =
    StateNotifierProvider<PendingNotifier, List<PendingTransaction>>((ref) {
  return PendingNotifier(
    ref,
    storage: ref.watch(pendingStorageServiceProvider),
  )..load();
});

class PendingNotifier extends StateNotifier<List<PendingTransaction>> {
  PendingNotifier(this._ref, {StorageService? storage})
      : _storage = storage ?? StorageService.instance,
        super(const []);

  final Ref _ref;
  final StorageService _storage;
  ResolvedLedger _ledger = ResolvedLedger();
  final SMSParser _parser = SMSParser();
  Future<void> _writeQueue = Future.value();

  ResolvedLedger get ledger => _ledger;

  Future<void> load() async {
    await _ref.read(transactionProvider.notifier).load();
    _ledger = await ResolvedLedger.load(_storage);
    final rows = await _storage.readSecureList(pendingTransactionsStorageKey);
    final pending = rows.map(PendingTransaction.fromJson).map((item) {
      return item.transaction.categoryId == 'public_transport'
          ? item.copyWith(
              transaction: item.transaction.copyWith(categoryId: 'commute'))
          : item;
    }).where((item) =>
        !_ledger.isResolved(item) &&
        !SMSFilter.isScheduledDebit(item.rawSms)).toList();
    pending.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    final uniquePending = _unique(pending);
    final alreadyConfirmed =
        uniquePending.where(_matchesConfirmedTransaction).toList();
    final activePending = uniquePending
        .where((item) => !alreadyConfirmed.contains(item))
        .toList();

    if (alreadyConfirmed.isNotEmpty) {
      for (final item in alreadyConfirmed) {
        _ledger.add(ResolvedRecord.fromPending(
          item,
          action: 'auto_confirmed',
          parser: _parser,
        ));
      }
      await ResolvedLedger.save(_storage, _ledger);
    }

    state = activePending;
    if (alreadyConfirmed.isNotEmpty ||
        activePending.length != rows.length ||
        rows.any((row) =>
            (row['transaction'] as Map?)?['categoryId'] ==
            'public_transport')) {
      await _persist();
    }
  }

  Future<bool> add(PendingTransaction pending) =>
      _serialize(() => _add(pending));

  Future<bool> _add(PendingTransaction pending) async {
    if (_ledger.isResolved(pending)) return false;
    if (_matchesConfirmedTransaction(pending)) {
      _ledger.add(ResolvedRecord.fromPending(
        pending,
        action: 'auto_confirmed',
        parser: _parser,
      ));
      await ResolvedLedger.save(_storage, _ledger);
      return false;
    }
    final rawKey = ResolvedRecord.normalizeRaw(pending.rawSms);
    if (state.any((item) =>
        ResolvedRecord.normalizeRaw(item.rawSms) == rawKey ||
        _parser.isSameTransaction(item.transaction, pending.transaction))) {
      return false;
    }
    state = [pending, ...state];
    await _persist();
    return true;
  }

  Future<void> confirm(String id) => _serialize(() => _confirm(id));

  Future<void> _confirm(String id) async {
    PendingTransaction? pending;
    for (final item in state) {
      if (item.id == id) {
        pending = item;
        break;
      }
    }
    if (pending == null) return;
    if (!_matchesConfirmedTransaction(pending)) {
      await _ref.read(transactionProvider.notifier).add(pending.transaction);
    }
    final duplicates = _equivalent(pending, state).toList();
    for (final item in duplicates) {
      _ledger.add(ResolvedRecord.fromPending(
        item,
        action: 'confirm',
        parser: _parser,
      ));
    }
    await ResolvedLedger.save(_storage, _ledger);
    await _removeMany(duplicates.map((item) => item.id));
  }

  Future<void> reject(String id) => _serialize(() => _reject(id));

  Future<void> _reject(String id) async {
    PendingTransaction? pending;
    for (final item in state) {
      if (item.id == id) {
        pending = item;
        break;
      }
    }
    if (pending == null) return;
    final duplicates = _equivalent(pending, state).toList();
    for (final item in duplicates) {
      _ledger.add(ResolvedRecord.fromPending(
        item,
        action: 'reject',
        parser: _parser,
      ));
    }
    await ResolvedLedger.save(_storage, _ledger);
    await _removeMany(duplicates.map((item) => item.id));
  }

  Future<void> confirmAll() => _serialize(_confirmAll);

  Future<void> _confirmAll() async {
    final items = List<PendingTransaction>.from(state);
    if (items.isEmpty) return;

    for (final item in items) {
      if (!_matchesConfirmedTransaction(item)) {
        await _ref.read(transactionProvider.notifier).add(item.transaction);
      }
      _ledger.add(ResolvedRecord.fromPending(
        item,
        action: 'confirm',
        parser: _parser,
      ));
    }
    await ResolvedLedger.save(_storage, _ledger);
    state = const [];
    await _cleanPendingStorage();
  }

  Future<void> rejectAll() => _serialize(_rejectAll);

  Future<void> _rejectAll() async {
    final items = List<PendingTransaction>.from(state);
    if (items.isEmpty) return;

    for (final item in items) {
      _ledger.add(ResolvedRecord.fromPending(
        item,
        action: 'reject',
        parser: _parser,
      ));
    }
    await ResolvedLedger.save(_storage, _ledger);
    state = const [];
    await _cleanPendingStorage();
  }

  Future<void> remove(String id) => _serialize(() => _remove(id));

  Future<void> _remove(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _persist();
  }

  Future<void> _removeMany(Iterable<String> ids) async {
    final idSet = ids.toSet();
    state = state.where((item) => !idSet.contains(item.id)).toList();
    await _cleanPendingStorage();
  }

  Future<void> _cleanPendingStorage() async {
    final rows = await _storage.readSecureList(pendingTransactionsStorageKey);
    final activeIds = state.map((e) => e.id).toSet();
    final filtered = rows.where((row) {
      final p = PendingTransaction.fromJson(row);
      return activeIds.contains(p.id) &&
          !_ledger.isResolved(p) &&
          !SMSFilter.isScheduledDebit(p.rawSms);
    }).toList();
    await _storage.writeSecureList(pendingTransactionsStorageKey, filtered);
  }

  Future<void> updateTransaction(String id, TrackrTransaction transaction) =>
      _serialize(() => _updateTransaction(id, transaction));

  Future<void> _updateTransaction(
      String id, TrackrTransaction transaction) async {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(transaction: transaction) else item,
    ];
    await _persist();
  }

  Future<void> clear() => _serialize(_clear);

  Future<void> _clear() async {
    state = const [];
    _ledger.clear();
    await _storage.writeSecureList(resolvedLedgerStorageKey, const []);
    await _storage.writeSecureStringList(handledSmsStorageKey, const []);
    await _storage.writeSecureList(pendingTransactionsStorageKey, const []);
  }

  bool _matchesConfirmedTransaction(PendingTransaction pending) {
    final candidate = pending.transaction;
    return _ref.read(transactionProvider).any((transaction) {
      final sameDay = transaction.dateTime.year == candidate.dateTime.year &&
          transaction.dateTime.month == candidate.dateTime.month &&
          transaction.dateTime.day == candidate.dateTime.day;
      return _parser.isSameTransaction(transaction, candidate) ||
          (transaction.type == candidate.type &&
              transaction.amount == candidate.amount &&
              transaction.description.toLowerCase() ==
                  candidate.description.toLowerCase() &&
              sameDay);
    });
  }

  String _fingerprintKey(PendingTransaction pending) =>
      'sms:${_parser.transactionFingerprint(pending.transaction)}';

  List<PendingTransaction> _unique(List<PendingTransaction> items) {
    final seenRaw = <String>{};
    final seenFingerprint = <String>{};
    final seenRef = <String>{};
    final result = <PendingTransaction>[];
    for (final item in items) {
      final raw = ResolvedRecord.normalizeRaw(item.rawSms);
      final fingerprint = _fingerprintKey(item);
      final ref = item.transaction.referenceNumber?.trim().toLowerCase();
      if (seenRaw.contains(raw) ||
          seenFingerprint.contains(fingerprint) ||
          (ref != null && ref.isNotEmpty && seenRef.contains(ref)) ||
          result.any((existing) =>
              _parser.isSameTransaction(existing.transaction, item.transaction))) {
        continue;
      }
      seenRaw.add(raw);
      seenFingerprint.add(fingerprint);
      if (ref != null && ref.isNotEmpty) {
        seenRef.add(ref);
      }
      result.add(item);
    }
    return result;
  }

  Iterable<PendingTransaction> _equivalent(
      PendingTransaction target, Iterable<PendingTransaction> items) {
    final raw = ResolvedRecord.normalizeRaw(target.rawSms);
    final targetRef = target.transaction.referenceNumber?.trim().toLowerCase();
    return items.where((item) {
      if (item.id == target.id) return true;
      if (ResolvedRecord.normalizeRaw(item.rawSms) == raw) return true;
      if (_parser.isSameTransaction(item.transaction, target.transaction)) {
        return true;
      }
      final itemRef = item.transaction.referenceNumber?.trim().toLowerCase();
      if (targetRef != null &&
          targetRef.isNotEmpty &&
          itemRef != null &&
          itemRef.isNotEmpty &&
          targetRef == itemRef) {
        return true;
      }
      return false;
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<void> _persist() => _storage.writeSecureList(
      pendingTransactionsStorageKey, state.map((e) => e.toJson()).toList());
}
