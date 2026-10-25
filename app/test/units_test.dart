import 'package:flutter_test/flutter_test.dart';
import 'package:kamal_bhandar/core/models/units.dart';

const weight = SellMode(mode: SellModeKind.weight, min: 25, step: 25, max: 50000, pricePaise: 12000);
const piece = SellMode(mode: SellModeKind.piece, min: 1, step: 1, max: 50, pricePaise: 1000);
const bag = SellMode(mode: SellModeKind.bag, min: 1, step: 1, max: 20, pricePaise: 220000, bagSizeKg: 50);

void main() {
  test('formats quantities the same way as the server', () {
    expect(formatQty(weight, 25), '25 g');
    expect(formatQty(weight, 1000), '1 kg');
    expect(formatQty(weight, 2500), '2.5 kg');
    expect(formatQty(piece, 1), '1 pc');
    expect(formatQty(piece, 6), '6 pcs');
    expect(formatQty(bag, 2), '2 bags × 50 kg');
  });

  test('checks min, max and steps', () {
    expect(weight.check(250), isNull);
    expect(weight.check(10), contains('Minimum'));
    expect(weight.check(60000), contains('Maximum'));
    expect(weight.check(30), contains('steps'));
  });

  test('clamps typed quantities onto the nearest step', () {
    expect(weight.clamp(10), 25);
    expect(weight.clamp(260), 250);
    expect(weight.clamp(270), 275);
    expect(weight.clamp(999999), 50000);
  });

  test('line totals match the server', () {
    expect(weight.lineTotalPaise(250), 3000);
    expect(piece.lineTotalPaise(6), 6000);
    expect(bag.lineTotalPaise(2), 440000);
  });

  test('formats rupees in Indian grouping', () {
    expect(formatRupees(0), '₹0');
    expect(formatRupees(4550), '₹45.50');
    expect(formatRupees(12345600), '₹1,23,456');
    expect(formatRupees(100000000), '₹10,00,000');
  });

  test('parses rupee prices typed by the owner', () {
    expect(parseRupees('45'), 4500);
    expect(parseRupees('45.5'), 4550);
    expect(parseRupees('₹1,200'), 120000);
    expect(parseRupees('abc'), isNull);
    expect(parseRupees(''), isNull);
  });

  test('sell modes survive a round trip through the database shape', () {
    final back = SellMode.fromMap(bag.toMap());
    expect(back.mode, SellModeKind.bag);
    expect(back.bagSizeKg, 50);
    expect(SellMode.fromMap(weight.toMap()).toMap().containsKey('bagSizeKg'), isFalse);
  });
}
