import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/inventory/fabrication/models/raw_material_issue_model.dart';
import 'package:QUIK/modules/inventory/fabrication/repositories/fabrication_inventory_repository.dart';

class MaterialIssueFormScreen extends StatefulWidget {
  final String tenantId;

  const MaterialIssueFormScreen({super.key, required this.tenantId});

  @override
  State<MaterialIssueFormScreen> createState() =>
      _MaterialIssueFormScreenState();
}

class _MaterialIssueFormScreenState extends State<MaterialIssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FabricationInventoryRepository _repository;

  final _issuedTo = TextEditingController();
  final _workOrderId = TextEditingController();
  final _materialDescription = TextEditingController();
  final _grade = TextEditingController();
  final _lengthMm = TextEditingController();
  final _unitWeightKgPerM = TextEditingController();
  final _quantityKg = TextEditingController();
  final _remarks = TextEditingController();

  DateTime _issueDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = FabricationInventoryRepository(tenantId: widget.tenantId);
  }

  @override
  void dispose() {
    _issuedTo.dispose();
    _workOrderId.dispose();
    _materialDescription.dispose();
    _grade.dispose();
    _lengthMm.dispose();
    _unitWeightKgPerM.dispose();
    _quantityKg.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await _repository.saveIssueEntry(
        RawMaterialIssueModel(
          issueId: _repository.newIssueId(),
          issueDate: _issueDate,
          issuedTo: _issuedTo.text.trim(),
          workOrderId: _workOrderId.text.trim(),
          materialDescription: _materialDescription.text.trim(),
          grade: _grade.text.trim(),
          lengthMm: double.tryParse(_lengthMm.text.trim()) ?? 0,
          unitWeightKgPerM: double.tryParse(_unitWeightKgPerM.text.trim()) ?? 0,
          quantityKg: double.tryParse(_quantityKg.text.trim()) ?? 0,
          remarks: _remarks.text.trim(),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material issue saved and stock updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save issue: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _issueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        title: const Text('New Material Issue'),
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
                    _field(_issuedTo, 'Issued To / Process', required: true),
                    _field(_workOrderId, 'Work Order'),
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
                      'Issued Qty (kg)',
                      number: true,
                      required: true,
                    ),
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
          decoration: const InputDecoration(labelText: 'Issue Date'),
          child: Text(_formatDate(_issueDate)),
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
