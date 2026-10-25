import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All Firebase services live in Mumbai (asia-south1).
const firebaseRegion = 'asia-south1';

final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final storageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
final functionsProvider =
    Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instanceFor(region: firebaseRegion));

/// Calls to the server functions. Errors arrive as [ApiError] with a message
/// the screen can show as it is.
class Api {
  Api(this._functions);
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final res = await _functions.httpsCallable(name).call<Object?>(data);
      return (res.data as Map?)?.cast<String, dynamic>() ?? {};
    } on FirebaseFunctionsException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> registerProfile(Map<String, dynamic> profile) => _call('registerProfile', profile);

  Future<({String orderId, String orderNo})> placeOrder({String note = ''}) async {
    final r = await _call('placeOrder', {'note': note});
    return (orderId: r['orderId'] as String, orderNo: r['orderNo'] as String);
  }

  Future<void> deleteAccount() => _call('deleteAccount', {});

  Future<void> setUserStatus(String uid, String status, {String reason = ''}) =>
      _call('setUserStatus', {'uid': uid, 'status': status, 'reason': reason});

  Future<void> adjustOrder(String orderId, List<Map<String, dynamic>> changes, {String note = ''}) =>
      _call('adjustOrder', {'orderId': orderId, 'changes': changes, 'note': note});

  Future<void> setOrderStatus(String orderId, String status, {String? paymentMethod, String note = ''}) =>
      _call('setOrderStatus', {
        'orderId': orderId,
        'status': status,
        'paymentMethod': ?paymentMethod,
        'note': note,
      });
}

class ApiError implements Exception {
  ApiError(this.message, {this.field, this.problems = const []});

  final String message;
  final String? field;
  final List<({String productId, String reason})> problems;

  factory ApiError.from(FirebaseFunctionsException e) {
    final details = (e.details as Map?)?.cast<String, dynamic>() ?? {};
    final problems = ((details['problems'] as List?) ?? []).map((p) {
      final m = (p as Map).cast<String, dynamic>();
      return (productId: m['productId'] as String? ?? '', reason: m['reason'] as String? ?? '');
    }).toList();
    final message = switch (e.code) {
      'unavailable' || 'deadline-exceeded' => 'No internet connection. Please try again.',
      'internal' => 'Something went wrong. Please try again.',
      _ => e.message ?? 'Something went wrong. Please try again.',
    };
    return ApiError(message, field: details['field'] as String?, problems: problems);
  }

  @override
  String toString() => message;
}

final apiProvider = Provider<Api>((ref) => Api(ref.watch(functionsProvider)));

/// Turns any error into a sentence for a snack bar.
String friendlyError(Object e) {
  if (e is ApiError) return e.message;
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return 'You do not have access to this.';
    if (e.code == 'unavailable') return 'No internet connection. Please try again.';
    return e.message ?? 'Something went wrong.';
  }
  return 'Something went wrong. Please try again.';
}
