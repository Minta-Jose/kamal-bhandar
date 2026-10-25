import 'package:flutter_test/flutter_test.dart';
import 'package:kamal_bhandar/core/models/models.dart';

void main() {
  test('reads an order written by placeOrder and adjustOrder', () {
    final o = CustomerOrder.fromMap('o1', {
      'orderNo': 'KB-2026-000001',
      'uid': 'u1',
      'customer': {
        'name': 'Ravi Kumar',
        'mobile': '+919876543210',
        'address': {'line1': '12 MG Road', 'city': 'Kolkata', 'state': 'West Bengal', 'pincode': '700091'},
      },
      'items': [
        {'productId': 'rice', 'name': 'Rice', 'mode': 'weight', 'qty': 900, 'unitLabel': '900 g', 'pricePaise': 6000, 'lineTotalPaise': 5400, 'adjusted': true},
        {'productId': 'atta', 'name': 'Atta', 'mode': 'bag', 'qty': 1, 'unitLabel': '1 bag × 10 kg', 'bagSizeKg': 10, 'pricePaise': 45000, 'lineTotalPaise': 45000, 'adjusted': false},
      ],
      'totalPaise': 50400,
      'status': 'picked_up',
      'statusHistory': [
        {'status': 'placed', 'by': 'u1', 'note': ''},
        {'status': 'adjusted', 'by': 'owner', 'note': 'Only 900 g left'},
        {'status': 'picked_up', 'by': 'owner', 'note': ''},
      ],
      'paymentMethod': 'upi',
    });
    expect(o.status, OrderStatus.pickedUp);
    expect(o.status.isOpen, isFalse);
    expect(o.paymentMethod, PaymentMethod.upi);
    expect(o.items.first.adjusted, isTrue);
    expect(o.items.last.sellMode.bagSizeKg, 10);
    expect(o.history.map((h) => h.status), [OrderStatus.placed, OrderStatus.adjusted, OrderStatus.pickedUp]);
    expect(o.customerAddress!.oneLine, '12 MG Road, Kolkata, West Bengal 700091');
  });

  test('reads an anonymised order after the customer deleted their account', () {
    final o = CustomerOrder.fromMap('o2', {
      'orderNo': 'KB-2026-000002',
      'uid': null,
      'customer': {'name': 'Deleted customer', 'mobile': null, 'address': null},
      'items': [],
      'status': 'placed',
    });
    expect(o.uid, isNull);
    expect(o.customerAddress, isNull);
    expect(o.customerName, 'Deleted customer');
  });

  test('products match English, Hindi and keyword searches', () {
    final p = Product.fromMap('dal', {
      'name': 'Toor dal',
      'nameHi': 'अरहर दाल',
      'keywords': ['arhar', 'tuvar'],
      'sellModes': [
        {'mode': 'weight', 'min': 250, 'step': 250, 'max': 10000, 'pricePaise': 14000},
      ],
    });
    expect(p.matches('toor'), isTrue);
    expect(p.matches('अरहर'), isTrue);
    expect(p.matches('TUVAR'), isTrue);
    expect(p.matches('rice'), isFalse);
    expect(p.mode(SellModeKind.weight)?.min, 250);
    expect(p.mode(SellModeKind.bag), isNull);
    expect(Product.fromMap('dal', p.toCache()).keywords, ['arhar', 'tuvar']);
  });

  test('profile status and owner role come from the user document', () {
    expect(AppUser.fromMap('a', {'firstName': 'A', 'lastName': 'B', 'status': 'blocked'}).status, UserStatus.blocked);
    expect(AppUser.fromMap('o', {'firstName': 'O', 'status': 'approved', 'role': 'owner'}).isOwner, isTrue);
    expect(AppUser.fromMap('n', {}).status, UserStatus.pending);
  });
}
