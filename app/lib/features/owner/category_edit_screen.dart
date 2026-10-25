import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/catalogue.dart';
import '../../core/data/firebase.dart';
import '../../core/data/owner.dart';
import '../../core/ui/widgets.dart';

class CategoryEditScreen extends ConsumerStatefulWidget {
  const CategoryEditScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  ConsumerState<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends ConsumerState<CategoryEditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameHi = TextEditingController();
  final _order = TextEditingController(text: '0');
  bool _active = true;
  String? _imageUrl;
  Uint8List? _newPhoto;
  bool _loaded = false;
  bool _busy = false;

  bool get _isNew => widget.categoryId == 'new';

  void _load() {
    if (_loaded) return;
    final cat = ref.read(ownerCatalogueProvider).value?.categories.where((c) => c.id == widget.categoryId).firstOrNull;
    if (cat != null) {
      _name.text = cat.name;
      _nameHi.text = cat.nameHi;
      _order.text = '${cat.sortOrder}';
      _active = cat.active;
      _imageUrl = cat.imageUrl;
    } else if (_isNew) {
      _order.text = '${(ref.read(ownerCatalogueProvider).value?.categories.length ?? 0) * 10}';
    }
    _loaded = true;
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (f != null) {
      final bytes = await f.readAsBytes();
      setState(() => _newPhoto = bytes);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(ownerRepositoryProvider);
    try {
      final id = _isNew ? repo.newCategoryId() : widget.categoryId;
      var imageUrl = _imageUrl;
      if (_newPhoto != null) imageUrl = await repo.uploadCategoryPhoto(id, _newPhoto!);
      await repo.saveCategory(id, {
        'name': _name.text.trim(),
        'nameHi': _nameHi.text.trim(),
        'sortOrder': int.tryParse(_order.text) ?? 0,
        'active': _active,
        'imageUrl': imageUrl,
        'imagePath': 'categories/$id.webp',
      });
      ref.invalidate(ownerCatalogueProvider);
      ref.invalidate(catalogueProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ownerCatalogueProvider);
    _load();
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New category' : 'Edit category')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: InkWell(
                onTap: _pick,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: _newPhoto != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_newPhoto!, fit: BoxFit.cover))
                      : Photo(_imageUrl, size: 160, radius: 16, icon: Icons.add_a_photo_outlined),
                ),
              ),
            ),
            TextButton(onPressed: _pick, child: const Text('Choose photo')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _nameHi, decoration: const InputDecoration(labelText: 'Hindi name (optional)')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _order,
              decoration: const InputDecoration(labelText: 'Position', helperText: 'Lower numbers show first'),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Show to customers'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
        ),
      ),
    );
  }
}
