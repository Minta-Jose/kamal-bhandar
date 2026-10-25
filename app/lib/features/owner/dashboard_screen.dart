import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/orders.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import '../orders/my_orders_screen.dart';

/// What needs the owner's attention right now.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCustomersProvider).value ?? const [];
    final open = ref.watch(ownerOrdersProvider(OrderFilter.open));
    final orders = open.value ?? const <CustomerOrder>[];
    final fresh = orders.where((o) => o.status == OrderStatus.placed || o.status == OrderStatus.adjusted).toList();
    final ready = orders.where((o) => o.status == OrderStatus.ready).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _Stat(label: 'To pack', value: fresh.length, color: Colors.blue.shade700, onTap: () => context.go('/owner/orders'))),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Ready for pickup', value: ready, color: AppColors.green, onTap: () => context.go('/owner/orders'))),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Sign-ups waiting', value: pending.length, color: Colors.deepOrange, onTap: () => context.go('/owner/customers'))),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const SectionTitle('Customers waiting for approval'),
            Card(
              child: Column(
                children: [
                  for (final u in pending.take(5))
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(u.fullName),
                      subtitle: Text('${u.mobile} · ${u.address.line2.isNotEmpty ? u.address.line2 : u.address.city}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/owner/customers'),
                    ),
                ],
              ),
            ),
          ],
          const SectionTitle('Orders to pack'),
          if (open.isLoading && !open.hasValue)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (fresh.isEmpty)
            const Card(child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('No new orders right now')))
          else
            for (final o in fresh) ...[
              OrderCard(order: o, showPrices: true, showCustomer: true, onTap: () => context.push('/owner/orders/${o.id}')),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 16),
          Card(
            color: AppColors.turmeric.withValues(alpha: 0.1),
            child: const ListTile(
              leading: Icon(Icons.notifications_active_outlined),
              title: Text('Not getting order alerts?'),
              subtitle: Text('In your phone\'s Settings, open Apps › Kamal Bhandar › Battery and choose "Unrestricted" or "No restrictions".'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color, required this.onTap});
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
