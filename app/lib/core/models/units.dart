// Quantities are whole numbers in a base unit: grams for weight, a count for
// pieces and bags. Money is whole paise. Mirrors functions/src/lib/quantity.ts.

enum SellModeKind {
  weight,
  piece,
  bag;

  static SellModeKind parse(String v) =>
      SellModeKind.values.firstWhere((m) => m.name == v, orElse: () => SellModeKind.piece);

  String get label => switch (this) {
        SellModeKind.weight => 'By weight',
        SellModeKind.piece => 'By piece',
        SellModeKind.bag => 'By bag',
      };
}

class SellMode {
  const SellMode({
    required this.mode,
    required this.min,
    required this.step,
    required this.max,
    required this.pricePaise,
    this.bagSizeKg,
  });

  final SellModeKind mode;
  final int min;
  final int step;
  final int max;
  final int pricePaise;
  final double? bagSizeKg;

  factory SellMode.fromMap(Map<String, dynamic> m) => SellMode(
        mode: SellModeKind.parse(m['mode'] as String? ?? 'piece'),
        min: (m['min'] as num?)?.toInt() ?? 1,
        step: (m['step'] as num?)?.toInt() ?? 1,
        max: (m['max'] as num?)?.toInt() ?? 1,
        pricePaise: (m['pricePaise'] as num?)?.toInt() ?? 0,
        bagSizeKg: (m['bagSizeKg'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'min': min,
        'step': step,
        'max': max,
        'pricePaise': pricePaise,
        if (mode == SellModeKind.bag) 'bagSizeKg': bagSizeKg,
      };

  /// The quantities a customer can pick, from min to max in steps.
  int clamp(int qty) {
    if (qty <= min) return min;
    if (qty >= max) return max;
    final steps = ((qty - min) / step).round();
    return (min + steps * step).clamp(min, max);
  }

  String? check(int qty) {
    if (qty <= 0) return 'Choose a quantity';
    if (qty < min) return 'Minimum is ${formatQty(this, min)}';
    if (qty > max) return 'Maximum is ${formatQty(this, max)}';
    if (step > 0 && (qty - min) % step != 0) return 'Must be in steps of ${formatQty(this, step)}';
    return null;
  }

  int lineTotalPaise(int qty) =>
      mode == SellModeKind.weight ? (pricePaise * qty / 1000).round() : pricePaise * qty;

  String get priceUnit => switch (mode) {
        SellModeKind.weight => 'per kg',
        SellModeKind.piece => 'per piece',
        SellModeKind.bag => 'per bag',
      };
}

String _trim(num n) {
  if (n == n.roundToDouble()) return n.toInt().toString();
  return (((n * 1000).round()) / 1000).toString();
}

/// "250 g", "2.5 kg", "6 pcs", "2 bags × 50 kg".
String formatQty(SellMode mode, int qty) {
  switch (mode.mode) {
    case SellModeKind.weight:
      return qty < 1000 ? '$qty g' : '${_trim(qty / 1000)} kg';
    case SellModeKind.piece:
      return qty == 1 ? '1 pc' : '$qty pcs';
    case SellModeKind.bag:
      return '$qty ${qty == 1 ? 'bag' : 'bags'} × ${_trim(mode.bagSizeKg ?? 0)} kg';
  }
}

/// ₹1,234.50 in Indian digit grouping.
String formatRupees(int paise) {
  final negative = paise < 0;
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final rest = abs % 100;
  final digits = rupees.toString();
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var head = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) parts.insert(0, head);
    grouped = '${parts.join(',')},$last3';
  }
  final p = rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₹$grouped$p';
}

/// Parses what the owner types as a rupee price ("45", "45.5") into paise.
int? parseRupees(String text) {
  final t = text.trim().replaceAll(',', '').replaceAll('₹', '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v < 0) return null;
  return (v * 100).round();
}
