import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'firebase.dart';
import 'session.dart';

/// The customer's own orders, newest first.
final myOrdersProvider = StreamProvider<List<CustomerOrder>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('orders')
      .where('uid', isEqualTo: uid)
      .orderBy('placedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(CustomerOrder.fromDoc).toList());
});

final orderProvider = StreamProvider.family<CustomerOrder?, String>((ref, id) {
  return ref
      .watch(firestoreProvider)
      .doc('orders/$id')
      .snapshots()
      .map((s) => s.exists ? CustomerOrder.fromDoc(s) : null);
});

/// Owner view: orders in the given statuses, newest first.
final ownerOrdersProvider = StreamProvider.family<List<CustomerOrder>, OrderFilter>((ref, filter) {
  Query<Map<String, dynamic>> q = ref.watch(firestoreProvider).collection('orders');
  q = q.where('status', whereIn: filter.statuses.map((s) => s.wire).toList());
  return q
      .orderBy('placedAt', descending: true)
      .limit(filter.isOpen ? 200 : 50)
      .snapshots()
      .map((s) => s.docs.map(CustomerOrder.fromDoc).toList());
});

enum OrderFilter {
  open([OrderStatus.placed, OrderStatus.adjusted, OrderStatus.ready]),
  done([OrderStatus.pickedUp]),
  cancelled([OrderStatus.cancelled]);

  const OrderFilter(this.statuses);
  final List<OrderStatus> statuses;

  bool get isOpen => this == OrderFilter.open;

  String get label => switch (this) {
        OrderFilter.open => 'Open',
        OrderFilter.done => 'Picked up',
        OrderFilter.cancelled => 'Cancelled',
      };
}

final pendingCustomersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());
});

final customersProvider = StreamProvider.family<List<AppUser>, UserStatus>((ref, status) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .where('status', isEqualTo: status.name)
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).where((u) => !u.isOwner).toList());
});
