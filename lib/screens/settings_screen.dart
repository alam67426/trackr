import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/pending_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/reimbursement_provider.dart';
import '../providers/profile_provider.dart';
import '../services/pdf_service.dart';
import '../services/sms_listener.dart';
import '../services/storage_service.dart';
import '../services/notification_access_service.dart';
import '../utils/constants.dart';
import '../widgets/common/glass_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('PREFERENCES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 1,
                  )),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode'),
                subtitle: const Text('Use the premium dark interface'),
                value: settings.darkMode,
                onChanged: (value) =>
                    notifier.update(settings.copyWith(darkMode: value)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Monthly budget'),
                subtitle:
                    Text('₹ ${settings.monthlyBudget.toStringAsFixed(0)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editBudget(context, ref),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('AUTOMATION',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 1,
                  )),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.sms_outlined),
                title: const Text('SMS auto-detection'),
                subtitle: const Text('Review qualifying bank messages offline'),
                value: settings.smsAutoDetection,
                onChanged: (value) async {
                  if (value) {
                    final listener = SMSListener();
                    final granted = await listener.requestPermission();
                    if (!granted) return;
                    await beginNewSmsDetectionWindow();
                  }
                  await notifier
                      .update(settings.copyWith(smsAutoDetection: value));
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.forum_outlined),
                title: const Text('Business chat detection'),
                subtitle: const Text(
                    'Review bank-like notifications from Truecaller and Messages locally'),
                value: settings.businessChatDetection,
                onChanged: (value) => _setBusinessChatDetection(
                    context, value, settings, notifier),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.verified_user_outlined),
                title: const Text('Trusted automatic detection'),
                subtitle: const Text(
                    'Automatically save only very high-confidence bank messages'),
                value: settings.trustedAutoDetection,
                onChanged: (value) => notifier
                    .update(settings.copyWith(trustedAutoDetection: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Daily spending summary'),
                subtitle: const Text('Keep a daily tab on your expenses'),
                value: settings.dailySummary,
                onChanged: (value) =>
                    _setDailySummary(value, settings, notifier),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('DATA',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 1,
                  )),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('Export all data'),
                subtitle: const Text('Create a local CSV file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final file = await PdfService()
                      .generateCsv(ref.read(transactionProvider));
                  await PdfService().share(file);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.delete_forever, color: AppColors.danger),
                title: const Text('Clear all data',
                    style: TextStyle(color: AppColors.danger)),
                subtitle: const Text('Permanently remove local records'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _clearAll(context, ref),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _setDailySummary(
      bool value, TrackrSettings settings, SettingsNotifier notifier) async {
    if (value) await Permission.notification.request();
    await notifier.update(settings.copyWith(dailySummary: value));
  }

  Future<void> _setBusinessChatDetection(BuildContext context, bool value,
      TrackrSettings settings, SettingsNotifier notifier) async {
    if (!value) {
      await notifier.update(settings.copyWith(businessChatDetection: false));
      return;
    }
    final access = NotificationAccessService();
    if (!await access.isEnabled()) {
      await access.openSettings();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Allow Trackr notification access, then enable this switch again.')));
      }
      return;
    }
    await notifier.update(settings.copyWith(businessChatDetection: true));
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final controller =
        TextEditingController(text: settings.monthlyBudget.toStringAsFixed(0));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly budget'),
        content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: '₹ ')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, double.tryParse(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await ref
        .read(settingsProvider.notifier)
        .update(settings.copyWith(monthlyBudget: value));
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
            'This removes local transactions, pending detections, budgets, and settings from this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirm != true) return;
    await StorageService.instance.clearSecureData();
    await ref.read(transactionProvider.notifier).clear();
    await ref.read(pendingProvider.notifier).clear();
    await ref.read(reimbursementProvider.notifier).clear();
    await ref.read(profileProvider.notifier).clear();
  }
}
