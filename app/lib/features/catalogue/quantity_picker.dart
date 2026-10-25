import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';

/// Quick picks offered for weight, in grams; only those inside min..max on the step show.
const _weightPresets = [100, 250, 500, 1000, 2000, 5000, 10000, 25000];

/// Lets the customer choose how much: a sell mode (weight, pieces, bags), then
/// a quantity with − / + buttons, quick picks, or typed in.
class QuantityPicker extends ConsumerStatefulWidget {
  const QuantityPicker({
    super.key,
    required this.product,
    required this.initialMode,
    required this.initialQty,
    required this.onChanged,
  });

  final Product product;
  final SellModeKind initialMode;
  final int initialQty;
  final void Function(SellModeKind mode, int qty) onChanged;

  @override
  ConsumerState<QuantityPicker> createState() => _QuantityPickerState();
}

class _QuantityPickerState extends ConsumerState<QuantityPicker> {
  late SellModeKind _kind = widget.initialMode;
  late int _qty = widget.initialQty;

  SellMode get _mode => widget.product.mode(_kind) ?? widget.product.sellModes.first;

  void _set(int qty) {
    final q = _mode.clamp(qty);
    setState(() => _qty = q);
    widget.onChanged(_kind, q);
  }

  void _switchMode(SellModeKind k) {
    setState(() {
      _kind = k;
      _qty = _mode.min;
    });
    widget.onChanged(_kind, _qty);
  }

  Future<void> _typeIn() async {
    final isWeight = _mode.mode == SellModeKind.weight;
    final controller = TextEditingController(
      text: isWeight ? (_qty >= 1000 ? '${_qty / 1000}' : '$_qty') : '$_qty',
    );
    var inKg = isWeight && _qty >= 1000;
    final result = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Enter quantity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(
                  suffixText: switch (_mode.mode) {
                    SellModeKind.weight => inKg ? 'kg' : 'g',
                    SellModeKind.piece => 'pcs',
                    SellModeKind.bag => 'bags',
                  },
                ),
              ),
              if (isWeight) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [ButtonSegment(value: false, label: Text('grams')), ButtonSegment(value: true, label: Text('kg'))],
                  selected: {inKg},
                  onSelectionChanged: (s) => setLocal(() => inKg = s.first),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () {
                final v = double.tryParse(controller.text);
                if (v == null) return Navigator.pop(c);
                Navigator.pop(c, isWeight && inKg ? (v * 1000).round() : v.round());
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (result != null) _set(result);
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    final showPrices = ref.watch(showPricesProvider);
    final t = Theme.of(context).textTheme;
    final presets = mode.mode == SellModeKind.weight
        ? _weightPresets.where((g) => g >= mode.min && g <= mode.max && mode.check(g) == null).toList()
        : const <int>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.product.sellModes.length > 1) ...[
          SegmentedButton<SellModeKind>(
            segments: [
              for (final m in widget.product.sellModes)
                ButtonSegment(
                  value: m.mode,
                  label: Text(m.mode == SellModeKind.bag ? 'Bag of ${formatQty(m, 1).split('× ').last}' : m.mode.label),
                ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => _switchMode(s.first),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            _RoundButton(icon: Icons.remove, onTap: _qty > mode.min ? () => _set(_qty - mode.step) : null),
            Expanded(
              child: InkWell(
                onTap: _typeIn,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(formatQty(mode, _qty), style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Tap to type', style: t.bodySmall?.copyWith(color: Colors.black45)),
                    ],
                  ),
                ),
              ),
            ),
            _RoundButton(icon: Icons.add, onTap: _qty < mode.max ? () => _set(_qty + mode.step) : null),
          ],
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final g in presets)
                ChoiceChip(label: Text(formatQty(mode, g)), selected: _qty == g, onSelected: (_) => _set(g)),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Min ${formatQty(mode, mode.min)} · steps of ${formatQty(mode, mode.step)} · max ${formatQty(mode, mode.max)}',
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: Colors.black45),
        ),
        if (showPrices) ...[
          const SizedBox(height: 8),
          Text(
            '${formatRupees(mode.pricePaise)} ${mode.priceUnit} · ${formatRupees(mode.lineTotalPaise(_qty))} for this',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: AppColors.green, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 28,
      style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
    );
  }
}
