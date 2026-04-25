import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/production/masters/models/work_center_model.dart';
import 'package:QUIK/modules/production/masters/repositories/work_center_repository.dart';

class WorkCenterFormScreen extends StatefulWidget {
  final String tenantId;
  final WorkCenterModel? workCenter;

  const WorkCenterFormScreen({
    super.key,
    required this.tenantId,
    this.workCenter,
  });

  @override
  State<WorkCenterFormScreen> createState() => _WorkCenterFormScreenState();
}

class _WorkCenterFormScreenState extends State<WorkCenterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final WorkCenterRepository _repository;
  late final String _workCenterId;

  final _workCenterCode = TextEditingController();
  final _workCenterName = TextEditingController();
  final _location = TextEditingController();
  final _processIds = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = WorkCenterRepository(tenantId: widget.tenantId);
    _workCenterId =
        widget.workCenter?.workCenterId ?? _repository.newWorkCenterId();
    _hydrate();
  }

  void _hydrate() {
    final workCenter = widget.workCenter;
    if (workCenter == null) return;
    _workCenterCode.text = workCenter.workCenterCode;
    _workCenterName.text = workCenter.workCenterName;
    _location.text = workCenter.location;
    _processIds.text = workCenter.processIds.join(', ');
    _isActive = workCenter.isActive;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      await _repository.saveWorkCenter(
        WorkCenterModel(
          workCenterId: _workCenterId,
          workCenterCode: _workCenterCode.text.trim(),
          workCenterName: _workCenterName.text.trim(),
          processIds: _processIds.text
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
          location: _location.text.trim(),
          isActive: _isActive,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Work center saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save work center: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _workCenterCode.dispose();
    _workCenterName.dispose();
    _location.dispose();
    _processIds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        title: Text(
          widget.workCenter == null ? 'Create Work Center' : 'Edit Work Center',
        ),
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
                    _field(_workCenterCode, 'Work Center Code', required: true),
                    _field(_workCenterName, 'Work Center Name', required: true),
                    _field(_location, 'Location'),
                    _field(
                      _processIds,
                      'Process IDs, comma separated',
                      width: 500,
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
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) =>
                  (value ?? '').trim().isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }
}
