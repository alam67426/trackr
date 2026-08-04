String? requiredText(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}

String? amountValidator(String? value) {
  final parsed = double.tryParse((value ?? '').replaceAll(',', '').trim());
  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
  return null;
}
