import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/production/masters/models/process_model.dart';
import 'package:QUIK/modules/production/masters/repositories/process_repository.dart';

class ProcessFormScreen extends StatefulWidget {
  final String tenantId;
  final ProcessModel? process;

  const ProcessFormScreen({super.key, required this.tenantId, this.process});

  @override
  State<ProcessFormScreen> createState() => _ProcessFormScreenState();
}

class _ProcessFormScreenState extends State<ProcessFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProcessRepository _repository;
  late final String _processId;

  final _processCode = TextEditingController();
  final _processName = TextEditingController();
  final _operationType = TextEditingController();
  final _defaultSeq = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = ProcessRepository(tenantId: widget.tenantId);
    _processId = widget.process?.processId ?? _repository.newProcessId();
    _hydrate();
  }

  void _hydrate() {
    final process = widget.process;
    if (process == null) return;
    _processCode.text = process.processCode;
    _processName.text = process.processName;
    _operationType.text = process.operationType;
    _defaultSeq.text = '${process.defaultSeq}';
    _isActive = process.isActive;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      await _repository.saveProcess(
        ProcessModel(
          processId: _processId,
          processCode: _processCode.text.trim(),
          processName: _processName.text.trim(),
          operationType: _operationType.text.trim(),
          defaultSeq: int.tryParse(_defaultSeq.text.trim()) ?? 0,
          isActive: _isActive,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Process saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save process: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _processCode.dispose();
    _processName.dispose();
    _operationType.dispose();
    _defaultSeq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        title: Text(widget.process == null ? 'Create Process' : 'Edit Process'),
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
                    _field(_processCode, 'Process Code', required: true),
                    _field(_processName, 'Process Name', required: true),
                    _field(_operationType, 'Operation Type', required: true),
                    _field(
                      _defaultSeq,
                      'Default Seq',
                      width: 140,
                      number: true,
                    ),
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
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) =>
                  (value ?? '').trim().isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }
}
