import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'firebase.dart';
import 'session.dart';

/// The customer's cart, kept in carts/{uid} so it survives reinstalling and is
/// what placeOrder reads on the server.
class CartController extends Notifier<List<CartItem>> {
  Timer? _saveTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _dirty = false;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = ref.read(currentUidProvider);
    return uid == null ? null : ref.read(firestoreProvider).doc('carts/$uid');
  }

  @override
  List<CartItem> build() {
    final uid = ref.watch(currentUidProvider);
    final session = ref.watch(sessionProvider).value;
    ref.onDispose(() {
      _saveTimer?.cancel();
      _sub?.cancel();
    });
    if (uid == null || session is! Customer || session.profile.status != UserStatus.approved) {
      return const [];
    }
    _sub = ref.read(firestoreProvider).doc('carts/$uid').snapshots().listen((snap) {
      if (_dirty) return; // Local edits win until they are saved.
      final items = ((snap.data()?['items'] as List?) ?? [])
          .map((e) => CartItem.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
      state = items;
    }, onError: (_) {});
    return const [];
  }

  CartItem? find(String productId, SellModeKind mode) {
    for (final i in state) {
      if (i.productId == productId && i.mode == mode) return i;
    }
    return null;
  }

  /// Adds or replaces the line for this product and mode; qty 0 removes it.
  void setQty(String productId, SellModeKind mode, int qty) {
    final key = '$productId:${mode.name}';
    final next = [...state];
    final i = next.indexWhere((e) => e.key == key);
    if (qty <= 0) {
      if (i >= 0) next.removeAt(i);
    } else if (i >= 0) {
      next[i] = next[i].withQty(qty);
    } else {
      next.add(CartItem(productId: productId, mode: mode, qty: qty));
    }
    state = next;
    _scheduleSave();
  }

  void remove(CartItem item) => setQty(item.productId, item.mode, 0);

  /// Removes lines whose product is gone, so the cart never shows ghosts.
  void dropMissing(Set<String> productIds) {
    final next = state.where((i) => productIds.contains(i.productId)).toList();
    if (next.length != state.length) {
      state = next;
      _scheduleSave();
    }
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), save);
  }

  /// Writes the cart now; called before placing an order.
  Future<void> save() async {
    _saveTimer?.cancel();
    final doc = _doc;
    if (doc == null || !_dirty) return;
    await doc.set({
      'items': state.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _dirty = false;
  }

  /// After an order the server has already emptied the saved cart.
  void clearLocal() {
    _saveTimer?.cancel();
    _dirty = false;
    state = const [];
  }
}

final cartProvider = NotifierProvider<CartController, List<CartItem>>(CartController.new);

final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).length);
