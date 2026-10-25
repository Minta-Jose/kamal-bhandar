import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/firebase.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/widgets.dart';

/// Version of the privacy policy the customer agrees to; bump it when the policy changes.
const consentVersion = '2026-10';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _mobile = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  final Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    // A rejected customer applying again starts from what they sent before.
    final s = ref.read(sessionProvider).value;
    if (s is Customer) {
      final p = s.profile;
      _first.text = p.firstName;
      _last.text = p.lastName;
      _mobile.text = p.mobile.replaceFirst('+91', '');
      _line1.text = p.address.line1;
      _line2.text = p.address.line2;
      _landmark.text = p.address.landmark;
      _city.text = p.address.city;
      _state.text = p.address.state;
      _pincode.text = p.address.pincode;
    } else if (s is NeedsProfile) {
      final parts = (s.user.displayName ?? '').trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) _first.text = parts.first;
      if (parts.length > 1) _last.text = parts.sublist(1).join(' ');
    }
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _mobile, _line1, _line2, _landmark, _city, _state, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String what) => (v ?? '').trim().isEmpty ? 'Enter $what' : null;

  Future<void> _submit() async {
    setState(_serverErrors.clear);
    if (!_form.currentState!.validate()) return;
    if (!_consent) {
      showSnack(context, 'Please accept the privacy policy to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).registerProfile({
        'firstName': _first.text,
        'lastName': _last.text,
        'mobile': _mobile.text,
        'address': Address(
          line1: _line1.text,
          line2: _line2.text,
          landmark: _landmark.text,
          city: _city.text,
          state: _state.text,
          pincode: _pincode.text,
        ).toMap(),
        'consentVersion': consentVersion,
      });
      // The session stream moves to "waiting for approval" by itself.
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.field != null) {
        setState(() => _serverErrors[e.field!] = e.message);
        _form.currentState!.validate();
      }
      showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? serverKey,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? prefix,
    String? hint,
    TextCapitalization caps = TextCapitalization.words,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, prefixText: prefix, hintText: hint),
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: caps,
        textInputAction: TextInputAction.next,
        validator: (v) => (serverKey != null ? _serverErrors[serverKey] : null) ?? validator?.call(v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your details'),
        actions: [
          TextButton(onPressed: () => ref.read(authRepositoryProvider).signOut(), child: const Text('Sign out')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'The store checks every new customer. Use your real name and the number the store can call you on.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(_first, 'First name', serverKey: 'firstName', validator: (v) => _required(v, 'your first name'))),
                const SizedBox(width: 12),
                Expanded(child: _field(_last, 'Last name', serverKey: 'lastName', validator: (v) => _required(v, 'your last name'))),
              ],
            ),
            _field(
              _mobile,
              'Mobile number',
              serverKey: 'mobile',
              prefix: '+91 ',
              keyboard: TextInputType.phone,
              formatters: [...digits, LengthLimitingTextInputFormatter(10)],
              validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '') ? null : 'Enter a 10-digit mobile number',
            ),
            const SectionTitle('Address'),
            _field(_line1, 'House / flat and street', serverKey: 'address.line1', validator: (v) => _required(v, 'your house and street')),
            _field(_line2, 'Area / locality (optional)'),
            _field(_landmark, 'Landmark (optional)'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(_city, 'City', serverKey: 'address.city', validator: (v) => _required(v, 'the city'))),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _pincode,
                    'Pincode',
                    serverKey: 'address.pincode',
                    keyboard: TextInputType.number,
                    formatters: [...digits, LengthLimitingTextInputFormatter(6)],
                    validator: (v) => RegExp(r'^[1-9]\d{5}$').hasMatch(v ?? '') ? null : '6 digits',
                  ),
                ),
              ],
            ),
            _field(_state, 'State', serverKey: 'address.state', validator: (v) => _required(v, 'the state')),
            CheckboxListTile(
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I agree that the store keeps my name, mobile and address to handle my orders.'),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => context.push('/policy'),
                  child: const Text('Read the privacy policy'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send for approval'),
            ),
          ],
        ),
      ),
    );
  }
}
