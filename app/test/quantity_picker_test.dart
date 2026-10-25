import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamal_bhandar/core/data/session.dart';
import 'package:kamal_bhandar/core/models/models.dart';
import 'package:kamal_bhandar/features/catalogue/quantity_picker.dart';

const rice = Product(
  id: 'rice',
  name: 'Basmati rice',
  categoryId: 'grains',
  sellModes: [
    SellMode(mode: SellModeKind.weight, min: 250, step: 250, max: 5000, pricePaise: 12000),
    SellMode(mode: SellModeKind.bag, min: 1, step: 1, max: 10, pricePaise: 550000, bagSizeKg: 50),
  ],
);

Future<List<(SellModeKind, int)>> pump(WidgetTester tester, {bool showPrices = false}) async {
  final changes = <(SellModeKind, int)>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [showPricesProvider.overrideWithValue(showPrices)],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuantityPicker(
            product: rice,
            initialMode: SellModeKind.weight,
            initialQty: 250,
            onChanged: (m, q) => changes.add((m, q)),
          ),
        ),
      ),
    ),
  ));
  return changes;
}

void main() {
  testWidgets('steps the weight up and down within limits', (tester) async {
    final changes = await pump(tester);
    expect(find.text('250 g'), findsWidgets);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(changes.last, (SellModeKind.weight, 500));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(changes.last, (SellModeKind.weight, 250));
  });

  testWidgets('offers quick picks and switches to bags', (tester) async {
    final changes = await pump(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '2 kg'));
    await tester.pump();
    expect(changes.last, (SellModeKind.weight, 2000));
    await tester.tap(find.text('Bag of 50 kg'));
    await tester.pump();
    expect(changes.last, (SellModeKind.bag, 1));
    expect(find.text('1 bag × 50 kg'), findsOneWidget);
  });

  testWidgets('hides prices unless the store shows them', (tester) async {
    await pump(tester);
    expect(find.textContaining('per kg'), findsNothing);
    await pump(tester, showPrices: true);
    expect(find.textContaining('₹120 per kg'), findsOneWidget);
  });
}
