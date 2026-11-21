import 'package:flutter/material.dart';

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
    if (count == 0) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: 'Review $count pending transactions',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0x1AFDCB6E),
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              top: BorderSide(color: Color(0x33FDCB6E)),
              right: BorderSide(color: Color(0x33FDCB6E)),
              bottom: BorderSide(color: Color(0x33FDCB6E)),
              left: BorderSide(color: Color(0xFFFDCB6E), width: 3.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0x26FDCB6E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on_rounded,
                    color: Color(0xFFFDCB6E), size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count transaction${count == 1 ? '' : 's'} to review',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Auto-detected from bank SMS alerts',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF96A2B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFFFDCB6E), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
