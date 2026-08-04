import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

class TrackrSettings {
  const TrackrSettings({
    this.darkMode = true,
    this.smsAutoDetection = false,
    this.monthlyBudget = 50000,
    this.dailySummary = true,
    this.trustedAutoDetection = false,
    this.businessChatDetection = false,
  });

  final bool darkMode;
  final bool smsAutoDetection;
  final double monthlyBudget;
  final bool dailySummary;
  final bool trustedAutoDetection;
  final bool businessChatDetection;

  TrackrSettings copyWith({
    bool? darkMode,
    bool? smsAutoDetection,
    double? monthlyBudget,
    bool? dailySummary,
    bool? trustedAutoDetection,
    bool? businessChatDetection,
  }) {
    return TrackrSettings(
      darkMode: darkMode ?? this.darkMode,
      smsAutoDetection: smsAutoDetection ?? this.smsAutoDetection,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      dailySummary: dailySummary ?? this.dailySummary,
      trustedAutoDetection: trustedAutoDetection ?? this.trustedAutoDetection,
      businessChatDetection:
          businessChatDetection ?? this.businessChatDetection,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, TrackrSettings>((ref) {
  return SettingsNotifier()..load();
});

class SettingsNotifier extends StateNotifier<TrackrSettings> {
  SettingsNotifier() : super(const TrackrSettings());

  Future<void> load() async {
    final prefs = await StorageService.instance.prefs();
    state = TrackrSettings(
      darkMode: prefs.getBool('darkMode') ?? true,
      smsAutoDetection: prefs.getBool('smsAutoDetection') ?? false,
      monthlyBudget: prefs.getDouble('monthlyBudget') ?? 50000,
      dailySummary: prefs.getBool('dailySummary') ?? true,
      trustedAutoDetection: prefs.getBool('trustedAutoDetection') ?? false,
      businessChatDetection: prefs.getBool('businessChatDetection') ?? false,
    );
  }

  Future<void> update(TrackrSettings settings) async {
    state = settings;
    final prefs = await StorageService.instance.prefs();
    await prefs.setBool('darkMode', settings.darkMode);
    await prefs.setBool('smsAutoDetection', settings.smsAutoDetection);
    await prefs.setDouble('monthlyBudget', settings.monthlyBudget);
    await prefs.setBool('dailySummary', settings.dailySummary);
    await prefs.setBool('trustedAutoDetection', settings.trustedAutoDetection);
    await prefs.setBool(
        'businessChatDetection', settings.businessChatDetection);
  }
}
