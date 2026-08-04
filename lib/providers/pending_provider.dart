import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pending_transaction_model.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import '../services/sms_parser.dart';
import '../utils/sms_filters.dart';
import 'transaction_provider.dart';

final pendingProvider =
    StateNotifierProvider<PendingNotifier, List<PendingTransaction>>((ref) {
  return PendingNotifier(ref)..load();
});

class PendingNotifier extends StateNotifier<List<PendingTransaction>> {
  PendingNotifier(this._ref) : super(const []);

  final Ref _ref;
  final Set<String> _handledRawSms = <String>{};
  final SMSParser _parser = SMSParser();
  Future<void> _writeQueue = Future.value();

  Future<void> load() async {
    await _ref.read(transactionProvider.notifier).load();
    final rows = await StorageService.instance
        .readSecureList(pendingTransactionsStorageKey);
    final handled = await StorageService.instance
        .readSecureStringList(handledSmsStorageKey);
    _handledRawSms
      ..clear()
      ..addAll(handled);
    final migratedHandledKeys = _migrateHandledFallbackKeys();
    final pending = rows.map(PendingTransaction.fromJson).map((item) {
      return item.transaction.categoryId == 'public_transport'
          ? item.copyWith(transaction: item.transaction.copyWith(categoryId: 'commute'))
          : item;
    }).where((item) =>
        !_isHandled(item) && !SMSFilter.isScheduledDebit(item.rawSms)).toList();
    pending.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    final uniquePending = _unique(pending);
    final alreadyConfirmed = uniquePending
        .where(_matchesConfirmedTransaction)
        .toList();
    final activePending = uniquePending
        .where((item) => !alreadyConfirmed.contains(item))
        .toList();
    if (alreadyConfirmed.isNotEmpty) {
      _handledRawSms.addAll(
          alreadyConfirmed.expand(_handledKeys));
      await StorageService.instance
          .writeSecureStringList(handledSmsStorageKey, _handledRawSms.toList());
    } else if (migratedHandledKeys) {
      await StorageService.instance
          .writeSecureStringList(handledSmsStorageKey, _handledRawSms.toList());
    }
    state = activePending;
    if (migratedHandledKeys ||
        activePending.length != rows.length ||
        rows.any((row) =>
            (row['transaction'] as Map?)?['categoryId'] == 'public_transport')) {
      await _persist();
    }
  }

  Future<bool> add(PendingTransaction pending) =>
      _serialize(() => _add(pending));

  Future<bool> _add(PendingTransaction pending) async {
    final fingerprint = _fingerprintKey(pending);
    final rawKey = _rawKey(pending.rawSms);
    if (_handledRawSms.contains(pending.rawSms) ||
        _handledRawSms.contains(rawKey) ||
        _handledRawSms.contains(fingerprint)) return false;
    if (_matchesConfirmedTransaction(pending)) {
      await _markHandled(_handledKeys(pending));
      return false;
    }
    if (state.any((item) =>
        _rawKey(item.rawSms) == rawKey ||
        _parser.isSameTransaction(item.transaction, pending.transaction)))
      return false;
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
    await _markHandled(duplicates.expand(_handledKeys));
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
    await _markHandled(duplicates.expand(_handledKeys));
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
    }
    await _markHandled(items.expand(_handledKeys));
    final ids = items.map((item) => item.id).toSet();
    state = state.where((item) => !ids.contains(item.id)).toList();
    await _persist();
  }

  Future<void> rejectAll() => _serialize(_rejectAll);

  Future<void> _rejectAll() async {
    final items = List<PendingTransaction>.from(state);
    final ids = items.map((item) => item.id).toSet();
    if (ids.isEmpty) return;
    await _markHandled(items.expand(_handledKeys));
    state = state.where((item) => !ids.contains(item.id)).toList();
    await _persist();
  }

  Future<void> remove(String id) => _serialize(() => _remove(id));

  Future<void> _remove(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _persist();
  }

  Future<void> _removeMany(Iterable<String> ids) async {
    final idSet = ids.toSet();
    state = state.where((item) => !idSet.contains(item.id)).toList();
    await _persist();
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
    _handledRawSms.clear();
    await StorageService.instance
        .writeSecureStringList(handledSmsStorageKey, const []);
    await _persist();
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

  String _identityKey(PendingTransaction pending) =>
      'sms:identity:${_parser.transactionIdentity(pending.transaction)}';

  Iterable<String> _handledKeys(PendingTransaction pending) => [
        _rawKey(pending.rawSms),
        _fingerprintKey(pending),
        _identityKey(pending),
      ];

  /// A background isolate can finish a queued write just after an item is
  /// confirmed or rejected. The handled ledger is authoritative, so discard
  /// any stale row that survives in Pending storage on the next load.
  bool _isHandled(PendingTransaction pending) {
    final rawKey = _rawKey(pending.rawSms);
    final fingerprint = _fingerprintKey(pending);
    return _handledRawSms.contains(pending.rawSms) ||
        _handledRawSms.contains(rawKey) ||
        _handledRawSms.contains(fingerprint) ||
        _handledRawSms.contains(_identityKey(pending));
  }

  bool _migrateHandledFallbackKeys() {
    final identities = <String>[];
    for (final key in _handledRawSms) {
      if (!key.startsWith('sms:fallback:')) continue;
      final parts = key.substring('sms:fallback:'.length).split('|');
      if (parts.length < 6) continue;
      identities.add('sms:identity:${parts.take(parts.length - 1).join('|')}');
    }
    final before = _handledRawSms.length;
    _handledRawSms.addAll(identities);
    return _handledRawSms.length != before;
  }

  String _rawKey(String rawSms) => 'raw:${rawSms
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '')}';

  List<PendingTransaction> _unique(List<PendingTransaction> items) {
    final seenRaw = <String>{};
    final seenFingerprint = <String>{};
    final result = <PendingTransaction>[];
    for (final item in items) {
      final raw = _rawKey(item.rawSms);
      final fingerprint = _fingerprintKey(item);
      if (seenRaw.contains(raw) ||
          seenFingerprint.contains(fingerprint) ||
          result.any((existing) =>
              _parser.isSameTransaction(existing.transaction, item.transaction))) {
        continue;
      }
      seenRaw.add(raw);
      seenFingerprint.add(fingerprint);
      result.add(item);
    }
    return result;
  }

  Iterable<PendingTransaction> _equivalent(
      PendingTransaction target, Iterable<PendingTransaction> items) {
    final raw = _rawKey(target.rawSms);
    final fingerprint = _fingerprintKey(target);
    return items.where((item) =>
        _rawKey(item.rawSms) == raw ||
        _parser.isSameTransaction(item.transaction, target.transaction));
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<void> _markHandled(Iterable<String> messages) async {
    _handledRawSms.addAll(messages);
    while (_handledRawSms.length > 2000) {
      _handledRawSms.remove(_handledRawSms.first);
    }
    await StorageService.instance
        .writeSecureStringList(handledSmsStorageKey, _handledRawSms.toList());
  }

  Future<void> _persist() => StorageService.instance.writeSecureList(
      pendingTransactionsStorageKey, state.map((e) => e.toJson()).toList());
}
