import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/cart.dart';
import '../../core/data/catalogue.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

/// A cart line joined with its product, for display.
typedef CartRow = ({CartItem item, Product? product, SellMode? mode});

List<CartRow> cartRows(List<CartItem> items, Catalogue? c) => [
      for (final i in items)
        (item: i, product: c?.products[i.productId], mode: c?.products[i.productId]?.mode(i.mode)),
    ];

int cartTotalPaise(List<CartRow> rows) =>
    rows.fold(0, (sum, r) => sum + (r.mode?.lineTotalPaise(r.item.qty) ?? 0));

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final catalogue = ref.watch(catalogueProvider).value;
    final rows = cartRows(items, catalogue);
    final showPrices = ref.watch(showPricesProvider);
    final unavailable = rows.where((r) => r.product == null || !r.product!.inStock || r.mode == null).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add products from the shop and they will appear here.',
              action: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: () => context.go('/shop'),
                child: const Text('Start shopping'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _CartRowTile(rows[i]),
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unavailable > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Remove the $unavailable unavailable ${unavailable == 1 ? 'item' : 'items'} to continue.',
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    if (showPrices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Estimated total', style: TextStyle(fontWeight: FontWeight.w600))),
                            Text(formatRupees(cartTotalPaise(rows)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          ],
                        ),
                      ),
                    FilledButton(
                      onPressed: unavailable > 0 ? null : () => context.push('/cart/review'),
                      child: Text('Review order (${items.length} ${items.length == 1 ? 'item' : 'items'})'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CartRowTile extends ConsumerWidget {
  const _CartRowTile(this.row);
  final CartRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = row.product;
    final m = row.mode;
    final t = Theme.of(context).textTheme;
    final cart = ref.read(cartProvider.notifier);
    final problem = p == null
        ? 'No longer sold'
        : !p.inStock
            ? 'Out of stock'
            : m == null
                ? 'No longer sold this way'
                : m.check(row.item.qty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Photo(p?.thumbUrl ?? p?.imageUrl, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p?.name ?? 'Unavailable product', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (m != null) Text(formatQty(m, row.item.qty), style: t.bodyMedium),
                  if (problem != null)
                    Text(problem, style: t.bodySmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600))
                  else if (m != null)
                    PriceText(m.lineTotalPaise(row.item.qty), style: t.bodySmall?.copyWith(color: Colors.black54)),
                ],
              ),
            ),
            if (p != null && m != null && problem == null) ...[
              IconButton(
                onPressed: row.item.qty > m.min ? () => cart.setQty(p.id, m.mode, row.item.qty - m.step) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                onPressed: row.item.qty < m.max ? () => cart.setQty(p.id, m.mode, row.item.qty + m.step) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
            IconButton(
              tooltip: 'Remove',
              onPressed: () => cart.remove(row.item),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
