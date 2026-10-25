import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/firebase.dart';
import '../../core/data/orders.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import '../orders/order_detail_screen.dart';

/// The owner's view of one order: who, what, and the next step.
class OwnerOrderScreen extends ConsumerStatefulWidget {
  const OwnerOrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OwnerOrderScreen> createState() => _OwnerOrderScreenState();
}

class _OwnerOrderScreenState extends ConsumerState<OwnerOrderScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markReady(CustomerOrder o) =>
      _run(() => ref.read(apiProvider).setOrderStatus(o.id, 'ready'), '${o.orderNo} is ready; the customer has been told');

  Future<void> _pickedUp(CustomerOrder o) async {
    final method = await showModalBottomSheet<PaymentMethod>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('How did the customer pay?', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final m in PaymentMethod.values)
              ListTile(
                leading: Icon(switch (m) {
                  PaymentMethod.cash => Icons.payments_outlined,
                  PaymentMethod.upi => Icons.qr_code_2,
                  PaymentMethod.card => Icons.credit_card,
                }),
                title: Text(m.label),
                onTap: () => Navigator.pop(c, m),
              ),
          ],
        ),
      ),
    );
    if (method == null) return;
    await _run(
      () => ref.read(apiProvider).setOrderStatus(o.id, 'picked_up', paymentMethod: method.name),
      '${o.orderNo} picked up, paid by ${method.label}',
    );
  }

  Future<void> _cancel(CustomerOrder o) async {
    final reason = await _askText(title: 'Cancel ${o.orderNo}?', hint: 'Reason for the customer (optional)', ok: 'Cancel order');
    if (reason == null) return;
    await _run(() => ref.read(apiProvider).setOrderStatus(o.id, 'cancelled', note: reason), '${o.orderNo} cancelled');
  }

  Future<void> _adjust(CustomerOrder o) async {
    final result = await Navigator.of(context).push<_AdjustResult>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _AdjustScreen(order: o)),
    );
    if (result == null || result.changes.isEmpty) return;
    await _run(
      () => ref.read(apiProvider).adjustOrder(o.id, result.changes, note: result.note),
      'Order updated; the customer has been told',
    );
  }

  Future<String?> _askText({required String title, required String hint, required String ok}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, maxLength: 200, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Back')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: Text(ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(order.value?.orderNo ?? 'Order')),
      body: AsyncView(
        value: order,
        data: (o) {
          if (o == null) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Order not found');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [StatusChip(o.status), const Spacer(), Text(formatDate(o.placedAt))]),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([o.customerMobile ?? '', o.customerAddress?.oneLine ?? ''].where((s) => s.isNotEmpty).join('\n')),
                  isThreeLine: o.customerAddress != null,
                  trailing: o.customerMobile == null
                      ? null
                      : IconButton.filledTonal(
                          onPressed: () => launchUrl(Uri(scheme: 'tel', path: o.customerMobile)),
                          icon: const Icon(Icons.call),
                        ),
                ),
              ),
              if (o.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Card(
                  color: AppColors.turmeric.withValues(alpha: 0.12),
                  child: ListTile(leading: const Icon(Icons.sticky_note_2_outlined), title: const Text('Customer note'), subtitle: Text(o.note)),
                ),
              ],
              const SizedBox(height: 12),
              OrderItemsCard(order: o),
              if (o.paymentMethod != null) ...[
                const SizedBox(height: 10),
                Card(child: ListTile(leading: const Icon(Icons.payments_outlined), title: Text('Paid by ${o.paymentMethod!.label}'))),
              ],
              const SectionTitle('Timeline'),
              StatusTimeline(order: o),
            ],
          );
        },
      ),
      bottomNavigationBar: switch (order.value) {
        final CustomerOrder o when o.status.isOpen => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _adjust(o),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Adjust items'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                          onPressed: _busy ? null : () => _cancel(o),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (o.status == OrderStatus.ready)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _pickedUp(o),
                      icon: const Icon(Icons.handshake_outlined),
                      label: const Text('Picked up and paid'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _markReady(o),
                      icon: const Icon(Icons.inventory_outlined),
                      label: const Text('Packed, ready for pickup'),
                    ),
                ],
              ),
            ),
          ),
        _ => null,
      },
    );
  }
}

class _AdjustResult {
  _AdjustResult(this.changes, this.note);
  final List<Map<String, dynamic>> changes;
  final String note;
}

/// Lets the owner change quantities or remove items. Prices stay as ordered.
class _AdjustScreen extends StatefulWidget {
  const _AdjustScreen({required this.order});
  final CustomerOrder order;

  @override
  State<_AdjustScreen> createState() => _AdjustScreenState();
}

class _AdjustScreenState extends State<_AdjustScreen> {
  late final Map<String, int> _qty = {for (final l in widget.order.items) '${l.productId}:${l.mode.name}': l.qty};
  final _note = TextEditingController();

  String _key(OrderLine l) => '${l.productId}:${l.mode.name}';

  Future<void> _edit(OrderLine l) async {
    final isWeight = l.mode == SellModeKind.weight;
    final c = TextEditingController(text: '${_qty[_key(l)]}');
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.name),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            suffixText: switch (l.mode) {
              SellModeKind.weight => 'grams',
              SellModeKind.piece => 'pcs',
              SellModeKind.bag => 'bags',
            },
            helperText: isWeight ? '1 kg = 1000 g' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(d, int.tryParse(c.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (v != null && v >= 0) setState(() => _qty[_key(l)] = v);
  }

  @override
  Widget build(BuildContext context) {
    final changes = [
      for (final l in widget.order.items)
        if (_qty[_key(l)] != l.qty) {'productId': l.productId, 'mode': l.mode.name, 'qty': _qty[_key(l)]},
    ];
    final remaining = widget.order.items.where((l) => (_qty[_key(l)] ?? 0) > 0).length;
    var total = 0;
    for (final l in widget.order.items) {
      total += l.sellMode.lineTotalPaise(_qty[_key(l)] ?? 0);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Adjust items')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tap a quantity to change it. Set it to 0 or tap the bin to remove an item.'),
          const SizedBox(height: 12),
          for (final l in widget.order.items)
            Card(
              child: ListTile(
                title: Text(l.name, style: TextStyle(decoration: _qty[_key(l)] == 0 ? TextDecoration.lineThrough : null)),
                subtitle: Text(_qty[_key(l)] == l.qty
                    ? 'Ordered ${l.unitLabel}'
                    : 'Ordered ${l.unitLabel} → ${_qty[_key(l)] == 0 ? 'removed' : formatQty(l.sellMode, _qty[_key(l)]!)}'),
                onTap: () => _edit(l),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () => _edit(l), icon: const Icon(Icons.edit_outlined)),
                    IconButton(onPressed: () => setState(() => _qty[_key(l)] = 0), icon: const Icon(Icons.delete_outline)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          ListTile(title: const Text('New total'), trailing: Text(formatRupees(total), style: const TextStyle(fontWeight: FontWeight.w800))),
          TextField(
            controller: _note,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Message for the customer (optional)', hintText: 'e.g. Only 900 g of toor dal left'),
          ),
          if (remaining == 0)
            const Text('An order needs at least one item. To drop everything, cancel the order instead.',
                style: TextStyle(color: AppColors.danger)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: changes.isEmpty || remaining == 0
                ? null
                : () => Navigator.pop(context, _AdjustResult(changes, _note.text.trim())),
            child: Text(changes.isEmpty ? 'No changes yet' : 'Save ${changes.length} ${changes.length == 1 ? 'change' : 'changes'}'),
          ),
        ),
      ),
    );
  }
}
