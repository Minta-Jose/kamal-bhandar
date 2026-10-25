import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'firebase.dart';

/// Catalogue and settings changes made by the owner. These are direct writes;
/// the security rules allow them for the owner role only.
class OwnerRepository {
  OwnerRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  String newProductId() => _db.collection('products').doc().id;
  String newCategoryId() => _db.collection('categories').doc().id;

  Future<void> saveProduct(String id, Map<String, dynamic> fields) =>
      _db.doc('products/$id').set({...fields, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<void> setInStock(Product p, bool inStock) => _db
      .doc('products/${p.id}')
      .update({'inStock': inStock, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> saveCategory(String id, Map<String, dynamic> fields) =>
      _db.doc('categories/$id').set({...fields, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<void> saveSettings(StoreSettings s) =>
      _db.doc('settings/store').set(s.toMap(), SetOptions(merge: true));

  /// Shrinks a photo on the phone to an 800 px WebP and a 200 px thumbnail,
  /// uploads both and returns their download links.
  Future<({String imageUrl, String thumbUrl})> uploadProductPhoto(String productId, Uint8List original) async {
    final main = await _compress(original, 800, 80);
    final thumb = await _compress(original, 200, 70);
    final base = 'products/$productId';
    final imageUrl = await _upload('$base/main.webp', main);
    final thumbUrl = await _upload('$base/thumb.webp', thumb);
    return (imageUrl: imageUrl, thumbUrl: thumbUrl);
  }

  Future<String> uploadCategoryPhoto(String categoryId, Uint8List original) async {
    final bytes = await _compress(original, 400, 80);
    return _upload('categories/$categoryId.webp', bytes);
  }

  Future<Uint8List> _compress(Uint8List bytes, int size, int quality) => FlutterImageCompress.compressWithList(
        bytes,
        minWidth: size,
        minHeight: size,
        quality: quality,
        format: CompressFormat.webp,
      );

  Future<String> _upload(String path, Uint8List bytes) async {
    final ref = _storage.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/webp', cacheControl: 'public, max-age=604800'),
    );
    final url = await ref.getDownloadURL();
    // A new version number makes phones fetch the new photo instead of a cached one.
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }
}

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) => OwnerRepository(ref.watch(firestoreProvider), ref.watch(storageProvider)),
);
