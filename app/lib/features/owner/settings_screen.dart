import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/firebase.dart';
import '../../core/data/owner.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/widgets.dart';
import '../profile/profile_screen.dart';

class OwnerSettingsScreen extends ConsumerStatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  ConsumerState<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends ConsumerState<OwnerSettingsScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _hours = TextEditingController();
  final _grievance = TextEditingController();
  bool _showPrices = false;
  int _minAppVersion = 0;
  bool _loaded = false;
  bool _busy = false;

  void _load(StoreSettings? s) {
    if (_loaded || s == null) return;
    _name.text = s.storeName;
    _address.text = s.storeAddress;
    _phone.text = s.storePhone;
    _hours.text = s.pickupHours;
    _grievance.text = s.grievanceContact;
    _showPrices = s.showPrices;
    _minAppVersion = s.minAppVersion;
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(ownerRepositoryProvider).saveSettings(StoreSettings(
            storeName: _name.text.trim().isEmpty ? 'Kamal Bhandar' : _name.text.trim(),
            storeAddress: _address.text.trim(),
            storePhone: _phone.text.trim(),
            pickupHours: _hours.text.trim(),
            grievanceContact: _grievance.text.trim(),
            showPrices: _showPrices,
            minAppVersion: _minAppVersion,
          ));
      if (mounted) showSnack(context, 'Settings saved');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _load(ref.watch(settingsProvider).value);
    Widget f(TextEditingController c, String label, {String? hint, TextInputType? k}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(controller: c, keyboardType: k, decoration: InputDecoration(labelText: label, hintText: hint)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Store details'),
          f(_name, 'Store name'),
          f(_address, 'Store address (shown for pickup)'),
          f(_phone, 'Store phone', k: TextInputType.phone, hint: '+91 98xxxxxxxx'),
          f(_hours, 'Pickup hours', hint: '9 am to 9 pm, closed Tuesday'),
          f(_grievance, 'Contact for privacy questions', hint: 'Owner name and phone or email'),
          const SectionTitle('Prices'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showPrices,
            onChanged: (v) => setState(() => _showPrices = v),
            title: const Text('Show prices to customers'),
            subtitle: const Text('Off in version 1. You always see prices and totals.'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Save settings')),
          const SizedBox(height: 24),
          const Card(
            child: ListTile(
              leading: Icon(Icons.notifications_active_outlined),
              title: Text('Order alerts'),
              subtitle: Text(
                'New orders ring with their own sound. If alerts arrive late, set this app\'s battery use to "Unrestricted" in your phone\'s settings.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => signOut(ref), icon: const Icon(Icons.logout), label: const Text('Sign out')),
        ],
      ),
    );
  }
}
