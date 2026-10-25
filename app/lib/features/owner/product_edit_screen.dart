import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/catalogue.dart';
import '../../core/data/firebase.dart';
import '../../core/data/owner.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

/// Form fields for one way of selling a product.
class _ModeFields {
  _ModeFields(this.kind, SellMode? m)
      : enabled = m != null,
        price = TextEditingController(text: m == null ? '' : _rupees(m.pricePaise)),
        min = TextEditingController(text: '${m?.min ?? _defaults[kind]!.min}'),
        step = TextEditingController(text: '${m?.step ?? _defaults[kind]!.step}'),
        max = TextEditingController(text: '${m?.max ?? _defaults[kind]!.max}'),
        bagKg = TextEditingController(text: _trim(m?.bagSizeKg ?? 25));

  final SellModeKind kind;
  bool enabled;
  final TextEditingController price, min, step, max, bagKg;

  static const _defaults = {
    SellModeKind.weight: (min: 250, step: 250, max: 25000),
    SellModeKind.piece: (min: 1, step: 1, max: 50),
    SellModeKind.bag: (min: 1, step: 1, max: 20),
  };

  static String _rupees(int paise) => paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);
  static String _trim(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  String get unit => switch (kind) {
        SellModeKind.weight => 'g',
        SellModeKind.piece => 'pcs',
        SellModeKind.bag => 'bags',
      };

  /// Returns the mode, or a problem to show.
  (SellMode?, String?) build() {
    final p = parseRupees(price.text);
    final mn = int.tryParse(min.text);
    final st = int.tryParse(step.text);
    final mx = int.tryParse(max.text);
    final bag = double.tryParse(bagKg.text);
    final name = kind.label.toLowerCase();
    if (p == null) return (null, 'Enter a price for selling $name');
    if (mn == null || mn <= 0) return (null, 'Minimum for selling $name must be more than 0');
    if (st == null || st <= 0) return (null, 'Step for selling $name must be more than 0');
    if (mx == null || mx < mn) return (null, 'Maximum for selling $name must be at least the minimum');
    if (kind == SellModeKind.bag && (bag == null || bag <= 0)) return (null, 'Enter the bag size in kg');
    return (
      SellMode(mode: kind, min: mn, step: st, max: mx, pricePaise: p, bagSizeKg: kind == SellModeKind.bag ? bag : null),
      null
    );
  }

  void dispose() {
    for (final c in [price, min, step, max, bagKg]) {
      c.dispose();
    }
  }
}

class ProductEditScreen extends ConsumerStatefulWidget {
  const ProductEditScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameHi = TextEditingController();
  final _description = TextEditingController();
  final _keywords = TextEditingController();
  String? _categoryId;
  bool _inStock = true;
  bool _active = true;
  String? _imageUrl;
  String? _thumbUrl;
  Uint8List? _newPhoto;
  late Map<SellModeKind, _ModeFields> _modes;
  bool _loaded = false;
  bool _busy = false;

  bool get _isNew => widget.productId == 'new';

  void _load(Catalogue? c) {
    if (_loaded || c == null) return;
    final p = c.products[widget.productId];
    _modes = {for (final k in SellModeKind.values) k: _ModeFields(k, p?.mode(k))};
    if (p != null) {
      _name.text = p.name;
      _nameHi.text = p.nameHi;
      _description.text = p.description;
      _keywords.text = p.keywords.join(', ');
      _categoryId = p.categoryId;
      _inStock = p.inStock;
      _active = p.active;
      _imageUrl = p.imageUrl;
      _thumbUrl = p.thumbUrl;
    } else {
      _modes[SellModeKind.weight]!.enabled = true;
      final cats = [...c.categories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (cats.isNotEmpty) _categoryId = cats.first.id;
    }
    _loaded = true;
  }

  @override
  void dispose() {
    for (final c in [_name, _nameHi, _description, _keywords]) {
      c.dispose();
    }
    if (_loaded) {
      for (final m in _modes.values) {
        m.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source, maxWidth: 2000);
    if (f != null) {
      final bytes = await f.readAsBytes();
      setState(() => _newPhoto = bytes);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final modes = <SellMode>[];
    for (final m in _modes.values.where((m) => m.enabled)) {
      final (mode, problem) = m.build();
      if (problem != null) return showSnack(context, problem);
      modes.add(mode!);
    }
    if (modes.isEmpty) return showSnack(context, 'Choose at least one way to sell this product');

    setState(() => _busy = true);
    final repo = ref.read(ownerRepositoryProvider);
    try {
      final id = _isNew ? repo.newProductId() : widget.productId;
      var imageUrl = _imageUrl;
      var thumbUrl = _thumbUrl;
      if (_newPhoto != null) {
        final up = await repo.uploadProductPhoto(id, _newPhoto!);
        imageUrl = up.imageUrl;
        thumbUrl = up.thumbUrl;
      }
      final keywords = _keywords.text
          .split(',')
          .map((k) => k.trim().toLowerCase())
          .where((k) => k.isNotEmpty)
          .toSet()
          .toList();
      await repo.saveProduct(id, {
        'name': _name.text.trim(),
        'nameHi': _nameHi.text.trim(),
        'description': _description.text.trim(),
        'categoryId': _categoryId,
        'keywords': keywords,
        'sellModes': modes.map((m) => m.toMap()).toList(),
        'inStock': _inStock,
        'active': _active,
        'imageUrl': imageUrl,
        'thumbUrl': thumbUrl,
        'imagePath': 'products/$id/main.webp',
        'thumbPath': 'products/$id/thumb.webp',
      });
      ref.invalidate(ownerCatalogueProvider);
      ref.invalidate(catalogueProvider);
      if (mounted) {
        showSnack(context, '${_name.text.trim()} saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(ownerCatalogueProvider).value;
    _load(catalogue);
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cats = [...catalogue!.categories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New product' : 'Edit product')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: _newPhoto != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_newPhoto!, fit: BoxFit.cover))
                    : Photo(_imageUrl, size: 180, radius: 16, icon: Icons.add_a_photo_outlined),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Take photo')),
                TextButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
              ],
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Toor dal'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _nameHi, decoration: const InputDecoration(labelText: 'Hindi name (optional)', hintText: 'e.g. अरहर दाल')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: cats.any((c) => c.id == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Choose a category' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _keywords,
              decoration: const InputDecoration(labelText: 'Other search words (optional)', hintText: 'arhar, pigeon pea, tuvar'),
            ),
            const SectionTitle('How it is sold'),
            for (final m in _modes.values) _ModeCard(fields: m, onToggle: (v) => setState(() => m.enabled = v)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _inStock,
              activeThumbColor: AppColors.green,
              onChanged: (v) => setState(() => _inStock = v),
              title: const Text('In stock'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              activeThumbColor: AppColors.green,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Show to customers'),
              subtitle: const Text('Turn off to hide the product without deleting it'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save product')),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.fields, required this.onToggle});
  final _ModeFields fields;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final f = fields;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    Widget num(TextEditingController c, String label, {String? suffix, bool decimal = false}) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: decimal ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : digits,
            decoration: InputDecoration(labelText: label, suffixText: suffix, isDense: true),
          ),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          SwitchListTile(
            value: f.enabled,
            onChanged: onToggle,
            activeThumbColor: AppColors.green,
            title: Text(f.kind.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(switch (f.kind) {
              SellModeKind.weight => 'Loose, in grams and kilos (25 g upwards)',
              SellModeKind.piece => 'Counted items, packets, bottles',
              SellModeKind.bag => 'Whole bags for bulk orders, e.g. 50 kg',
            }),
          ),
          if (f.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(children: [
                    num(f.price, switch (f.kind) {
                      SellModeKind.weight => 'Price per kg',
                      SellModeKind.piece => 'Price per piece',
                      SellModeKind.bag => 'Price per bag',
                    }, suffix: '₹', decimal: true),
                    if (f.kind == SellModeKind.bag) ...[const SizedBox(width: 10), num(f.bagKg, 'Bag size', suffix: 'kg', decimal: true)],
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    num(f.min, 'Minimum', suffix: f.unit),
                    const SizedBox(width: 10),
                    num(f.step, 'Step', suffix: f.unit),
                    const SizedBox(width: 10),
                    num(f.max, 'Maximum', suffix: f.unit),
                  ]),
                  if (f.kind == SellModeKind.weight)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('In grams: 1 kg = 1000 g. Step 250 allows 250 g, 500 g, 750 g…', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
