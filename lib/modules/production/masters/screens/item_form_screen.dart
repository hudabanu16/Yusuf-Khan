import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/production/masters/models/fabrication_item_model.dart';
import 'package:QUIK/modules/production/masters/repositories/item_repository.dart';

class ItemFormScreen extends StatefulWidget {
  final String tenantId;
  final FabricationItemModel? item;

  const ItemFormScreen({super.key, required this.tenantId, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ItemRepository _repository;
  late final String _itemId;

  final _itemCode = TextEditingController();
  final _itemName = TextEditingController();
  final _description = TextEditingController();
  final _itemType = TextEditingController(text: 'manufactured');
  final _category = TextEditingController();
  final _uom = TextEditingController(text: 'nos');
  final _section = TextEditingController();
  final _standardLength = TextEditingController();
  final _unitWeight = TextEditingController();
  final _makeOrBuy = TextEditingController(text: 'make');
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = ItemRepository(tenantId: widget.tenantId);
    _itemId = widget.item?.itemId ?? _repository.newItemId();
    _hydrate();
  }

  void _hydrate() {
    final item = widget.item;
    if (item == null) return;
    _itemCode.text = item.itemCode;
    _itemName.text = item.itemName;
    _description.text = item.description;
    _itemType.text = item.itemType;
    _category.text = item.category;
    _uom.text = item.uom;
    _section.text = item.section;
    _standardLength.text = '${item.standardLength}';
    _unitWeight.text = '${item.unitWeight}';
    _makeOrBuy.text = item.makeOrBuy;
    _isActive = item.isActive;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      await _repository.saveItem(
        FabricationItemModel(
          itemId: _itemId,
          itemCode: _itemCode.text.trim(),
          itemName: _itemName.text.trim(),
          description: _description.text.trim(),
          itemType: _itemType.text.trim().isEmpty
              ? 'manufactured'
              : _itemType.text.trim(),
          category: _category.text.trim(),
          uom: _uom.text.trim().isEmpty ? 'nos' : _uom.text.trim(),
          section: _section.text.trim(),
          standardLength: double.tryParse(_standardLength.text.trim()) ?? 0,
          unitWeight: double.tryParse(_unitWeight.text.trim()) ?? 0,
          makeOrBuy: _makeOrBuy.text.trim().isEmpty
              ? 'make'
              : _makeOrBuy.text.trim(),
          isActive: _isActive,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save item: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _itemCode.dispose();
    _itemName.dispose();
    _description.dispose();
    _itemType.dispose();
    _category.dispose();
    _uom.dispose();
    _section.dispose();
    _standardLength.dispose();
    _unitWeight.dispose();
    _makeOrBuy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        title: Text(widget.item == null ? 'Create Item' : 'Edit Item'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving' : 'Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: zBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _field(_itemCode, 'Item Code', required: true),
                    _field(_itemName, 'Item Name', required: true),
                    _field(_description, 'Description', width: 500),
                    _field(_itemType, 'Item Type'),
                    _field(_category, 'Category'),
                    _field(_uom, 'UOM', width: 120),
                    _field(_section, 'Section'),
                    _field(_standardLength, 'Standard Length mm', number: true),
                    _field(_unitWeight, 'Unit Weight kg/m', number: true),
                    _field(_makeOrBuy, 'Make / Buy', width: 160),
                    SizedBox(
                      width: 180,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 240,
    bool required = false,
    bool number = false,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) =>
                  (value ?? '').trim().isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }
}
