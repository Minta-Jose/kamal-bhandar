import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/orders.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/widgets.dart';

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final showPrices = ref.watch(showPricesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: AsyncView(
        value: orders,
        onRetry: () => ref.invalidate(myOrdersProvider),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                message: 'Your orders and their status will show here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => OrderCard(
                  order: list[i],
                  showPrices: showPrices,
                  onTap: () => context.push('/orders/${list[i].id}'),
                ),
              ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap, this.showPrices = false, this.showCustomer = false});
  final CustomerOrder order;
  final VoidCallback onTap;
  final bool showPrices;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final preview = order.items.take(3).map((l) => '${l.name} ${l.unitLabel}').join(', ');
    final more = order.items.length > 3 ? ' +${order.items.length - 3} more' : '';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order.orderNo, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                  StatusChip(order.status),
                ],
              ),
              if (showCustomer) ...[
                const SizedBox(height: 4),
                Text(order.customerName, style: t.titleSmall),
              ],
              const SizedBox(height: 6),
              Text('$preview$more', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: Colors.black87)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(formatDate(order.placedAt), style: t.bodySmall?.copyWith(color: Colors.black54)),
                  const Spacer(),
                  if (showPrices) Text(formatRupees(order.totalPaise), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
