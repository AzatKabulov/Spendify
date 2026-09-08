import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_colors.dart';
import '../../core/category_icons.dart';
import '../../domain/entities/category.dart';
import '../providers/category_providers.dart';
import '../widgets/category_avatar.dart';
import '../widgets/color_picker.dart';
import '../widgets/icon_picker.dart';

/// Create (when [existing] is null) or edit a category. Name + icon + colour.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({this.existing, super.key});

  final Category? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _iconCode;
  late int _colorValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _nameController = TextEditingController(text: c?.name ?? '');
    _iconCode = c?.iconCode ?? kCategoryIcons.first.codePoint;
    _colorValue = c?.colorValue ?? kCategoryColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? raw) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) return 'Enter a name';
    final existing = ref.read(categoriesProvider).value ?? const <Category>[];
    if (isCategoryNameTaken(existing, name, excludingId: widget.existing?.id)) {
      return 'A category called "$name" already exists';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final actions = ref.read(categoryActionsProvider);
    try {
      if (widget.existing case final existing?) {
        await actions.edit(
          existing,
          name: _nameController.text,
          iconCode: _iconCode,
          colorValue: _colorValue,
        );
      } else {
        await actions.create(
          name: _nameController.text,
          iconCode: _iconCode,
          colorValue: _colorValue,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the category list subscribed so [_validateName] sees a live value.
    ref.watch(categoriesProvider);

    final preview = Category(
      id: 'preview',
      userId: 'preview',
      name: _nameController.text,
      iconCode: _iconCode,
      colorValue: _colorValue,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit category' : 'New category'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Center(child: CategoryAvatar(category: preview, radius: 28)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: !widget.isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: _validateName,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              IconPicker(
                selectedCode: _iconCode,
                onSelected: (c) => setState(() => _iconCode = c),
              ),
              const SizedBox(height: 24),
              Text('Colour', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              ColorPicker(
                selectedValue: _colorValue,
                onSelected: (v) => setState(() => _colorValue = v),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(widget.isEditing ? 'Save changes' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
