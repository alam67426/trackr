import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/transaction_model.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

class AddTransactionDialog extends StatefulWidget {
  const AddTransactionDialog({super.key, this.initial});

  final TrackrTransaction? initial;

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TransactionType _type;
  late UpiApp _upiApp;
  late String _categoryId;
  late DateTime _dateTime;
  late TextEditingController _amount;
  late TextEditingController _description;
  late TextEditingController _note;
  late TextEditingController _split;
  late TextEditingController _participantCount;
  bool _splitEnabled = false;
  bool _includeUser = true;
  bool _equalSplit = true;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _type = item?.type ?? TransactionType.expense;
    _upiApp = item?.upiApp ?? UpiApp.none;
    _categoryId = item?.categoryId ?? 'food';
    _dateTime = item?.dateTime ?? DateTime.now();
    _amount = TextEditingController(
        text: item == null ? '' : item.amount.toStringAsFixed(0));
    _description = TextEditingController(text: item?.description ?? '');
    _note = TextEditingController(text: item?.note ?? '');
    _split = TextEditingController(
        text: item?.splitWith.map((e) => e.name).join(', ') ?? '');
    _participantCount =
        TextEditingController(text: item?.splitWith.length.toString() ?? '');
    _splitEnabled = item?.splitWith.isNotEmpty ?? false;
    _includeUser = item?.splitIncludesUser ?? true;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _note.dispose();
    _split.dispose();
    _participantCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.initial == null ? 'Add transaction' : 'Edit transaction'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_upward)),
                  ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(
                      value: TransactionType.transfer,
                      label: Text('Transfer'),
                      icon: Icon(Icons.swap_horiz)),
                ],
                selected: {_type},
                onSelectionChanged: (value) => setState(() {
                  _type = value.first;
                  if (_type == TransactionType.transfer)
                    _categoryId = 'friends';
                  if (_type == TransactionType.income) _categoryId = 'salary';
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                validator: amountValidator,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(
                    prefixText: '₹ ', labelText: 'Amount'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                  controller: _description,
                  validator: requiredText,
                  decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppCategories.all.map((category) {
                  return DropdownMenuItem(
                      value: category.id, child: Text(category.name));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _categoryId = value ?? _categoryId),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date & time'),
                subtitle: Text(_dateTime.toString().substring(0, 16)),
                trailing: const Icon(Icons.calendar_month),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 14),
              TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Note')),
              const SizedBox(height: 14),
              if (_type == TransactionType.expense) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Split among others'),
                  subtitle:
                      const Text('Track repayments separately from income'),
                  value: _splitEnabled,
                  onChanged: (value) => setState(() => _splitEnabled = value),
                ),
                if (_splitEnabled) ...[
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Equal split')),
                      ButtonSegment(
                          value: false, label: Text('Custom amounts')),
                    ],
                    selected: {_equalSplit},
                    onSelectionChanged: (value) =>
                        setState(() => _equalSplit = value.first),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include me in the split'),
                    subtitle: Text(_includeUser
                        ? 'Your share is included'
                        : 'Others repay the full bill'),
                    value: _includeUser,
                    onChanged: (value) => setState(() => _includeUser = value),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _participantCount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Number of other participants'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _split,
                    decoration: InputDecoration(
                      labelText: _equalSplit
                          ? 'Participant names'
                          : 'Participant names and amounts',
                      hintText: _equalSplit
                          ? 'Raj, Priya, Sam'
                          : 'Raj:1500, Priya:1000',
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<UpiApp>(
                value: _upiApp,
                decoration: const InputDecoration(labelText: 'UPI App'),
                items: UpiApp.values
                    .map((app) =>
                        DropdownMenuItem(value: app, child: Text(app.name)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _upiApp = value ?? UpiApp.none),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Save transaction')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: _dateTime);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_dateTime));
    if (time == null) return;
    setState(() => _dateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    final amount = double.parse(_amount.text);
    final splitResult = _buildSplits(amount);
    if (splitResult == null) return;
    Navigator.of(context).pop(
      TrackrTransaction(
        id: widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        type: _type,
        amount: amount,
        description: _description.text.trim(),
        categoryId: _categoryId,
        dateTime: _dateTime,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        upiApp: _upiApp,
        splitWith: splitResult.participants,
        splitIncludesUser: _includeUser,
        userShare: splitResult.userShare,
      ),
    );
  }

  _SplitResult? _buildSplits(double amount) {
    if (!_splitEnabled) return const _SplitResult([], 0);
    final parts = _split.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final expectedCount = int.tryParse(_participantCount.text);
    if (parts.isEmpty ||
        expectedCount == null ||
        expectedCount != parts.length) {
      _showSplitError('Enter a name for each participant.');
      return null;
    }
    final divisor = parts.length + (_includeUser ? 1 : 0);
    if (_equalSplit && divisor == 0) {
      _showSplitError('Include yourself or at least one participant.');
      return null;
    }
    if (_equalSplit) {
      final share = amount / divisor;
      return _SplitResult(
          List.generate(
              parts.length,
              (index) => SplitParticipant(
                  id: '${DateTime.now().microsecondsSinceEpoch}_$index',
                  name: parts[index],
                  amount: share)),
          _includeUser ? share : 0);
    }
    final participants = <SplitParticipant>[];
    for (var index = 0; index < parts.length; index++) {
      final pieces = parts[index].split(':');
      final value =
          pieces.length == 2 ? double.tryParse(pieces[1].trim()) : null;
      if (pieces.length != 2 ||
          pieces.first.trim().isEmpty ||
          value == null ||
          value <= 0) {
        _showSplitError('Use Name:amount for every custom split.');
        return null;
      }
      participants.add(SplitParticipant(
          id: '${DateTime.now().microsecondsSinceEpoch}_$index',
          name: pieces.first.trim(),
          amount: value));
    }
    final recoverable =
        participants.fold<double>(0, (sum, item) => sum + item.amount);
    if (recoverable > amount || (!_includeUser && recoverable != amount)) {
      _showSplitError(
          'Custom participant amounts cannot exceed the bill and must equal it when you are excluded.');
      return null;
    }
    return _SplitResult(participants, _includeUser ? amount - recoverable : 0);
  }

  void _showSplitError(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class _SplitResult {
  const _SplitResult(this.participants, this.userShare);
  final List<SplitParticipant> participants;
  final double userShare;
}
