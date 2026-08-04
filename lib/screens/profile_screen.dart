import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/common/glass_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _emailDomains = [
    'gmail.com',
    'yahoo.com',
    'yahoo.in',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'proton.me',
    'rediffmail.com',
  ];
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  String? _imagePath;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    const profile = UserProfile();
    _name = TextEditingController(text: profile.fullName);
    _age = TextEditingController();
    _phone = TextEditingController(text: profile.contactNumber);
    _email = TextEditingController(text: profile.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (!_ready) {
      _name.text = profile.fullName;
      _age.text = profile.age?.toString() ?? '';
      _phone.text = _localPhoneNumber(profile.contactNumber);
      _email.text = profile.email;
      _imagePath = profile.imagePath;
      _ready = true;
    }
    return Scaffold(
      appBar: AppBar(
          title: const Text('Profile'),
          actions: [TextButton(onPressed: _save, child: const Text('Save'))]),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Center(
                child: InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(48),
                    child: CircleAvatar(
                        radius: 46,
                        backgroundImage:
                            _imagePath != null && File(_imagePath!).existsSync()
                                ? FileImage(File(_imagePath!))
                                : null,
                        child: _imagePath == null
                            ? const Icon(Icons.person_outline, size: 42)
                            : null))),
            const SizedBox(height: 10),
            Center(
                child: TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Choose profile photo'))),
            const SizedBox(height: 14),
            GlassCard(
                child: Column(children: [
              TextFormField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Full name (optional)')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Age (optional)'),
                  validator: (value) {
                    final age = value?.trim() ?? '';
                    if (age.isEmpty) return null;
                    final number = int.tryParse(age);
                    return number != null && number >= 1 && number <= 120
                        ? null
                        : 'Enter an age between 1 and 120';
                  }),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Contact number (optional)',
                    prefixText: '+91 ',
                    hintText: '9876543210',
                  ),
                  validator: (value) {
                    final number = value?.trim() ?? '';
                    if (number.isEmpty) return null;
                    return RegExp(r'^[6-9]\d{9}$').hasMatch(number)
                        ? null
                        : 'Enter a valid 10-digit Indian mobile number';
                  }),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email address (optional)',
                    hintText: 'name@gmail.com',
                    suffixIcon: PopupMenuButton<String>(
                      tooltip: 'Choose email domain',
                      icon: const Icon(Icons.alternate_email),
                      onSelected: _applyEmailDomain,
                      itemBuilder: (context) => _emailDomains
                          .map((domain) => PopupMenuItem(
                              value: domain, child: Text('@$domain')))
                          .toList(),
                    ),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return null;
                    return RegExp(
                            r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$")
                        .hasMatch(email)
                        ? null
                        : 'Use a valid address, for example name@gmail.com';
                  }),
            ])),
          ])),
    );
  }

  Future<void> _pickImage() async {
    final path = await ref.read(profileProvider.notifier).pickImage();
    if (path != null && mounted) setState(() => _imagePath = path);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(profileProvider.notifier).save(UserProfile(
        fullName: _name.text.trim(),
        age: int.tryParse(_age.text),
        contactNumber: _phone.text.trim().isEmpty
            ? ''
            : '+91${_phone.text.trim()}',
        email: _email.text.trim(),
        imagePath: _imagePath));
    if (mounted) Navigator.pop(context);
  }

  String _localPhoneNumber(String storedNumber) {
    final digits = storedNumber.replaceAll(RegExp(r'\D'), '');
    return digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits.length > 10
            ? digits.substring(digits.length - 10)
            : digits;
  }

  void _applyEmailDomain(String domain) {
    final username = _email.text.trim().split('@').first;
    _email.value = TextEditingValue(
      text: '${username.isEmpty ? 'name' : username}@$domain',
      selection: TextSelection.collapsed(
          offset: '${username.isEmpty ? 'name' : username}@$domain'.length),
    );
  }
}
