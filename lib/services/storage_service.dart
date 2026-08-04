import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const pendingTransactionsStorageKey = 'trackr_pending_transactions';
const handledSmsStorageKey = 'trackr_handled_sms';

class StorageService {
  StorageService._();
  static final instance = StorageService._();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<List<Map<String, dynamic>>> readSecureList(String key) async {
    final raw = await _secureStorage.read(key: key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> writeSecureList(String key, List<Map<String, dynamic>> value) {
    return _secureStorage.write(key: key, value: jsonEncode(value));
  }

  Future<List<String>> readSecureStringList(String key) async {
    final raw = await _secureStorage.read(key: key);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> writeSecureStringList(String key, List<String> value) {
    return _secureStorage.write(key: key, value: jsonEncode(value));
  }

  Future<void> clearSecureData() => _secureStorage.deleteAll();

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
}
