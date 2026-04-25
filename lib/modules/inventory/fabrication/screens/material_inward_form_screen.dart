import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/inventory/fabrication/models/raw_material_inward_model.dart';
import 'package:QUIK/modules/inventory/fabrication/repositories/fabrication_inventory_repository.dart';

class MaterialInwardFormScreen extends StatefulWidget {
  final String tenantId;
  final bool purchaseView;

  const MaterialInwardFormScreen({
    super.key,
    required this.tenantId,
    this.purchaseView = false,
  });

  @override
  State<MaterialInwardFormScreen> createState() =>
      _MaterialInwardFormScreenState();
}

class _MaterialInwardFormScreenState extends State<MaterialInwardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FabricationInventoryRepository _repository;

  final _supplierName = TextEditingController();
  final _challanNo = TextEditingController();
  final _materialDescription = TextEditingController();
  final _grade = TextEditingController();
  final _lengthMm = TextEditingController();
  final _unitWeightKgPerM = TextEditingController();
  final _quantityKg = TextEditingController();
  final _quantityNos = TextEditingController();
  final _remarks = TextEditingController();

  DateTime _inwardDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = FabricationInventoryRepository(tenantId: widget.tenantId);
  }

  @override
  void dispose() {
    _supplierName.dispose();
    _challanNo.dispose();
    _materialDescription.dispose();
    _grade.dispose();
    _lengthMm.dispose();
    _unitWeightKgPerM.dispose();
    _quantityKg.dispose();
    _quantityNos.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await _repository.saveInwardEntry(
        RawMaterialInwardModel(
          inwardId: _repository.newInwardId(),
          inwardDate: _inwardDate,
          supplierName: _supplierName.text.trim(),
          challanNo: _challanNo.text.trim(),
          materialDescription: _materialDescription.text.trim(),
          grade: _grade.text.trim(),
          lengthMm: double.tryParse(_lengthMm.text.trim()) ?? 0,
          unitWeightKgPerM: double.tryParse(_unitWeightKgPerM.text.trim()) ?? 0,
          quantityKg: double.tryParse(_quantityKg.text.trim()) ?? 0,
          quantityNos: double.tryParse(_quantityNos.text.trim()) ?? 0,
          remarks: _remarks.text.trim(),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.purchaseView
                ? 'GRN saved and stock updated'
                : 'Material inward saved and stock updated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save receipt: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inwardDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _inwardDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.purchaseView
        ? 'New GRN / Material Receipt'
        : 'New Material Inward';

    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        title: Text(title),
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
                    _dateField(),
                    _field(_supplierName, 'Supplier Name', required: true),
                    _field(_challanNo, 'Challan / GRN No', required: true),
                    _field(
                      _materialDescription,
                      'Section / Material',
                      width: 420,
                      required: true,
                    ),
                    _field(_grade, 'Grade', required: true),
                    _field(_lengthMm, 'Length (mm)', number: true),
                    _field(
                      _unitWeightKgPerM,
                      'Unit Weight (kg/m)',
                      number: true,
                    ),
                    _field(
                      _quantityKg,
                      'Received Qty (kg)',
                      number: true,
                      required: true,
                    ),
                    _field(_quantityNos, 'Received Qty (nos)', number: true),
                    _field(_remarks, 'Remarks', width: 420),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField() {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Receipt Date'),
          child: Text(_formatDate(_inwardDate)),
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

  String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}
