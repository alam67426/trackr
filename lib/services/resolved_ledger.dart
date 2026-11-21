import '../models/pending_transaction_model.dart';
import '../models/resolved_record_model.dart';
import 'sms_parser.dart';
import 'storage_service.dart';

class ResolvedLedger {
  ResolvedLedger({List<ResolvedRecord>? records}) {
    if (records != null) {
      addAll(records);
    }
  }

  final List<ResolvedRecord> _records = [];
  final Set<String> _references = <String>{};
  final Set<String> _identitiesWithDate = <String>{};
  final Set<String> _legacyIdentities = <String>{};
  final Set<String> _rawKeys = <String>{};
  final Set<String> _fingerprints = <String>{};
  final SMSParser _parser = SMSParser();

  List<ResolvedRecord> get records => List.unmodifiable(_records);

  void add(ResolvedRecord record) {
    _records.add(record);
    _index(record);
  }

  void addAll(Iterable<ResolvedRecord> newRecords) {
    for (final r in newRecords) {
      add(r);
    }
  }

  void _index(ResolvedRecord record) {
    if (record.reference != null && record.reference!.isNotEmpty) {
      _references.add(record.reference!.toLowerCase());
    }
    if (record.identity.isNotEmpty) {
      if (record.transactionDate != null &&
          record.transactionDate!.isNotEmpty) {
        _identitiesWithDate.add('${record.identity}|${record.transactionDate}');
      } else {
        _legacyIdentities.add(record.identity);
      }
    }
    if (record.rawKey.isNotEmpty) {
      _rawKeys.add(record.rawKey);
    }
    if (record.fingerprint.isNotEmpty) {
      _fingerprints.add(record.fingerprint);
    }
  }

  bool isResolved(PendingTransaction pending) {
    final ref = pending.transaction.referenceNumber?.trim().toLowerCase();
    if (ref != null && ref.isNotEmpty && _references.contains(ref)) {
      return true;
    }
    final rawKey = ResolvedRecord.normalizeRaw(pending.rawSms);
    if (_rawKeys.contains(rawKey) || _rawKeys.contains(pending.rawSms)) {
      return true;
    }
    final fingerprint =
        'sms:${_parser.transactionFingerprint(pending.transaction)}';
    if (_fingerprints.contains(fingerprint)) {
      return true;
    }
    final identity = _parser.transactionIdentity(pending.transaction);
    final date = pending.transaction.dateTime;
    final dateKey = '$identity|${date.year}-${date.month}-${date.day}';
    if (_identitiesWithDate.contains(dateKey) ||
        _legacyIdentities.contains(identity)) {
      return true;
    }
    return false;
  }

  void trimRetention({int maxRecords = 2000}) {
    if (_records.length <= maxRecords) return;
    _records.sort((a, b) => a.resolvedAt.compareTo(b.resolvedAt));
    final toRemove = _records.length - maxRecords;
    _records.removeRange(0, toRemove);

    _references.clear();
    _identitiesWithDate.clear();
    _legacyIdentities.clear();
    _rawKeys.clear();
    _fingerprints.clear();
    for (final r in _records) {
      _index(r);
    }
  }

  void clear() {
    _records.clear();
    _references.clear();
    _identitiesWithDate.clear();
    _legacyIdentities.clear();
    _rawKeys.clear();
    _fingerprints.clear();
  }

  static Future<ResolvedLedger> load(StorageService storage) async {
    final rows = await storage.readSecureList(resolvedLedgerStorageKey);
    if (rows.isNotEmpty) {
      final records = rows.map((e) => ResolvedRecord.fromJson(e)).toList();
      return ResolvedLedger(records: records);
    }
    final legacyStrings =
        await storage.readSecureStringList(handledSmsStorageKey);
    if (legacyStrings.isNotEmpty) {
      final records =
          legacyStrings.map((s) => ResolvedRecord.fromLegacyString(s)).toList();
      final ledger = ResolvedLedger(records: records);
      await save(storage, ledger);
      return ledger;
    }
    return ResolvedLedger();
  }

  static Future<void> save(StorageService storage, ResolvedLedger ledger) async {
    ledger.trimRetention();
    await storage.writeSecureList(
      resolvedLedgerStorageKey,
      ledger.records.map((r) => r.toJson()).toList(),
    );
    final legacyKeys = <String>{};
    for (final r in ledger.records) {
      if (r.rawKey.isNotEmpty) legacyKeys.add(r.rawKey);
      if (r.fingerprint.isNotEmpty) legacyKeys.add(r.fingerprint);
      if (r.identity.isNotEmpty) {
        legacyKeys.add('sms:identity:${r.identity}');
      }
      if (r.reference != null && r.reference!.isNotEmpty) {
        legacyKeys.add('sms:ref:${r.reference}');
      }
    }
    await storage.writeSecureStringList(
        handledSmsStorageKey, legacyKeys.toList());
  }
}
