import 'package:flutter/material.dart';

import '../common/glass_card.dart';

class PendingBadge extends StatelessWidget {
  const PendingBadge({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Review $count pending transactions',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x26FDCB6E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.pending_actions, color: Color(0xFFFDCB6E)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending review',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                        '$count transaction${count == 1 ? '' : 's'} need attention',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Color(0xFF96A2B8)),
            ],
          ),
        ),
      ),
    );
  }
}
