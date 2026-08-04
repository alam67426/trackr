import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reimbursement_model.dart';
import '../models/transaction_model.dart';
import '../providers/reimbursement_provider.dart';
import '../utils/formatters.dart';
import '../widgets/common/glass_card.dart';

class SettlementScreen extends ConsumerWidget {
  const SettlementScreen({super.key, required this.expense});
  final TrackrTransaction expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reimbursements = ref
        .watch(reimbursementProvider)
        .where((item) => item.expenseId == expense.id)
        .toList();
    final received =
        reimbursements.fold<double>(0, (sum, item) => sum + item.amount);
    final recoverable =
        expense.splitWith.fold<double>(0, (sum, item) => sum + item.amount);
    final pending = recoverable - received;
    return Scaffold(
      appBar: AppBar(title: const Text('Split settlement')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(expense.description,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Bill paid by you: ${money(expense.amount)}'),
          const SizedBox(height: 14),
          Row(children: [
            _Amount(label: 'Your share', value: expense.userShare),
            _Amount(label: 'To receive', value: recoverable),
            _Amount(label: 'Pending', value: pending),
          ]),
        ])),
        const SizedBox(height: 14),
        Text('PARTICIPANTS', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        for (final participant in expense.splitWith)
          _ParticipantRow(
              expense: expense,
              participant: participant,
              reimbursements: reimbursements),
      ]),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        FittedBox(
            child: Text(money(value),
                style: const TextStyle(fontWeight: FontWeight.w900)))
      ]));
}

class _ParticipantRow extends ConsumerWidget {
  const _ParticipantRow(
      {required this.expense,
      required this.participant,
      required this.reimbursements});
  final TrackrTransaction expense;
  final SplitParticipant participant;
  final List<Reimbursement> reimbursements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final received = reimbursements
        .where((item) => item.participantId == participant.id)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final pending = participant.amount - received;
    final status = pending <= 0
        ? 'Fully received'
        : received > 0
            ? 'Partially received'
            : 'Pending';
    return GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          CircleAvatar(
              child: Text(participant.name.isEmpty
                  ? '?'
                  : participant.name[0].toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(participant.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                    '$status • ${money(received)} received • ${money(pending)} pending',
                    style: Theme.of(context).textTheme.bodySmall)
              ])),
          if (pending > .001)
            IconButton(
                tooltip: 'Received amount',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _receive(context, ref, pending)),
        ]));
  }

  Future<void> _receive(
      BuildContext context, WidgetRef ref, double pending) async {
    final controller = TextEditingController(text: pending.toStringAsFixed(0));
    final amount = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Received from ${participant.name}'),
                content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        prefixText: '₹ ',
                        helperText: 'Maximum ${money(pending)}')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(
                          context, double.tryParse(controller.text)),
                      child: const Text('Record'))
                ]));
    controller.dispose();
    if (amount == null || amount <= 0 || amount - pending > .001) {
      if (amount != null && context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Received amount cannot exceed the pending amount.')));
      return;
    }
    await ref.read(reimbursementProvider.notifier).add(Reimbursement(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        expenseId: expense.id,
        participantId: participant.id,
        amount: amount,
        receivedAt: DateTime.now()));
  }
}
