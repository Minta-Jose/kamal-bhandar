import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/cart.dart';
import '../../core/data/catalogue.dart';
import '../../core/data/firebase.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'cart_screen.dart';

/// Last look before the order is locked.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    final ok = await confirm(
      context,
      title: 'Confirm order?',
      message: 'Once confirmed you cannot change this order. The store may adjust it if something is short, and will let you know.',
      ok: 'Confirm order',
      cancel: 'Go back',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(cartProvider.notifier).save();
      final r = await ref.read(apiProvider).placeOrder(note: _note.text);
      ref.read(cartProvider.notifier).clearLocal();
      if (mounted) context.go('/cart/placed/${r.orderId}');
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.problems.isNotEmpty) {
        // Prices or stock changed since the catalogue was loaded.
        ref.invalidate(catalogueProvider);
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Some items need attention'),
            content: Text(e.problems.map((p) => '• ${p.reason}').join('\n')),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fix my cart'))],
          ),
        );
        if (mounted) context.pop();
      } else {
        showSnack(context, e.message);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = cartRows(ref.watch(cartProvider), ref.watch(catalogueProvider).value);
    final settings = ref.watch(settingsProvider).value;
    final showPrices = ref.watch(showPricesProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Review order')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                for (final r in rows)
                  ListTile(
                    title: Text(r.product?.name ?? ''),
                    subtitle: r.product?.nameHi.isNotEmpty == true ? Text(r.product!.nameHi) : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(r.mode == null ? '' : formatQty(r.mode!, r.item.qty), style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (r.mode != null) PriceText(r.mode!.lineTotalPaise(r.item.qty), style: t.bodySmall),
                      ],
                    ),
                  ),
                if (showPrices)
                  ListTile(
                    title: const Text('Estimated total', style: TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Text(formatRupees(cartTotalPaise(rows)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront, color: AppColors.green),
              title: const Text('Pickup from the store'),
              subtitle: Text([
                if (settings?.storeAddress.isNotEmpty == true) settings!.storeAddress,
                if (settings?.pickupHours.isNotEmpty == true) 'Open ${settings!.pickupHours}',
                'Pay at pickup by cash, UPI or card',
              ].join('\n')),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note for the store (optional)', hintText: 'e.g. I will come at 6 pm'),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.turmeric.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline),
                SizedBox(width: 10),
                Expanded(child: Text('After you confirm, the order is locked and cannot be edited.')),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy || rows.isEmpty ? null : _place,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirm order'),
          ),
        ),
      ),
    );
  }
}
