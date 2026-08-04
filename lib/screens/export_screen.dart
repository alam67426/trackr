import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/reimbursement_provider.dart';
import '../services/pdf_service.dart';
import '../widgets/common/glass_card.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String _type = 'Monthly';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights_outlined, color: Color(0xFF00CEC9)),
                const SizedBox(height: 12),
                Text('Share your money story',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                    'Generate a clean report or a spreadsheet from your local data.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Report type'),
                items: const ['Monthly', 'Quarterly', 'Yearly', 'Custom']
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _DateField(
                        label: 'From', value: _from, onTap: () => _pick(true))),
                const SizedBox(width: 10),
                Expanded(
                    child: _DateField(
                        label: 'To', value: _to, onTap: () => _pick(false))),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: _busy ? null : _pdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label:
                  Text(_busy ? 'Preparing report...' : 'Generate PDF report')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: _busy ? null : _csv,
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Export CSV spreadsheet')),
        ],
      ),
    );
  }

  Future<void> _pick(bool from) async {
    final selected = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: from ? _from : _to);
    if (selected == null) return;
    setState(() => from ? _from = selected : _to = selected);
  }

  Future<void> _pdf() async {
    setState(() => _busy = true);
    final service = PdfService();
    final file = await service.generateReport(
        transactions: ref.read(transactionProvider),
        from: _from,
        to: _to,
        reportType: _type,
        profile: ref.read(profileProvider),
        reimbursements: ref.read(reimbursementProvider));
    await service.share(file);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _csv() async {
    setState(() => _busy = true);
    final service = PdfService();
    final file = await service.generateCsv(ref.read(transactionProvider));
    await service.share(file);
    if (mounted) setState(() => _busy = false);
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF202838),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: Color(0xFF00CEC9)),
              const SizedBox(width: 6),
              Expanded(child: Text(value.toString().substring(0, 10))),
            ]),
          ]),
        ),
      );
}
