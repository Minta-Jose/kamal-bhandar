import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/orders.dart';
import '../../core/ui/widgets.dart';
import '../orders/my_orders_screen.dart';

class OwnerOrdersScreen extends ConsumerStatefulWidget {
  const OwnerOrdersScreen({super.key});

  @override
  ConsumerState<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends ConsumerState<OwnerOrdersScreen> {
  OrderFilter _filter = OrderFilter.open;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ownerOrdersProvider(_filter));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Search name or order number', prefixIcon: Icon(Icons.search), isDense: true),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final f in OrderFilter.values) ...[
                      ChoiceChip(label: Text(f.label), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: AsyncView(
        value: orders,
        onRetry: () => ref.invalidate(ownerOrdersProvider(_filter)),
        data: (list) {
          final shown = _query.isEmpty
              ? list
              : list.where((o) => o.orderNo.toLowerCase().contains(_query) || o.customerName.toLowerCase().contains(_query)).toList();
          if (shown.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders here');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => OrderCard(
              order: shown[i],
              showPrices: true,
              showCustomer: true,
              onTap: () => context.push('/owner/orders/${shown[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
