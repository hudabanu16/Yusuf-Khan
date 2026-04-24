import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/production/bom/models/bom_header_model.dart';
import 'package:QUIK/modules/production/bom/models/bom_line_model.dart';
import 'package:QUIK/modules/production/bom/repositories/bom_repository.dart';

class BomEditorScreen extends StatefulWidget {
  final String tenantId;
  final BomHeaderModel? bom;

  const BomEditorScreen({super.key, required this.tenantId, this.bom});

  @override
  State<BomEditorScreen> createState() => _BomEditorScreenState();
}

class _BomEditorScreenState extends State<BomEditorScreen> {
  static const double _lineGridWidth = 1374;

  final _formKey = GlobalKey<FormState>();
  late final BomRepository _repository;
  late final String _bomId;

  final _bomCode = TextEditingController();
  final _bomName = TextEditingController();
  final _parentItemId = TextEditingController();
  final _revisionNo = TextEditingController(text: '1');
  final _status = TextEditingController(text: 'draft');
  final _drawingNo = TextEditingController();
  final _customerId = TextEditingController();
  final _projectId = TextEditingController();
  final _remarks = TextEditingController();

  final List<_BomLineDraft> _lines = [];
  final _lineScrollController = ScrollController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = BomRepository(tenantId: widget.tenantId);
    _bomId = widget.bom?.bomId ?? _repository.newBomId();
    _hydrateHeader();
    _loadLines();
  }

  void _hydrateHeader() {
    final bom = widget.bom;
    _bomCode.text =
        bom?.bomCode ?? 'BOM-${DateTime.now().millisecondsSinceEpoch}';
    _bomName.text = bom?.bomName ?? '';
    _parentItemId.text = bom?.parentItemId ?? '';
    _revisionNo.text = '${bom?.revisionNo == 0 ? 1 : bom?.revisionNo ?? 1}';
    _status.text = bom?.status ?? 'draft';
    _drawingNo.text = bom?.drawingNo ?? '';
    _customerId.text = bom?.customerId ?? '';
    _projectId.text = bom?.projectId ?? '';
    _remarks.text = bom?.remarks ?? '';
  }

  Future<void> _loadLines() async {
    if (widget.bom == null) {
      _lines.add(_BomLineDraft());
      setState(() => _loading = false);
      return;
    }

    final lines = await _repository.fetchBomLines(_bomId);
    _lines
      ..clear()
      ..addAll(lines.map(_BomLineDraft.fromModel));
    if (_lines.isEmpty) _lines.add(_BomLineDraft());
    if (mounted) setState(() => _loading = false);
  }

  double get _totalWeight {
    return _lines.fold(0, (sum, line) => sum + line.totalWeight);
  }

  void _addLine() {
    setState(() => _lines.add(_BomLineDraft()));
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    setState(() => _lines.removeAt(index).dispose());
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final header = BomHeaderModel(
        bomId: _bomId,
        bomCode: _bomCode.text.trim(),
        bomName: _bomName.text.trim(),
        parentItemId: _parentItemId.text.trim(),
        revisionNo: int.tryParse(_revisionNo.text.trim()) ?? 1,
        status: _status.text.trim().isEmpty ? 'draft' : _status.text.trim(),
        drawingNo: _drawingNo.text.trim(),
        customerId: _emptyToNull(_customerId.text),
        projectId: _emptyToNull(_projectId.text),
        remarks: _remarks.text.trim(),
      );

      final lineModels = <BomLineModel>[];
      for (var i = 0; i < _lines.length; i++) {
        final line = _lines[i];
        if (line.isBlank) continue;
        lineModels.add(
          BomLineModel(
            lineId: line.lineId ?? _repository.newBomLineId(_bomId),
            lineNo: i + 1,
            itemId: line.itemId.text.trim(),
            itemCode: line.itemCode.text.trim(),
            description: line.description.text.trim(),
            qtyPer: line.qtyPerValue,
            uom: line.uom.text.trim().isEmpty ? 'nos' : line.uom.text.trim(),
            length: line.lengthValue,
            width: line.widthValue,
            thickness: line.thicknessValue,
            unitWeight: line.unitWeightValue,
            totalWeight: line.totalWeight,
            scrapPercent: line.scrapPercentValue,
            processId: line.processId.text.trim(),
            operationSeq: line.operationSeqValue,
            makeOrBuy: line.makeOrBuy.text.trim().isEmpty
                ? 'make'
                : line.makeOrBuy.text.trim(),
            remarks: line.remarks.text.trim(),
          ),
        );
      }

      await _repository.saveBomHeader(header);
      await _repository.replaceBomLines(bomId: _bomId, lines: lineModels);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('BOM saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save BOM: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _bomCode.dispose();
    _bomName.dispose();
    _parentItemId.dispose();
    _revisionNo.dispose();
    _status.dispose();
    _drawingNo.dispose();
    _customerId.dispose();
    _projectId.dispose();
    _remarks.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    _lineScrollController.dispose();
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
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        title: Text(widget.bom == null ? 'Create BOM' : 'Edit BOM'),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionCard(
                    title: 'BOM Header',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _field(_bomCode, 'BOM Code', required: true),
                        _field(_bomName, 'BOM Name', required: true),
                        _field(_parentItemId, 'Parent Item / Assembly'),
                        _field(
                          _revisionNo,
                          'Revision No',
                          width: 130,
                          number: true,
                        ),
                        _field(_status, 'Status', width: 150),
                        _field(_drawingNo, 'Drawing No'),
                        _field(_customerId, 'Customer'),
                        _field(_projectId, 'Project'),
                        _field(_remarks, 'Remarks', width: 500),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'BOM Lines and Operations',
                    trailing: FilledButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Line'),
                    ),
                    child: desktop
                        ? _BomLineTable(
                            width: _lineGridWidth,
                            controller: _lineScrollController,
                            lines: _lines,
                            onChanged: () => setState(() {}),
                            onRemove: _removeLine,
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < _lines.length; i++) ...[
                                _BomLineCard(
                                  index: i,
                                  line: _lines[i],
                                  onChanged: () => setState(() {}),
                                  onRemove: () => _removeLine(i),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: zBorder),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Estimated BOM Weight',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${_totalWeight.toStringAsFixed(2)} kg',
                          style: const TextStyle(
                            color: zBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
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

class _BomLineDraft {
  String? lineId;
  final itemId = TextEditingController();
  final itemCode = TextEditingController();
  final description = TextEditingController();
  final qtyPer = TextEditingController(text: '1');
  final uom = TextEditingController(text: 'nos');
  final length = TextEditingController();
  final width = TextEditingController();
  final thickness = TextEditingController();
  final unitWeight = TextEditingController();
  final scrapPercent = TextEditingController();
  final processId = TextEditingController();
  final operationSeq = TextEditingController();
  final makeOrBuy = TextEditingController(text: 'make');
  final remarks = TextEditingController();

  _BomLineDraft();

  _BomLineDraft.fromModel(BomLineModel model) {
    lineId = model.lineId;
    itemId.text = model.itemId;
    itemCode.text = model.itemCode;
    description.text = model.description;
    qtyPer.text = '${model.qtyPer}';
    uom.text = model.uom;
    length.text = '${model.length}';
    width.text = '${model.width}';
    thickness.text = '${model.thickness}';
    unitWeight.text = '${model.unitWeight}';
    scrapPercent.text = '${model.scrapPercent}';
    processId.text = model.processId;
    operationSeq.text = '${model.operationSeq}';
    makeOrBuy.text = model.makeOrBuy;
    remarks.text = model.remarks;
  }

  bool get isBlank {
    return itemCode.text.trim().isEmpty &&
        description.text.trim().isEmpty &&
        qtyPer.text.trim().isEmpty &&
        unitWeight.text.trim().isEmpty;
  }

  double get qtyPerValue => double.tryParse(qtyPer.text.trim()) ?? 0;
  double get lengthValue => double.tryParse(length.text.trim()) ?? 0;
  double get widthValue => double.tryParse(width.text.trim()) ?? 0;
  double get thicknessValue => double.tryParse(thickness.text.trim()) ?? 0;
  double get unitWeightValue => double.tryParse(unitWeight.text.trim()) ?? 0;
  double get scrapPercentValue =>
      double.tryParse(scrapPercent.text.trim()) ?? 0;
  int get operationSeqValue => int.tryParse(operationSeq.text.trim()) ?? 0;
  double get totalWeight {
    final baseWeight = qtyPerValue * unitWeightValue;
    return baseWeight * (1 + (scrapPercentValue / 100));
  }

  void dispose() {
    itemId.dispose();
    itemCode.dispose();
    description.dispose();
    qtyPer.dispose();
    uom.dispose();
    length.dispose();
    width.dispose();
    thickness.dispose();
    unitWeight.dispose();
    scrapPercent.dispose();
    processId.dispose();
    operationSeq.dispose();
    makeOrBuy.dispose();
    remarks.dispose();
  }
}

class _BomLineCard extends StatelessWidget {
  final int index;
  final _BomLineDraft line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _BomLineCard({
    required this.index,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Line ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove line',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _field(line.itemCode, 'Item Code', 130),
              _field(line.description, 'Description', 240),
              _field(line.qtyPer, 'Qty/Assembly', 120, number: true),
              _field(line.uom, 'UOM', 90),
              _field(line.length, 'Length mm', 120, number: true),
              _field(line.width, 'Width mm', 120, number: true),
              _field(line.thickness, 'Thk mm', 110, number: true),
              _field(line.unitWeight, 'Unit Wt kg', 130, number: true),
              _field(line.scrapPercent, 'Scrap %', 110, number: true),
              _field(line.operationSeq, 'Op Seq', 100, number: true),
              _field(line.processId, 'Operation / Process', 170),
              _field(line.makeOrBuy, 'Make/Buy', 110),
              _field(line.remarks, 'Remarks', 240),
              _readOnly('Line Weight (kg)', line.totalWeight),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
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
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => onChanged(),
      ),
    );
  }

  Widget _readOnly(String label, double value) {
    return SizedBox(
      width: 120,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _BomLineTable extends StatelessWidget {
  final double width;
  final ScrollController controller;
  final List<_BomLineDraft> lines;
  final VoidCallback onChanged;
  final void Function(int index) onRemove;

  const _BomLineTable({
    required this.width,
    required this.controller,
    required this.lines,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: zBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Table(
              border: const TableBorder(
                horizontalInside: BorderSide(color: zBorder),
                verticalInside: BorderSide(color: zBorder),
              ),
              columnWidths: const {
                0: FixedColumnWidth(54),
                1: FixedColumnWidth(130),
                2: FixedColumnWidth(210),
                3: FixedColumnWidth(94),
                4: FixedColumnWidth(94),
                5: FixedColumnWidth(94),
                6: FixedColumnWidth(94),
                7: FixedColumnWidth(120),
                8: FixedColumnWidth(96),
                9: FixedColumnWidth(154),
                10: FixedColumnWidth(106),
                11: FixedColumnWidth(168),
                12: FixedColumnWidth(110),
                13: FixedColumnWidth(50),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    _header('Line'),
                    _header('Item'),
                    _header('Section / Description'),
                    _header('Qty'),
                    _header('Length'),
                    _header('Width'),
                    _header('Thickness'),
                    _header('Unit Weight'),
                    _header('Scrap %'),
                    _header('Operation / Process'),
                    _header('Make/Buy'),
                    _header('Remarks'),
                    _header('Line Weight (kg)'),
                    _header(''),
                  ],
                ),
                for (var i = 0; i < lines.length; i++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                    ),
                    children: [
                      _text('${i + 1}'),
                      _field(lines[i].itemCode),
                      _sectionField(lines[i]),
                      _field(lines[i].qtyPer, number: true),
                      _field(lines[i].length, number: true),
                      _field(lines[i].width, number: true),
                      _field(lines[i].thickness, number: true),
                      _field(lines[i].unitWeight, number: true),
                      _field(lines[i].scrapPercent, number: true),
                      _field(lines[i].processId),
                      _field(lines[i].makeOrBuy),
                      _field(lines[i].remarks),
                      _text(lines[i].totalWeight.toStringAsFixed(2)),
                      SizedBox(
                        height: 44,
                        child: IconButton(
                          tooltip: 'Remove line',
                          onPressed: () => onRemove(i),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionField(_BomLineDraft line) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: line.description,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: line.itemId.text.trim().isEmpty
              ? 'Section / description'
              : line.itemId.text.trim(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 13,
          ),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }

  Widget _field(TextEditingController controller, {bool number = false}) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 13),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }

  Widget _header(String label) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: zText,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _text(String value) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: zText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
