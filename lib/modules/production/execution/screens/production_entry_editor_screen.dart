import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/production/execution/models/production_entry_model.dart';
import 'package:QUIK/modules/production/execution/models/production_line_model.dart';
import 'package:QUIK/modules/production/execution/repositories/production_repository.dart';
import 'package:QUIK/modules/production/execution/services/daily_production_pdf_service.dart';

class ProductionEntryEditorScreen extends StatefulWidget {
  final String tenantId;
  final ProductionEntryModel? entry;

  const ProductionEntryEditorScreen({
    super.key,
    required this.tenantId,
    this.entry,
  });

  @override
  State<ProductionEntryEditorScreen> createState() =>
      _ProductionEntryEditorScreenState();
}

class _ProductionEntryEditorScreenState
    extends State<ProductionEntryEditorScreen> {
  static const _operations = ['cutting', 'punching', 'bending', 'welding'];
  static const double _gridWidth = 1358;

  final _formKey = GlobalKey<FormState>();
  late final ProductionRepository _repository;
  late final String _entryId;

  final _shift = TextEditingController(text: 'A');
  final _operatorId = TextEditingController();
  final _workCenterId = TextEditingController();
  final _supervisorId = TextEditingController();
  final _status = TextEditingController(text: 'draft');

  final List<_ProductionLineDraft> _lines = [];
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = ProductionRepository(tenantId: widget.tenantId);
    _entryId = widget.entry?.entryId ?? _repository.newEntryId();
    _hydrateHeader();
    _loadLines();
  }

  void _hydrateHeader() {
    final entry = widget.entry;
    _date = entry?.date ?? DateTime.now();
    _shift.text = entry?.shift.isEmpty == false ? entry!.shift : 'A';
    _operatorId.text = entry?.operatorId ?? '';
    _workCenterId.text = entry?.workCenterId ?? '';
    _supervisorId.text = entry?.supervisorId ?? '';
    _status.text = entry?.status ?? 'draft';
  }

  Future<void> _loadLines() async {
    if (widget.entry == null) {
      _lines.add(_ProductionLineDraft(workCenterId: _workCenterId.text));
      setState(() => _loading = false);
      return;
    }

    final lines = await _repository.fetchEntryLines(_entryId);
    _lines
      ..clear()
      ..addAll(lines.map(_ProductionLineDraft.fromModel));
    if (_lines.isEmpty) {
      _lines.add(_ProductionLineDraft(workCenterId: _workCenterId.text));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _addLine() {
    final previous = _lines.isEmpty ? null : _lines.last;
    setState(() {
      _lines.add(
        _ProductionLineDraft.quick(
          previous: previous,
          workCenterId: _workCenterId.text,
        ),
      );
    });
  }

  void _duplicateLine(int index) {
    setState(() => _lines.insert(index + 1, _lines[index].copy()));
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    setState(() => _lines.removeAt(index).dispose());
  }

  Future<void> _loadDemoDay() async {
    final hasUserData =
        _operatorId.text.trim().isNotEmpty ||
        _workCenterId.text.trim().isNotEmpty ||
        _lines.any((line) => !line.isBlank);

    if (hasUserData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Load demo production day?'),
          content: const Text(
            'This will replace the current unsaved production rows on this screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Load Demo'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    for (final line in _lines) {
      line.dispose();
    }

    setState(() {
      _date = DateTime.now();
      _shift.text = 'A';
      _operatorId.text = 'Shop Floor Team A';
      _workCenterId.text = 'FAB-BAY-01';
      _supervisorId.text = 'Supervisor';
      _status.text = 'draft';
      _lines
        ..clear()
        ..addAll(_DemoProductionData.lines.map(_ProductionLineDraft.demo));
    });
  }

  Future<void> _printPdf() async {
    final entry = _buildEntryModel();
    final lines = _buildLineModels();
    await Printing.layoutPdf(
      name: 'daily_production_${_dateLabel(_date)}.pdf',
      onLayout: (_) => DailyProductionPdfService.buildDailyProductionPdf(
        entry: entry,
        lines: lines,
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final entry = _buildEntryModel();
      final lineModels = _buildLineModels();

      await _repository.saveEntry(entry);
      await _repository.replaceEntryLines(entryId: _entryId, lines: lineModels);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Production entry saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save production entry: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  ProductionEntryModel _buildEntryModel() {
    return ProductionEntryModel(
      entryId: _entryId,
      date: _date,
      shift: _shift.text.trim(),
      operatorId: _operatorId.text.trim(),
      workCenterId: _workCenterId.text.trim(),
      supervisorId: _supervisorId.text.trim(),
      tenantId: widget.tenantId,
      status: _status.text.trim().isEmpty ? 'draft' : _status.text.trim(),
    );
  }

  List<ProductionLineModel> _buildLineModels() {
    final lineModels = <ProductionLineModel>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.isBlank) continue;
      lineModels.add(
        ProductionLineModel(
          lineId: line.lineId ?? _repository.newLineId(_entryId),
          lineNo: i + 1,
          itemId: line.itemId,
          clientName: line.clientName.text.trim(),
          itemCode: line.itemName.text.trim(),
          description: line.itemName.text.trim(),
          section: line.section.text.trim(),
          length: line.lengthValue,
          operationType: line.operation,
          processId: line.processId.text.trim(),
          workCenterId: line.workCenterId.text.trim().isEmpty
              ? _workCenterId.text.trim()
              : line.workCenterId.text.trim(),
          holeSize: line.holeSize.text.trim(),
          quantity: line.quantityValue,
          uom: line.uom.text.trim().isEmpty ? 'nos' : line.uom.text.trim(),
          remarks: line.remarks.text.trim(),
        ),
      );
    }
    return lineModels;
  }

  @override
  void dispose() {
    _shift.dispose();
    _operatorId.dispose();
    _workCenterId.dispose();
    _supervisorId.dispose();
    _status.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: zBlue)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EC),
      appBar: AppBar(
        title: Text(
          widget.entry == null
              ? 'Daily Production Register'
              : 'Edit Production Register',
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _loadDemoDay,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Load Demo'),
          ),
          TextButton.icon(
            onPressed: _saving ? null : _printPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Print / PDF'),
          ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 820;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _registerHeader(compact: compact),
                  const SizedBox(height: 10),
                  if (compact) _mobileRows() else _registerGrid(),
                  const SizedBox(height: 12),
                  _footerActions(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _registerHeader({required bool compact}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF3),
        border: Border.all(color: _ink, width: 1.3),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF6E6C8),
              border: Border(bottom: BorderSide(color: _ink, width: 1.1)),
            ),
            child: const Text(
              'DAILY PRODUCTION REGISTER',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          if (compact)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _headerFields(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: _headerFields()
                    .map((child) => Expanded(child: child))
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _headerFields() {
    return [
      _dateField(),
      _headerField(_shift, 'Shift', width: 110, required: true),
      _headerField(_operatorId, 'Operator', width: 190),
      _headerField(_workCenterId, 'Work Center', width: 190),
      _headerField(_supervisorId, 'Supervisor', width: 190),
    ];
  }

  Widget _dateField() {
    return SizedBox(
      width: 190,
      child: InputDecorator(
        decoration: _registerInputDecoration('Date'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dateLabel(_date),
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Pick date',
              visualDensity: VisualDensity.compact,
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerField(
    TextEditingController controller,
    String label, {
    double width = 180,
    bool required = false,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: _registerInputDecoration(label),
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
        validator: required
            ? (value) =>
                  (value ?? '').trim().isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }

  Widget _registerGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: _gridWidth,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF3),
          border: Border.all(color: _ink, width: 1.2),
        ),
        child: Table(
          border: const TableBorder(
            horizontalInside: BorderSide(color: _ink, width: 0.85),
            verticalInside: BorderSide(color: _ink, width: 0.85),
          ),
          columnWidths: const {
            0: FixedColumnWidth(54),
            1: FixedColumnWidth(150),
            2: FixedColumnWidth(170),
            3: FixedColumnWidth(150),
            4: FixedColumnWidth(110),
            5: FixedColumnWidth(140),
            6: FixedColumnWidth(150),
            7: FixedColumnWidth(100),
            8: FixedColumnWidth(245),
            9: FixedColumnWidth(88),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFEFF3F8)),
              children: [
                _tableHeader('Sr No'),
                _tableHeader('Client Name'),
                _tableHeader('Item Name'),
                _tableHeader('Section'),
                _tableHeader('Length\n(mm)'),
                _tableHeader('Operation'),
                _tableHeader('Hole / Slot Size'),
                _tableHeader('Quantity'),
                _tableHeader('Remarks'),
                _tableHeader(''),
              ],
            ),
            for (var i = 0; i < _lines.length; i++)
              TableRow(
                decoration: BoxDecoration(
                  color: i.isEven
                      ? const Color(0xFFFFFCF3)
                      : const Color(0xFFFBF7EA),
                ),
                children: [
                  _tableText('${i + 1}'),
                  _tableField(_lines[i].clientName),
                  _tableField(_lines[i].itemName),
                  _tableField(_lines[i].section),
                  _tableField(_lines[i].length, number: true),
                  _operationCell(_lines[i]),
                  _tableField(_lines[i].holeSize),
                  _tableField(_lines[i].quantity, number: true),
                  _tableField(_lines[i].remarks),
                  _rowActions(i),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _mobileRows() {
    return Column(
      children: [
        for (var i = 0; i < _lines.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF3),
              border: Border.all(color: _ink, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Sr No ${i + 1}',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Duplicate row',
                      onPressed: () => _duplicateLine(i),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove row',
                      onPressed: () => _removeLine(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _mobileField(_lines[i].clientName, 'Client Name', 220),
                    _mobileField(_lines[i].itemName, 'Item Name', 220),
                    _mobileField(_lines[i].section, 'Section', 180),
                    _mobileField(
                      _lines[i].length,
                      'Length (mm)',
                      150,
                      number: true,
                    ),
                    _mobileOperation(_lines[i]),
                    _mobileField(_lines[i].holeSize, 'Hole / Slot Size', 180),
                    _mobileField(
                      _lines[i].quantity,
                      'Quantity',
                      130,
                      number: true,
                    ),
                    _mobileField(_lines[i].remarks, 'Remarks', 260),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _footerActions() {
    final totalQuantity = _lines.fold<double>(
      0,
      (sum, line) => sum + line.quantityValue,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF3),
        border: Border.all(color: _ink),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          FilledButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add),
            label: const Text('Add Row'),
          ),
          OutlinedButton.icon(
            onPressed: _lines.isEmpty
                ? null
                : () => _duplicateLine(_lines.length - 1),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Duplicate Last'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF6E6C8),
              border: Border.all(color: _ink),
            ),
            child: Text(
              'Total Qty: ${_num(totalQuantity)} Nos',
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ink,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _tableField(TextEditingController controller, {bool number = false}) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 13),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _operationCell(_ProductionLineDraft line) {
    return SizedBox(
      height: 44,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _operations.contains(line.operation)
              ? line.operation
              : _operations.first,
          isExpanded: true,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          items: _operations
              .map(
                (operation) => DropdownMenuItem(
                  value: operation,
                  child: Center(child: Text(operation)),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            setState(() => line.operation = value);
          },
        ),
      ),
    );
  }

  Widget _rowActions(int index) {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Duplicate row',
            visualDensity: VisualDensity.compact,
            onPressed: () => _duplicateLine(index),
            icon: const Icon(Icons.copy_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Remove row',
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeLine(index),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _tableText(String text) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _mobileField(
    TextEditingController controller,
    String label,
    double width, {
    bool number = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: _registerInputDecoration(label),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _mobileOperation(_ProductionLineDraft line) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        initialValue: _operations.contains(line.operation)
            ? line.operation
            : 'cutting',
        decoration: _registerInputDecoration('Operation'),
        items: _operations
            .map(
              (operation) =>
                  DropdownMenuItem(value: operation, child: Text(operation)),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value == null) return;
          setState(() => line.operation = value);
        },
      ),
    );
  }

  InputDecoration _registerInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFFFCF3),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _ink, width: 0.8),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: zBlue, width: 1.2),
      ),
      isDense: true,
    );
  }

  String _dateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _num(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}

class _ProductionLineDraft {
  String? lineId;
  String? itemId;
  final clientName = TextEditingController();
  final itemName = TextEditingController();
  final section = TextEditingController();
  final length = TextEditingController();
  String operation = 'cutting';
  final processId = TextEditingController();
  final workCenterId = TextEditingController();
  final holeSize = TextEditingController();
  final quantity = TextEditingController();
  final uom = TextEditingController(text: 'nos');
  final remarks = TextEditingController();

  _ProductionLineDraft({String workCenterId = ''}) {
    this.workCenterId.text = workCenterId;
  }

  _ProductionLineDraft.demo(_DemoProductionLine line) {
    clientName.text = line.clientName;
    itemName.text = line.itemName;
    section.text = line.section;
    length.text = _formatNumber(line.length);
    operation = line.operation;
    holeSize.text = line.holeSize;
    quantity.text = _formatNumber(line.quantity);
    remarks.text = line.remarks;
    workCenterId.text = 'FAB-BAY-01';
  }

  _ProductionLineDraft.quick({
    required _ProductionLineDraft? previous,
    required String workCenterId,
  }) {
    this.workCenterId.text = workCenterId;
    if (previous == null) return;
    clientName.text = previous.clientName.text;
    itemName.text = previous.itemName.text;
    section.text = previous.section.text;
    length.text = previous.length.text;
    operation = previous.operation;
    processId.text = previous.processId.text;
    this.workCenterId.text = previous.workCenterId.text.isEmpty
        ? workCenterId
        : previous.workCenterId.text;
    holeSize.text = previous.holeSize.text;
    uom.text = previous.uom.text;
    remarks.text = previous.remarks.text;
  }

  _ProductionLineDraft.fromModel(ProductionLineModel model) {
    lineId = model.lineId;
    itemId = model.itemId;
    clientName.text = model.clientName;
    itemName.text = model.description.isNotEmpty
        ? model.description
        : model.itemCode;
    section.text = model.section;
    length.text = _formatNumber(model.length);
    operation = model.operationType.isEmpty ? 'cutting' : model.operationType;
    processId.text = model.processId;
    workCenterId.text = model.workCenterId;
    holeSize.text = model.holeSize;
    quantity.text = _formatNumber(model.quantity);
    uom.text = model.uom;
    remarks.text = model.remarks;
  }

  _ProductionLineDraft copy() {
    final copy = _ProductionLineDraft();
    copy.clientName.text = clientName.text;
    copy.itemName.text = itemName.text;
    copy.section.text = section.text;
    copy.length.text = length.text;
    copy.operation = operation;
    copy.processId.text = processId.text;
    copy.workCenterId.text = workCenterId.text;
    copy.holeSize.text = holeSize.text;
    copy.quantity.text = quantity.text;
    copy.uom.text = uom.text;
    copy.remarks.text = remarks.text;
    return copy;
  }

  bool get isBlank {
    return clientName.text.trim().isEmpty &&
        itemName.text.trim().isEmpty &&
        section.text.trim().isEmpty &&
        length.text.trim().isEmpty &&
        quantity.text.trim().isEmpty &&
        remarks.text.trim().isEmpty;
  }

  double get lengthValue => double.tryParse(length.text.trim()) ?? 0;
  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;

  void dispose() {
    clientName.dispose();
    itemName.dispose();
    section.dispose();
    length.dispose();
    processId.dispose();
    workCenterId.dispose();
    holeSize.dispose();
    quantity.dispose();
    uom.dispose();
    remarks.dispose();
  }
}

const Color _ink = Color(0xFF1E2E6D);

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

class _DemoProductionLine {
  final String clientName;
  final String itemName;
  final String section;
  final double length;
  final String operation;
  final String holeSize;
  final double quantity;
  final String remarks;

  const _DemoProductionLine({
    required this.clientName,
    required this.itemName,
    required this.section,
    required this.length,
    required this.operation,
    required this.holeSize,
    required this.quantity,
    required this.remarks,
  });
}

class _DemoProductionData {
  static const lines = [
    _DemoProductionLine(
      clientName: 'INDUS SOLAR',
      itemName: 'COLUMN',
      section: 'CU - 4X40X95',
      length: 100,
      operation: 'bending',
      holeSize: 'Bending',
      quantity: 1300,
      remarks: 'company',
    ),
    _DemoProductionLine(
      clientName: 'INDUS SOLAR',
      itemName: 'BASE PLATE',
      section: 'PL - 8X305',
      length: 317,
      operation: 'cutting',
      holeSize: 'Cutting',
      quantity: 327,
      remarks: 'company',
    ),
    _DemoProductionLine(
      clientName: 'INDUS SOLAR',
      itemName: 'CLEAT',
      section: 'L - 6X75',
      length: 80,
      operation: 'cutting',
      holeSize: 'Cutting',
      quantity: 550,
      remarks: 'company',
    ),
    _DemoProductionLine(
      clientName: 'INDUS SOLAR 2PX3',
      itemName: 'TEMPLATE',
      section: 'PL - 4X325',
      length: 325,
      operation: 'cutting',
      holeSize: 'Cutting',
      quantity: 483,
      remarks: 'company',
    ),
    _DemoProductionLine(
      clientName: 'OM SOLAR',
      itemName: 'JOINT CLEAT',
      section: 'L - 5X75X75',
      length: 80,
      operation: 'cutting',
      holeSize: 'Cutting',
      quantity: 750,
      remarks: 'cont.',
    ),
    _DemoProductionLine(
      clientName: 'INDUS SOLAR',
      itemName: 'BR. BEND PLATE',
      section: 'PL - 8X80',
      length: 235,
      operation: 'punching',
      holeSize: 'Ø14X20 mm slot',
      quantity: 110,
      remarks: 'cont.',
    ),
    _DemoProductionLine(
      clientName: 'INDUS SOLAR',
      itemName: 'BR. BEND PLATE',
      section: 'PL - 8X55',
      length: 297,
      operation: 'punching',
      holeSize: 'Ø10 mm hole',
      quantity: 352,
      remarks: 'cont.',
    ),
    _DemoProductionLine(
      clientName: 'OM SOLAR',
      itemName: 'BASE PLATE',
      section: 'PL - 5X150',
      length: 150,
      operation: 'punching',
      holeSize: 'Ø12X25 mm slot',
      quantity: 540,
      remarks: 'company',
    ),
  ];
}
