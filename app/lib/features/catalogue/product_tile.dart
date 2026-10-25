import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/cart.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

class ProductTile extends ConsumerWidget {
  const ProductTile(this.product, {super.key});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final inCart = cart.where((i) => i.productId == product.id).toList();
    final showPrices = ref.watch(showPricesProvider);
    final t = Theme.of(context).textTheme;
    final first = product.sellModes.isEmpty ? null : product.sellModes.first;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/shop/product/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Opacity(opacity: product.inStock ? 1 : 0.4, child: Photo(product.thumbUrl ?? product.imageUrl, size: 72)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (product.nameHi.isNotEmpty)
                      Text(product.nameHi, style: t.bodySmall?.copyWith(color: Colors.black54)),
                    const SizedBox(height: 4),
                    if (!product.inStock)
                      Text('Out of stock', style: t.bodySmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600))
                    else if (inCart.isNotEmpty)
                      Text(
                        'In cart: ${inCart.map((i) => formatQty(product.mode(i.mode) ?? first!, i.qty)).join(' + ')}',
                        style: t.bodySmall?.copyWith(color: AppColors.green, fontWeight: FontWeight.w600),
                      )
                    else if (showPrices && first != null)
                      Text('${formatRupees(first.pricePaise)} ${first.priceUnit}', style: t.bodySmall)
                    else
                      Text(product.sellModes.map((m) => m.mode.label).join(' · '),
                          style: t.bodySmall?.copyWith(color: Colors.black54)),
                  ],
                ),
              ),
              if (product.inStock)
                Icon(inCart.isEmpty ? Icons.add_circle : Icons.edit, color: AppColors.green, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
