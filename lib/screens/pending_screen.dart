import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pending_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/pending_transaction_model.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/transactions/pending_transaction_tile.dart';
import '../widgets/transactions/add_transaction_dialog.dart';

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Pending (${pending.length})'),
        actions: pending.isEmpty
            ? null
            : [
                IconButton(
                  tooltip: 'Approve all',
                  onPressed: () => _confirmApproveAll(context, ref),
                  icon: const Icon(Icons.done_all),
                ),
                IconButton(
                  tooltip: 'Reject all',
                  onPressed: () => _confirmRejectAll(context, ref),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
      ),
      body: pending.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.task_alt_outlined,
                    size: 46, color: AppColors.teal),
                const SizedBox(height: 12),
                Text('You are all caught up',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('New detected bank messages will appear here.',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 18),
              itemCount: pending.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('REVIEW BEFORE ADDING TO HISTORY',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.muted,
                                  letterSpacing: 1,
                                )),
                  );
                }
                final item = pending[index - 1];
                return PendingTransactionTile(
                  pending: item,
                  onConfirm: () => _confirmOne(ref, item),
                  onReject: () =>
                      ref.read(pendingProvider.notifier).reject(item.id),
                  onEdit: () => _editPending(context, ref, item),
                  onReview: () => _showDetails(context, item),
                );
              },
            ),
    );
  }

  Future<void> _editPending(
      BuildContext context, WidgetRef ref, PendingTransaction pending) async {
    final edited = await showDialog(
      context: context,
      builder: (_) => AddTransactionDialog(initial: pending.transaction),
    );
    if (edited != null) {
      await ref
          .read(pendingProvider.notifier)
          .updateTransaction(pending.id, edited);
    }
  }

  Future<void> _confirmOne(WidgetRef ref, PendingTransaction pending) async {
    await ref.read(pendingProvider.notifier).confirm(pending.id);
    ref.read(currentMonthProvider.notifier).state =
        DateTime(pending.transaction.dateTime.year, pending.transaction.dateTime.month);
  }

  Future<void> _showDetails(
      BuildContext context, PendingTransaction pending) async {
    final tx = pending.transaction;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: Text('Transaction review',
                      style: Theme.of(context).textTheme.titleLarge)),
              Text(money(tx.amount),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: tx.type == TransactionType.income
                          ? AppColors.success
                          : AppColors.danger)),
            ]),
            const SizedBox(height: 16),
            _DetailRow('Type', _titleCase(tx.type.name)),
            _DetailRow('Description', tx.description),
            _DetailRow('Category', AppCategories.byId(tx.categoryId).name),
            _DetailRow('Date & time', formatDateTime(tx.dateTime)),
            if (tx.bankName?.isNotEmpty == true) _DetailRow('Bank', tx.bankName!),
            if (tx.accountLastDigits?.isNotEmpty == true)
              _DetailRow('Account', '•••• ${tx.accountLastDigits}'),
            if (tx.referenceNumber?.isNotEmpty == true)
              _DetailRow('Reference', tx.referenceNumber!),
            _DetailRow('Detection confidence', '${(tx.confidence * 100).round()}%'),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Source message',
                    style: Theme.of(context).textTheme.labelLarge)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(pending.rawSms,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ]),
        ),
      ),
    );
  }

  String _titleCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';

  Future<void> _confirmApproveAll(BuildContext context, WidgetRef ref) async {
    final count = ref.read(pendingProvider).length;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve all pending transactions?'),
        content: Text('$count transactions will be added to your history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve all')),
        ],
      ),
    );
    if (approved == true) {
      await ref.read(pendingProvider.notifier).confirmAll();
    }
  }

  Future<void> _confirmRejectAll(BuildContext context, WidgetRef ref) async {
    final count = ref.read(pendingProvider).length;
    final rejected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject all pending transactions?'),
        content: Text('$count transactions will be removed from the queue.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject all')),
        ],
      ),
    );
    if (rejected == true) {
      await ref.read(pendingProvider.notifier).rejectAll();
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 118,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}
