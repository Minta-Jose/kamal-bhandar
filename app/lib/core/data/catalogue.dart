import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'firebase.dart';
import 'session.dart';

class Catalogue {
  const Catalogue({required this.categories, required this.products});

  final List<ProductCategory> categories;
  final Map<String, Product> products;

  static const empty = Catalogue(categories: [], products: {});

  List<ProductCategory> get activeCategories =>
      categories.where((c) => c.active).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<Product> inCategory(String categoryId) =>
      products.values.where((p) => p.active && p.categoryId == categoryId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Product> search(String query) =>
      products.values.where((p) => p.active && p.matches(query)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
}

/// Keeps the whole catalogue on the phone and fetches only what changed since
/// the last sync, so browsing and search are instant and cost few reads.
class CatalogueRepository {
  CatalogueRepository(this._db);

  final FirebaseFirestore _db;
  static const _cacheKey = 'catalogue.v1';

  Future<Catalogue> load({bool includeInactive = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs.getString(_cacheKey));
    final since = cached.syncedAt;

    final categories = Map<String, Map<String, dynamic>>.from(cached.categories);
    final products = Map<String, Map<String, dynamic>>.from(cached.products);
    var newest = since;

    try {
      Query<Map<String, dynamic>> catQuery = _db.collection('categories');
      Query<Map<String, dynamic>> prodQuery = _db.collection('products');
      if (since != null) {
        catQuery = catQuery.where('updatedAt', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(since));
        prodQuery = prodQuery.where('updatedAt', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(since));
      }
      final results = await Future.wait([catQuery.get(), prodQuery.get()]);
      for (final d in results[0].docs) {
        categories[d.id] = _forCache(d.data());
        newest = _max(newest, d.data()['updatedAt']);
      }
      for (final d in results[1].docs) {
        products[d.id] = _forCache(d.data());
        newest = _max(newest, d.data()['updatedAt']);
      }
      await prefs.setString(
        _cacheKey,
        jsonEncode({'syncedAt': newest, 'categories': categories, 'products': products}),
      );
    } on FirebaseException catch (e) {
      // Offline: keep showing the cached catalogue.
      debugPrint('Catalogue sync failed: ${e.code}');
      if (categories.isEmpty && products.isEmpty) rethrow;
    }

    return Catalogue(
      categories: categories.entries
          .map((e) => ProductCategory.fromMap(e.key, e.value))
          .where((c) => includeInactive || c.active)
          .toList(),
      products: {
        for (final e in products.entries)
          if (includeInactive || e.value['active'] != false) e.key: Product.fromMap(e.key, e.value),
      },
    );
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  static Map<String, dynamic> _forCache(Map<String, dynamic> m) =>
      {for (final e in m.entries) if (e.key != 'updatedAt') e.key: e.value};

  static int? _max(int? current, Object? ts) {
    if (ts is! Timestamp) return current;
    final ms = ts.millisecondsSinceEpoch;
    return current == null || ms > current ? ms : current;
  }

  static ({int? syncedAt, Map<String, Map<String, dynamic>> categories, Map<String, Map<String, dynamic>> products})
      _readCache(String? raw) {
    if (raw == null) return (syncedAt: null, categories: {}, products: {});
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      Map<String, Map<String, dynamic>> part(String k) => ((m[k] as Map?) ?? {})
          .map((key, value) => MapEntry(key as String, (value as Map).cast<String, dynamic>()));
      return (syncedAt: m['syncedAt'] as int?, categories: part('categories'), products: part('products'));
    } catch (_) {
      return (syncedAt: null, categories: {}, products: {});
    }
  }
}

final catalogueRepositoryProvider =
    Provider<CatalogueRepository>((ref) => CatalogueRepository(ref.watch(firestoreProvider)));

/// The catalogue as customers see it. Refresh with ref.invalidate(catalogueProvider).
final catalogueProvider = FutureProvider<Catalogue>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Catalogue.empty;
  return ref.watch(catalogueRepositoryProvider).load();
});

/// Everything, including hidden items, for the owner's catalogue screens.
final ownerCatalogueProvider = FutureProvider<Catalogue>((ref) async {
  return ref.watch(catalogueRepositoryProvider).load(includeInactive: true);
});
