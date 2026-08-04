import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pending_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';
import '../widgets/common/glass_card.dart';
import 'export_screen.dart';
import 'insight_hub_screen.dart';
import 'pending_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingProvider).length;
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('TOOLS',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _MoreTile(
            icon: Icons.person_outline_rounded,
            color: AppColors.teal,
            title: profile.fullName.isEmpty ? 'Your profile' : profile.fullName,
            subtitle: profile.fullName.isEmpty
                ? 'Add your details for personalised reports'
                : 'Profile and report details',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            _MoreTile(
              icon: Icons.pending_actions_outlined,
              color: AppColors.warning,
              title: 'Pending review',
              subtitle: pending == 0
                  ? 'No transactions waiting for review'
                  : '$pending transaction${pending == 1 ? '' : 's'} waiting for review',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PendingScreen())),
            ),
            const Divider(height: 1),
            _MoreTile(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.purple,
              title: 'Trackr Intelligence',
              subtitle:
                  'Private spending, savings, investment, and EMI guidance',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightHubScreen())),
            ),
            const Divider(height: 1),
            _MoreTile(
              icon: Icons.ios_share_outlined,
              color: AppColors.teal,
              title: 'Export reports',
              subtitle: 'PDF reports and CSV spreadsheets',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportScreen())),
            ),
            const Divider(height: 1),
            _MoreTile(
              icon: Icons.settings_outlined,
              color: AppColors.purple,
              title: 'Settings',
              subtitle: 'Privacy, SMS detection, budget, and appearance',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
