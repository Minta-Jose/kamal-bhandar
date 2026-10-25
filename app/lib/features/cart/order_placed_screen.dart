import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/orders.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import '../orders/order_detail_screen.dart';

/// The list of everything ordered, right after confirming.
class OrderPlacedScreen extends ConsumerWidget {
  const OrderPlacedScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Order placed')),
      body: AsyncView(
        value: order,
        data: (o) {
          if (o == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Icon(Icons.check_circle, color: AppColors.green, size: 72),
              const SizedBox(height: 12),
              Text('Thank you!', textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Order ${o.orderNo} has been sent to the store. We will notify you when it is ready for pickup.',
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              OrderItemsCard(order: o),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => context.go('/orders'), child: const Text('My orders'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => context.go('/shop'),
                  child: const Text('Keep shopping'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
