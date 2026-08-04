import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../utils/constants.dart';
import '../widgets/transactions/add_transaction_dialog.dart';
import '../widgets/transactions/transaction_list_tile.dart';
import '../widgets/common/glass_card.dart';
import 'settlement_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _query = '';
  TransactionType? _type;
  String? _category;
  String _sort = 'newest';

  @override
  Widget build(BuildContext context) {
    var transactions = [...ref.watch(transactionProvider)];
    transactions = transactions.where((t) {
      final matchesQuery = _query.isEmpty ||
          t.description.toLowerCase().contains(_query.toLowerCase());
      final matchesType = _type == null || t.type == _type;
      final matchesCategory = _category == null || t.categoryId == _category;
      return matchesQuery && matchesType && matchesCategory;
    }).toList();
    transactions.sort((a, b) {
      return switch (_sort) {
        'oldest' => a.dateTime.compareTo(b.dateTime),
        'high' => b.amount.compareTo(a.amount),
        'low' => a.amount.compareTo(b.amount),
        _ => b.dateTime.compareTo(a.dateTime),
      };
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Add transaction',
            onPressed: _openForm,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search merchants or people'),
                      onChanged: (v) => setState(() => _query = v)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterMenu<TransactionType?>(
                          icon: Icons.swap_horiz,
                          value: _type,
                          hint: 'Type',
                          items: [null, ...TransactionType.values]
                              .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t?.name ?? 'All types')))
                              .toList(),
                          onChanged: (v) => setState(() => _type = v),
                        ),
                        const SizedBox(width: 12),
                        _FilterMenu<String?>(
                          icon: Icons.category_outlined,
                          value: _category,
                          hint: 'Category',
                          items: [null, ...AppCategories.all.map((c) => c.id)]
                              .map((id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(id == null
                                      ? 'All categories'
                                      : AppCategories.byId(id).name)))
                              .toList(),
                          onChanged: (v) => setState(() => _category = v),
                        ),
                        const SizedBox(width: 12),
                        _FilterMenu<String>(
                          icon: Icons.sort,
                          value: _sort,
                          hint: 'Sort',
                          items: const [
                            DropdownMenuItem(
                                value: 'newest', child: Text('Newest')),
                            DropdownMenuItem(
                                value: 'oldest', child: Text('Oldest')),
                            DropdownMenuItem(
                                value: 'high', child: Text('Amount high')),
                            DropdownMenuItem(
                                value: 'low', child: Text('Amount low')),
                          ],
                          onChanged: (v) =>
                              setState(() => _sort = v ?? 'newest'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: transactions.isEmpty
                ? const _EmptyTransactions()
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      return TransactionListTile(
                        transaction: tx,
                        onTap: tx.splitWith.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        SettlementScreen(expense: tx))),
                        onEdit: () => _openForm(tx),
                        onDelete: () => ref
                            .read(transactionProvider.notifier)
                            .delete(tx.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm([TrackrTransaction? transaction]) async {
    final result = await showDialog<TrackrTransaction>(
        context: context,
        builder: (context) => AddTransactionDialog(initial: transaction));
    if (result == null) return;
    if (transaction == null) {
      await ref.read(transactionProvider.notifier).add(result);
    } else {
      await ref.read(transactionProvider.notifier).update(result);
    }
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.icon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF202838),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.expand_more, size: 18),
          hint: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(hint),
          ]),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_outlined,
              size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text('No transactions found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Try a different search or add one manually.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
