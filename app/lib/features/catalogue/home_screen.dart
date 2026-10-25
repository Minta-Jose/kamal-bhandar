import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/catalogue.dart';
import '../../core/data/cart.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);
    final session = ref.watch(sessionProvider).value;
    final name = session is Customer ? session.profile.firstName : '';
    final settings = ref.watch(settingsProvider).value;

    // Keep the cart free of products the store has removed.
    ref.listen(catalogueProvider, (_, next) {
      final c = next.value;
      if (c != null && c.products.isNotEmpty) {
        ref.read(cartProvider.notifier).dropMissing(c.products.keys.toSet());
      }
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(catalogueProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14),
                title: Text(settings?.storeName ?? 'Kamal Bhandar'),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: InkWell(
                    onTap: () => context.push('/shop/search'),
                    borderRadius: BorderRadius.circular(12),
                    child: IgnorePointer(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: name.isEmpty ? 'Search rice, dal, atta…' : 'Hi $name, what do you need today?',
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ...catalogue.when(
              data: (c) => _categoryGrid(context, c),
              loading: () => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
              error: (e, _) => [
                SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load the shop',
                    message: 'Check your internet connection and pull down to try again.',
                    action: OutlinedButton(onPressed: () => ref.invalidate(catalogueProvider), child: const Text('Try again')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _categoryGrid(BuildContext context, Catalogue c) {
    final cats = c.activeCategories;
    if (cats.isEmpty) {
      return [
        const SliverFillRemaining(
          child: EmptyState(icon: Icons.inventory_2_outlined, title: 'The shop is being set up', message: 'Products will appear here soon.'),
        ),
      ];
    }
    return [
      const SliverToBoxAdapter(child: SectionTitle('Shop by category')),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: cats.length,
          itemBuilder: (_, i) => _CategoryCard(cats[i], count: c.inCategory(cats[i].id).length),
        ),
      ),
    ];
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(this.category, {required this.count});
  final ProductCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/shop/category/${category.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Photo(category.imageUrl, radius: 0, icon: Icons.category_outlined)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('$count ${count == 1 ? 'item' : 'items'}', style: t.bodySmall?.copyWith(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
