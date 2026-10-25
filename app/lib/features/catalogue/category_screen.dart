import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/catalogue.dart';
import '../../core/ui/widgets.dart';
import 'product_tile.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);
    final category = catalogue.value?.categories.where((c) => c.id == categoryId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(category?.name ?? '')),
      body: AsyncView(
        value: catalogue,
        onRetry: () => ref.invalidate(catalogueProvider),
        data: (c) {
          final products = c.inCategory(categoryId)..sort((a, b) => (a.inStock ? 0 : 1).compareTo(b.inStock ? 0 : 1));
          if (products.isEmpty) {
            return const EmptyState(icon: Icons.inventory_2_outlined, title: 'Nothing here yet');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => ProductTile(products[i]),
          );
        },
      ),
    );
  }
}
