import 'package:cloud_firestore/cloud_firestore.dart';

import 'units.dart';

export 'units.dart';

DateTime? _date(Object? v) => switch (v) {
      Timestamp t => t.toDate(),
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    };

class Address {
  const Address({
    required this.line1,
    this.line2 = '',
    this.landmark = '',
    required this.city,
    required this.state,
    required this.pincode,
  });

  final String line1, line2, landmark, city, state, pincode;

  factory Address.fromMap(Map<String, dynamic>? m) => Address(
        line1: m?['line1'] as String? ?? '',
        line2: m?['line2'] as String? ?? '',
        landmark: m?['landmark'] as String? ?? '',
        city: m?['city'] as String? ?? '',
        state: m?['state'] as String? ?? '',
        pincode: m?['pincode'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'line1': line1,
        'line2': line2,
        'landmark': landmark,
        'city': city,
        'state': state,
        'pincode': pincode,
      };

  String get oneLine => [line1, line2, landmark, city, '$state $pincode']
      .where((s) => s.trim().isNotEmpty)
      .join(', ');
}

enum UserStatus { pending, approved, rejected, blocked }

class AppUser {
  const AppUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    required this.address,
    required this.status,
    this.email,
    this.rejectReason,
    this.isOwner = false,
    this.createdAt,
  });

  final String uid, firstName, lastName, mobile;
  final String? email, rejectReason;
  final Address address;
  final UserStatus status;
  final bool isOwner;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName';

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) => AppUser.fromMap(d.id, d.data() ?? {});

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) {
    return AppUser(
      uid: uid,
      firstName: m['firstName'] as String? ?? '',
      lastName: m['lastName'] as String? ?? '',
      mobile: m['mobile'] as String? ?? '',
      email: m['email'] as String?,
      address: Address.fromMap((m['address'] as Map?)?.cast<String, dynamic>()),
      status: UserStatus.values.asNameMap()[m['status']] ?? UserStatus.pending,
      rejectReason: m['rejectReason'] as String?,
      isOwner: m['role'] == 'owner',
      createdAt: _date(m['createdAt']),
    );
  }
}

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.nameHi = '',
    this.imageUrl,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id, name, nameHi;
  final String? imageUrl;
  final int sortOrder;
  final bool active;

  factory ProductCategory.fromMap(String id, Map<String, dynamic> m) => ProductCategory(
        id: id,
        name: m['name'] as String? ?? '',
        nameHi: m['nameHi'] as String? ?? '',
        imageUrl: m['imageUrl'] as String?,
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
        active: m['active'] as bool? ?? true,
      );

  /// For the phone's catalogue cache.
  Map<String, dynamic> toCache() => {
        'name': name,
        'nameHi': nameHi,
        'imageUrl': imageUrl,
        'sortOrder': sortOrder,
        'active': active,
      };
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.sellModes,
    this.nameHi = '',
    this.imageUrl,
    this.thumbUrl,
    this.keywords = const [],
    this.inStock = true,
    this.active = true,
    this.description = '',
  });

  final String id, name, nameHi, categoryId, description;
  final String? imageUrl, thumbUrl;
  final List<String> keywords;
  final List<SellMode> sellModes;
  final bool inStock, active;

  SellMode? mode(SellModeKind kind) {
    for (final m in sellModes) {
      if (m.mode == kind) return m;
    }
    return null;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        nameHi.contains(q) ||
        keywords.any((k) => k.toLowerCase().contains(q));
  }

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
        id: id,
        name: m['name'] as String? ?? '',
        nameHi: m['nameHi'] as String? ?? '',
        description: m['description'] as String? ?? '',
        categoryId: m['categoryId'] as String? ?? '',
        imageUrl: m['imageUrl'] as String?,
        thumbUrl: m['thumbUrl'] as String?,
        keywords: ((m['keywords'] as List?) ?? []).cast<String>(),
        sellModes: ((m['sellModes'] as List?) ?? [])
            .map((e) => SellMode.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
        inStock: m['inStock'] as bool? ?? true,
        active: m['active'] as bool? ?? true,
      );

  Map<String, dynamic> toCache() => {
        'name': name,
        'nameHi': nameHi,
        'description': description,
        'categoryId': categoryId,
        'imageUrl': imageUrl,
        'thumbUrl': thumbUrl,
        'keywords': keywords,
        'sellModes': sellModes.map((m) => m.toMap()).toList(),
        'inStock': inStock,
        'active': active,
      };
}

class CartItem {
  const CartItem({required this.productId, required this.mode, required this.qty});

  final String productId;
  final SellModeKind mode;
  final int qty;

  String get key => '$productId:${mode.name}';

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
        productId: m['productId'] as String? ?? '',
        mode: SellModeKind.parse(m['mode'] as String? ?? 'piece'),
        qty: (m['qty'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {'productId': productId, 'mode': mode.name, 'qty': qty};

  CartItem withQty(int q) => CartItem(productId: productId, mode: mode, qty: q);
}

enum OrderStatus {
  placed('Placed'),
  adjusted('Changed by store'),
  ready('Ready for pickup'),
  pickedUp('Picked up'),
  cancelled('Cancelled');

  const OrderStatus(this.label);
  final String label;

  String get wire => this == pickedUp ? 'picked_up' : name;

  static OrderStatus parse(String? v) =>
      OrderStatus.values.firstWhere((s) => s.wire == v, orElse: () => OrderStatus.placed);

  bool get isOpen => this == placed || this == adjusted || this == ready;
}

enum PaymentMethod {
  cash('Cash'),
  upi('UPI'),
  card('Card');

  const PaymentMethod(this.label);
  final String label;
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.mode,
    required this.qty,
    required this.unitLabel,
    required this.pricePaise,
    required this.lineTotalPaise,
    this.bagSizeKg,
    this.adjusted = false,
  });

  final String productId, name, unitLabel;
  final SellModeKind mode;
  final int qty, pricePaise, lineTotalPaise;
  final double? bagSizeKg;
  final bool adjusted;

  SellMode get sellMode =>
      SellMode(mode: mode, min: 1, step: 1, max: 1 << 30, pricePaise: pricePaise, bagSizeKg: bagSizeKg);

  factory OrderLine.fromMap(Map<String, dynamic> m) => OrderLine(
        productId: m['productId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        mode: SellModeKind.parse(m['mode'] as String? ?? 'piece'),
        qty: (m['qty'] as num?)?.toInt() ?? 0,
        unitLabel: m['unitLabel'] as String? ?? '',
        pricePaise: (m['pricePaise'] as num?)?.toInt() ?? 0,
        lineTotalPaise: (m['lineTotalPaise'] as num?)?.toInt() ?? 0,
        bagSizeKg: (m['bagSizeKg'] as num?)?.toDouble(),
        adjusted: m['adjusted'] as bool? ?? false,
      );
}

class StatusChange {
  const StatusChange({required this.status, required this.at, this.note = ''});
  final OrderStatus status;
  final DateTime? at;
  final String note;
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.orderNo,
    required this.uid,
    required this.customerName,
    required this.customerMobile,
    required this.customerAddress,
    required this.items,
    required this.totalPaise,
    required this.status,
    required this.history,
    this.note = '',
    this.paymentMethod,
    this.placedAt,
  });

  final String id, orderNo, customerName, note;
  final String? uid, customerMobile;
  final Address? customerAddress;
  final List<OrderLine> items;
  final int totalPaise;
  final OrderStatus status;
  final List<StatusChange> history;
  final PaymentMethod? paymentMethod;
  final DateTime? placedAt;

  factory CustomerOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      CustomerOrder.fromMap(d.id, d.data() ?? {});

  factory CustomerOrder.fromMap(String id, Map<String, dynamic> m) {
    final c = (m['customer'] as Map?)?.cast<String, dynamic>() ?? {};
    return CustomerOrder(
      id: id,
      orderNo: m['orderNo'] as String? ?? '',
      uid: m['uid'] as String?,
      customerName: c['name'] as String? ?? '',
      customerMobile: c['mobile'] as String?,
      customerAddress: c['address'] == null
          ? null
          : Address.fromMap((c['address'] as Map).cast<String, dynamic>()),
      items: ((m['items'] as List?) ?? [])
          .map((e) => OrderLine.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      totalPaise: (m['totalPaise'] as num?)?.toInt() ?? 0,
      status: OrderStatus.parse(m['status'] as String?),
      history: ((m['statusHistory'] as List?) ?? []).map((e) {
        final h = (e as Map).cast<String, dynamic>();
        return StatusChange(
          status: OrderStatus.parse(h['status'] as String?),
          at: _date(h['at']),
          note: h['note'] as String? ?? '',
        );
      }).toList(),
      note: m['note'] as String? ?? '',
      paymentMethod: PaymentMethod.values.asNameMap()[m['paymentMethod']],
      placedAt: _date(m['placedAt']),
    );
  }

  int get itemCount => items.length;
}

class StoreSettings {
  const StoreSettings({
    this.storeName = 'Kamal Bhandar',
    this.showPrices = false,
    this.pickupHours = '',
    this.storeAddress = '',
    this.storePhone = '',
    this.grievanceContact = '',
    this.minAppVersion = 0,
  });

  final String storeName, pickupHours, storeAddress, storePhone, grievanceContact;
  final bool showPrices;
  final int minAppVersion;

  factory StoreSettings.fromMap(Map<String, dynamic>? m) => StoreSettings(
        storeName: m?['storeName'] as String? ?? 'Kamal Bhandar',
        showPrices: m?['showPrices'] as bool? ?? false,
        pickupHours: m?['pickupHours'] as String? ?? '',
        storeAddress: m?['storeAddress'] as String? ?? '',
        storePhone: m?['storePhone'] as String? ?? '',
        grievanceContact: m?['grievanceContact'] as String? ?? '',
        minAppVersion: (m?['minAppVersion'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'storeName': storeName,
        'showPrices': showPrices,
        'pickupHours': pickupHours,
        'storeAddress': storeAddress,
        'storePhone': storePhone,
        'grievanceContact': grievanceContact,
        'minAppVersion': minAppVersion,
      };
}
