import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/orders.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text(order.value?.orderNo ?? 'Order')),
      body: AsyncView(
        value: order,
        data: (o) => o == null
            ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Order not found')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [StatusChip(o.status), const Spacer(), Text(formatDate(o.placedAt))]),
                  if (o.status == OrderStatus.adjusted) ...[
                    const SizedBox(height: 12),
                    const _Banner(
                      icon: Icons.edit_note,
                      text: 'The store changed some quantities. Changed items are marked below.',
                    ),
                  ],
                  if (o.status == OrderStatus.ready) ...[
                    const SizedBox(height: 12),
                    const _Banner(icon: Icons.shopping_bag_outlined, text: 'Your order is packed. Pick it up at the store and pay there.'),
                  ],
                  const SizedBox(height: 16),
                  OrderItemsCard(order: o),
                  if (o.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(child: ListTile(leading: const Icon(Icons.sticky_note_2_outlined), title: const Text('Your note'), subtitle: Text(o.note))),
                  ],
                  if (o.paymentMethod != null) ...[
                    const SizedBox(height: 12),
                    Card(child: ListTile(leading: const Icon(Icons.payments_outlined), title: Text('Paid by ${o.paymentMethod!.label}'))),
                  ],
                  const SectionTitle('Timeline'),
                  StatusTimeline(order: o),
                ],
              ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.turmeric.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Text(text))]),
    );
  }
}

/// Every item with its quantity; changed lines are marked.
class OrderItemsCard extends ConsumerWidget {
  const OrderItemsCard({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPrices = ref.watch(showPricesProvider);
    final t = Theme.of(context).textTheme;
    return Card(
      child: Column(
        children: [
          for (final line in order.items)
            ListTile(
              dense: true,
              title: Text(line.name, style: t.bodyLarge),
              subtitle: line.adjusted
                  ? const Text('Changed by store', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600))
                  : null,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(line.unitLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (showPrices) Text(formatRupees(line.lineTotalPaise), style: t.bodySmall),
                ],
              ),
            ),
          const Divider(height: 1),
          ListTile(
            title: Text('${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: showPrices
                ? Text(formatRupees(order.totalPaise), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))
                : const Text('Pay at pickup'),
          ),
        ],
      ),
    );
  }
}

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < order.history.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: i == order.history.length - 1 ? AppColors.green : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < order.history.length - 1) Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.history[i].status.label, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(formatDate(order.history[i].at), style: t.bodySmall?.copyWith(color: Colors.black54)),
                        if (order.history[i].note.isNotEmpty) Text(order.history[i].note, style: t.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
