import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/catalogue.dart';
import '../../core/data/firebase.dart';
import '../../core/data/owner.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

/// Categories with their products; stock can be switched right from the list.
class CatalogueAdminScreen extends ConsumerStatefulWidget {
  const CatalogueAdminScreen({super.key});

  @override
  ConsumerState<CatalogueAdminScreen> createState() => _CatalogueAdminScreenState();
}

class _CatalogueAdminScreenState extends ConsumerState<CatalogueAdminScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(ownerCatalogueProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/owner/catalogue/category/new'),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Category'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/owner/catalogue/product/new'),
        icon: const Icon(Icons.add),
        label: const Text('Product'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ownerCatalogueProvider.future),
        child: AsyncView(
          value: catalogue,
          onRetry: () => ref.invalidate(ownerCatalogueProvider),
          data: (c) {
            final cats = [...c.categories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            if (cats.isEmpty) {
              return EmptyState(
                icon: Icons.category_outlined,
                title: 'Start with a category',
                message: 'For example Rice, Dal, Atta and flours, Spices, Oil.',
                action: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
                  onPressed: () => context.push('/owner/catalogue/category/new'),
                  child: const Text('Add a category'),
                ),
              );
            }
            final q = _query.toLowerCase();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Find a product', prefixIcon: Icon(Icons.search), isDense: true),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${c.products.length} products in ${cats.length} categories',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                ),
                for (final cat in cats) ..._section(context, cat, c, q),
                ..._uncategorised(context, c, cats, q),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Product> _productsOf(Catalogue c, String categoryId, String q) =>
      c.products.values.where((p) => p.categoryId == categoryId && (q.isEmpty || p.matches(q))).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Widget> _section(BuildContext context, ProductCategory cat, Catalogue c, String q) {
    final products = _productsOf(c, cat.id, q);
    if (q.isNotEmpty && products.isEmpty) return const [];
    return [
      SectionTitle(
        '${cat.name}${cat.active ? '' : ' (hidden)'}',
        trailing: IconButton(
          tooltip: 'Edit category',
          onPressed: () => context.push('/owner/catalogue/category/${cat.id}'),
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
      if (products.isEmpty)
        const Card(child: ListTile(title: Text('No products yet'))),
      for (final p in products) ...[_AdminProductTile(product: p), const SizedBox(height: 8)],
    ];
  }

  List<Widget> _uncategorised(BuildContext context, Catalogue c, List<ProductCategory> cats, String q) {
    final ids = cats.map((e) => e.id).toSet();
    final orphans = c.products.values.where((p) => !ids.contains(p.categoryId) && (q.isEmpty || p.matches(q))).toList();
    if (orphans.isEmpty) return const [];
    return [
      const SectionTitle('Without a category'),
      for (final p in orphans) ...[_AdminProductTile(product: p), const SizedBox(height: 8)],
    ];
  }
}

class _AdminProductTile extends ConsumerWidget {
  const _AdminProductTile({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final first = p.sellModes.isEmpty ? null : p.sellModes.first;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        leading: Opacity(opacity: p.active ? 1 : 0.4, child: Photo(p.thumbUrl ?? p.imageUrl, size: 48, radius: 8)),
        title: Text(p.name + (p.active ? '' : ' (hidden)')),
        subtitle: Text([
          if (first != null) '${formatRupees(first.pricePaise)} ${first.priceUnit}',
          p.sellModes.map((m) => m.mode.label.replaceFirst('By ', '')).join(', '),
        ].join(' · ')),
        onTap: () => context.push('/owner/catalogue/product/${p.id}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Switch(
              value: p.inStock,
              activeThumbColor: AppColors.green,
              onChanged: (v) async {
                try {
                  await ref.read(ownerRepositoryProvider).setInStock(p, v);
                  ref.invalidate(ownerCatalogueProvider);
                  ref.invalidate(catalogueProvider);
                } catch (e) {
                  if (context.mounted) showSnack(context, friendlyError(e));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
