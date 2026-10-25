import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/cart.dart';
import '../../core/data/catalogue.dart';
import '../../core/data/firebase.dart';
import '../../core/data/messaging.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

Future<void> signOut(WidgetRef ref) async {
  await Messaging.instance.unregister();
  ref.read(cartProvider.notifier).clearLocal();
  await ref.read(authRepositoryProvider).signOut();
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final settings = ref.watch(settingsProvider).value;
    if (session is! Customer) return const Scaffold(body: SizedBox());
    final p = session.profile;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.fullName, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(p.mobile),
                  if (p.email != null) Text(p.email!, style: t.bodySmall?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(p.address.oneLine, style: t.bodyMedium),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _EditProfileSheet(profile: p),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit name and address'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'To change your mobile number, please ask the store.',
            style: t.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                if (settings != null && settings.storePhone.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.call_outlined),
                    title: const Text('Call the store'),
                    subtitle: Text(settings.storePhone),
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: settings.storePhone)),
                  ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  onTap: () => context.push('/policy'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () => signOut(ref),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                  title: const Text('Delete my account', style: TextStyle(color: AppColors.danger)),
                  onTap: () => _delete(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Delete your account?',
      message:
          'Your name, mobile, address and cart are removed. Past orders stay with the store for its accounts, without your details. This cannot be undone.',
      ok: 'Delete',
      cancel: 'Keep account',
      danger: true,
    );
    if (!ok) return;
    try {
      await Messaging.instance.unregister();
      await ref.read(apiProvider).deleteAccount();
      await ref.read(catalogueRepositoryProvider).clearCache();
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});
  final AppUser profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _last = TextEditingController(text: widget.profile.lastName);
  late final _line1 = TextEditingController(text: widget.profile.address.line1);
  late final _line2 = TextEditingController(text: widget.profile.address.line2);
  late final _landmark = TextEditingController(text: widget.profile.address.landmark);
  late final _city = TextEditingController(text: widget.profile.address.city);
  late final _state = TextEditingController(text: widget.profile.address.state);
  late final _pincode = TextEditingController(text: widget.profile.address.pincode);
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(firestoreProvider).doc('users/${widget.profile.uid}').update({
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'address': Address(
          line1: _line1.text.trim(),
          line2: _line2.text.trim(),
          landmark: _landmark.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          pincode: _pincode.text.trim(),
        ).toMap(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? need(String? v) => (v ?? '').trim().length < 2 ? 'Required' : null;
    Widget f(TextEditingController c, String label, {String? Function(String?)? v, TextInputType? k}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(controller: c, decoration: InputDecoration(labelText: label), validator: v, keyboardType: k),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Edit details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            f(_first, 'First name', v: (x) => (x ?? '').trim().isEmpty ? 'Required' : null),
            f(_last, 'Last name', v: (x) => (x ?? '').trim().isEmpty ? 'Required' : null),
            f(_line1, 'House / flat and street', v: (x) => (x ?? '').trim().length < 3 ? 'Required' : null),
            f(_line2, 'Area / locality'),
            f(_landmark, 'Landmark'),
            f(_city, 'City', v: need),
            f(_state, 'State', v: need),
            f(_pincode, 'Pincode', k: TextInputType.number, v: (x) => RegExp(r'^[1-9]\d{5}$').hasMatch(x ?? '') ? null : '6 digits'),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

/// The same policy is published on the web for the Play Store listing (hosting/public/privacy.html).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget h(String s) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(s, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Kamal Bhandar respects your privacy. This policy explains what the app keeps and why.', style: t.bodyLarge),
          h('What we collect'),
          const Text('Your name, mobile number, address and Google account email, the orders you place, and a notification token for your phone.'),
          h('Why'),
          const Text('To check that you are a real customer, prepare your orders for pickup, contact you about them and keep the store\'s accounts.'),
          h('Where it is stored'),
          const Text('In Google Firebase, in India (Mumbai). Only the store owner can see customer details. We never sell or share your data.'),
          h('How long'),
          const Text('As long as you have an account. If you delete your account, your details are removed and past orders are kept without your name or address.'),
          h('Your rights'),
          const Text('You can see and correct your details in Profile, and delete your account at any time from Profile. For any question or complaint, contact the store owner.'),
        ],
      ),
    );
  }
}
