import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/cart.dart';
import '../../core/data/catalogue.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'quantity_picker.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  SellModeKind? _mode;
  int? _qty;

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(catalogueProvider).value?.products[widget.productId];
    if (product == null || product.sellModes.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.inventory_2_outlined, title: 'This product is not available'),
      );
    }

    final cart = ref.read(cartProvider.notifier);
    final existing = ref.watch(cartProvider).where((i) => i.productId == product.id).firstOrNull;
    final mode = _mode ?? existing?.mode ?? product.sellModes.first.mode;
    final sellMode = product.mode(mode) ?? product.sellModes.first;
    final inCartForMode = cart.find(product.id, mode);
    final qty = _qty ?? inCartForMode?.qty ?? sellMode.min;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          AspectRatio(aspectRatio: 1.4, child: Photo(product.imageUrl, radius: 16)),
          const SizedBox(height: 16),
          Text(product.name, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (product.nameHi.isNotEmpty) Text(product.nameHi, style: t.titleMedium?.copyWith(color: Colors.black54)),
          if (product.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(product.description, style: t.bodyMedium),
          ],
          const SizedBox(height: 24),
          if (!product.inStock)
            const Card(
              child: ListTile(
                leading: Icon(Icons.remove_shopping_cart_outlined, color: AppColors.danger),
                title: Text('Out of stock'),
                subtitle: Text('Check again later.'),
              ),
            )
          else
            QuantityPicker(
              key: ValueKey('${product.id}:${existing?.key}'),
              product: product,
              initialMode: mode,
              initialQty: qty,
              onChanged: (m, q) => setState(() {
                _mode = m;
                _qty = q;
              }),
            ),
        ],
      ),
      bottomNavigationBar: !product.inStock
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (inCartForMode != null) ...[
                      IconButton.outlined(
                        tooltip: 'Remove from cart',
                        onPressed: () {
                          cart.setQty(product.id, mode, 0);
                          showSnack(context, '${product.name} removed from cart');
                        },
                        icon: const Icon(Icons.delete_outline),
                        style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          cart.setQty(product.id, mode, qty);
                          showSnack(context, '${formatQty(sellMode, qty)} ${product.name} in your cart');
                          context.pop();
                        },
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: Text(inCartForMode == null ? 'Add ${formatQty(sellMode, qty)}' : 'Update to ${formatQty(sellMode, qty)}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
