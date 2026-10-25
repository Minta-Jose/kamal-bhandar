import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/catalogue.dart';
import '../../core/ui/widgets.dart';
import 'product_tile.dart';

/// Searches the catalogue on the phone, in English or Hindi names and keywords.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Search products', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
      ),
      body: AsyncView(
        value: catalogue,
        data: (c) {
          if (_query.trim().length < 2) {
            return const EmptyState(icon: Icons.search, title: 'Type at least 2 letters', message: 'Try "rice", "toor dal" or "चावल".');
          }
          final results = c.search(_query);
          if (results.isEmpty) {
            return EmptyState(icon: Icons.search_off, title: 'No products match "$_query"');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => ProductTile(results[i]),
          );
        },
      ),
    );
  }
}
