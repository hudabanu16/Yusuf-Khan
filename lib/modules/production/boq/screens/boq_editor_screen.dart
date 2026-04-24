import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/production/boq/models/boq_item_model.dart';
import 'package:QUIK/modules/production/boq/models/boq_model.dart';
import 'package:QUIK/modules/production/boq/repositories/boq_repository.dart';
import 'package:QUIK/modules/production/boq/services/boq_pdf_service.dart';

class BoqEditorScreen extends StatefulWidget {
  final String tenantId;
  final BoqModel? boq;

  const BoqEditorScreen({super.key, required this.tenantId, this.boq});

  @override
  State<BoqEditorScreen> createState() => _BoqEditorScreenState();
}

class _BoqEditorScreenState extends State<BoqEditorScreen> {
  static const double _gridWidth = 1688;

  final _formKey = GlobalKey<FormState>();
  late final BoqRepository _repository;
  late final String _boqId;

  final _boqNo = TextEditingController();
  final _clientName = TextEditingController();
  final _epcContractor = TextEditingController();
  final _projectName = TextEditingController();
  final _moduleType = TextEditingController();
  final _moduleWattPeak = TextEditingController();
  final _pileDepthConsidered = TextEditingController();
  final _groundClearance = TextEditingController();
  final _dcCapacity = TextEditingController();
  final _tiltAngle = TextEditingController();

  final List<_ModuleQuantityDraft> _moduleQuantities = [
    _ModuleQuantityDraft(label: '2PX26'),
    _ModuleQuantityDraft(label: '2PX13'),
    _ModuleQuantityDraft(label: '2PX7'),
  ];
  final List<_BoqLineDraft> _lines = [];
  final _tableHorizontalController = ScrollController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = BoqRepository(tenantId: widget.tenantId);
    _boqId = widget.boq?.boqId ?? _repository.newBoqId();
    _hydrateHeader();
    _loadLines();
  }

  void _hydrateHeader() {
    final boq = widget.boq;
    _boqNo.text = boq?.boqNo ?? 'BOQ-${DateTime.now().millisecondsSinceEpoch}';
    _clientName.text = boq?.clientName ?? '';
    _epcContractor.text = boq?.epcContractor ?? '';
    _projectName.text = boq?.projectName ?? '';
    _moduleType.text = boq?.moduleType ?? '';
    _moduleWattPeak.text = _textNum(boq?.moduleWattPeak ?? 0);
    _pileDepthConsidered.text = _textNum(boq?.pileDepthConsidered ?? 0);
    _groundClearance.text = _textNum(boq?.groundClearance ?? 0);
    final dcCapacity = boq == null || boq.dcCapacity == 0
        ? boq?.capacityKW ?? 0
        : boq.dcCapacity;
    _dcCapacity.text = _textNum(dcCapacity);
    _tiltAngle.text = _textNum(boq?.tiltAngle ?? 0);
    _hydrateModuleQuantities(boq?.moduleQuantities ?? const []);
  }

  void _hydrateModuleQuantities(List<BoqModuleQuantityModel> quantities) {
    for (final draft in _moduleQuantities) {
      final matches = quantities.where((item) => item.label == draft.label);
      if (matches.isNotEmpty) {
        draft.quantity.text = _textNum(matches.first.quantity);
      }
    }
  }

  Future<void> _loadLines() async {
    if (widget.boq == null) {
      _lines.add(_BoqLineDraft());
      setState(() => _loading = false);
      return;
    }

    final lines = await _repository.fetchBoqItems(_boqId);
    _lines
      ..clear()
      ..addAll(lines.map(_BoqLineDraft.fromModel));
    if (_lines.isEmpty) _lines.add(_BoqLineDraft());
    if (mounted) setState(() => _loading = false);
  }

  double get _totalWeight {
    return _lines.fold(0, (total, line) => total + line.totalWeight);
  }

  double get _totalWeightWithFinish {
    return _lines.fold(0, (total, line) => total + line.totalWeightWithFinish);
  }

  double get _tonsPerMwp {
    final dcCapacity = double.tryParse(_dcCapacity.text.trim()) ?? 0;
    return dcCapacity == 0 ? 0 : _totalWeightWithFinish / dcCapacity;
  }

  void _addLine() {
    setState(() => _lines.add(_BoqLineDraft()));
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    setState(() => _lines.removeAt(index).dispose());
  }

  Future<void> _loadDemoBoq() async {
    final hasUserData =
        _clientName.text.trim().isNotEmpty ||
        _epcContractor.text.trim().isNotEmpty ||
        _projectName.text.trim().isNotEmpty ||
        _lines.any((line) => !line.isBlank);

    if (hasUserData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Load demo BOQ?'),
          content: const Text(
            'This will replace the current unsaved BOQ values on this screen.',
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
      _boqNo.text = 'BOQ-DEMO-MMS';
      _clientName.text = 'Demo Solar Fabrication Client';
      _epcContractor.text = 'VIRAT ENGINEERING SYSTEMS';
      _projectName.text = 'MMS Demo Project';
      _moduleType.text = 'GOLDI';
      _moduleWattPeak.text = '610';
      _pileDepthConsidered.text = '1350';
      _groundClearance.text = '600';
      _dcCapacity.text = '2408.28';
      _tiltAngle.text = '20';
      _moduleQuantities[0].quantity.text = '58';
      _moduleQuantities[1].quantity.text = '26';
      _moduleQuantities[2].quantity.text = '20';
      _lines
        ..clear()
        ..addAll(_DemoBoqData.lines.map(_BoqLineDraft.demo));
    });
  }

  Future<void> _printPdf() async {
    final boq = _buildBoqModel();
    final items = _buildLineModels();
    await Printing.layoutPdf(
      name: '${boq.boqNo}_module_mounting_structure_boq.pdf',
      onLayout: (_) => BoqPdfService.buildBoqPdf(boq: boq, items: items),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('BOQ save blocked: form validation failed');
      _showSnack(
        'Please fill required BOQ fields before saving',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final boq = _buildBoqModel();
      final lineModels = _buildLineModels();

      debugPrint(
        'Saving BOQ ${boq.boqId} for tenant ${widget.tenantId} with ${lineModels.length} lines',
      );

      await _repository.saveBoq(boq);
      await _repository.replaceBoqItems(boqId: _boqId, items: lineModels);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('BOQ save Firebase error code: ${e.code}');
      debugPrint('BOQ save Firebase error message: ${e.message}');
      debugPrint('BOQ save Firebase stack: $stackTrace');
      if (!mounted) return;
      _showSnack(
        'Failed to save BOQ: ${e.code}${e.message == null ? '' : ' - ${e.message}'}',
        isError: true,
      );
    } catch (e) {
      debugPrint('BOQ save error: $e');
      if (!mounted) return;
      _showSnack('Failed to save BOQ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : zSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  BoqModel _buildBoqModel() {
    return BoqModel(
      boqId: _boqId,
      boqNo: _boqNo.text.trim(),
      clientName: _clientName.text.trim(),
      epcContractor: _epcContractor.text.trim(),
      projectName: _projectName.text.trim(),
      moduleType: _moduleType.text.trim(),
      moduleWattPeak: double.tryParse(_moduleWattPeak.text.trim()) ?? 0,
      pileDepthConsidered:
          double.tryParse(_pileDepthConsidered.text.trim()) ?? 0,
      groundClearance: double.tryParse(_groundClearance.text.trim()) ?? 0,
      dcCapacity: double.tryParse(_dcCapacity.text.trim()) ?? 0,
      moduleQuantities: _moduleQuantities
          .map(
            (moduleQuantity) => BoqModuleQuantityModel(
              label: moduleQuantity.label,
              quantity:
                  double.tryParse(moduleQuantity.quantity.text.trim()) ?? 0,
              uom: 'Nos',
            ),
          )
          .toList(growable: false),
      capacityKW: double.tryParse(_dcCapacity.text.trim()) ?? 0,
      tiltAngle: double.tryParse(_tiltAngle.text.trim()) ?? 0,
      totalWeight: _totalWeight,
      totalWeightInclFinish: _totalWeightWithFinish,
      status: widget.boq?.status ?? 'draft',
    );
  }

  List<BoqItemModel> _buildLineModels() {
    final lineModels = <BoqItemModel>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.isBlank) continue;
      lineModels.add(
        BoqItemModel(
          itemId: line.itemId ?? _repository.newBoqItemId(_boqId),
          lineNo: i + 1,
          description: line.description.text.trim(),
          section: line.section.text.trim(),
          gradeOfSteel: line.gradeOfSteel.text.trim(),
          finish: line.finish.text.trim(),
          coatingThickness: line.coatingThickness.text.trim(),
          length: line.lengthValue,
          quantity: line.quantityValue,
          unitWeight: line.unitWeightValue,
          componentWeight: line.componentWeight,
          totalWeight: line.totalWeight,
          totalWeightWithFinish: line.totalWeightWithFinish,
        ),
      );
    }
    return lineModels;
  }

  @override
  void dispose() {
    _boqNo.dispose();
    _clientName.dispose();
    _epcContractor.dispose();
    _projectName.dispose();
    _moduleType.dispose();
    _moduleWattPeak.dispose();
    _pileDepthConsidered.dispose();
    _groundClearance.dispose();
    _dcCapacity.dispose();
    _tiltAngle.dispose();
    for (final moduleQuantity in _moduleQuantities) {
      moduleQuantity.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    _tableHorizontalController.dispose();
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
        title: Text(widget.boq == null ? 'Create BOQ' : 'Edit BOQ'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _loadDemoBoq,
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
              final compact = constraints.maxWidth < 780;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSheetHeader(compact: compact),
                  const SizedBox(height: 12),
                  if (compact)
                    _buildMobileLines()
                  else
                    _desktopSheet(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEditableGrid(),
                          const SizedBox(height: 12),
                          _buildSummaryBlock(compact: false),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (compact) _buildSummaryBlock(compact: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader({required bool compact}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            alignment: Alignment.center,
            color: const Color(0xFFF8ECE4),
            child: const Text(
              'MODULE MOUNTING STRUCTURE BOQ',
              style: TextStyle(
                color: zText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          if (compact) ...[
            _headerRow('Client Name', _clientName, fill: _BoqColors.yellow),
            _headerRow(
              'EPC Contractor',
              _epcContractor,
              fill: _BoqColors.beige,
            ),
            _headerRow('Module', _moduleType, valueFill: _BoqColors.blue),
            _headerRow(
              'Module Wp',
              _moduleWattPeak,
              valueFill: _BoqColors.blue,
            ),
            for (final moduleQuantity in _moduleQuantities)
              _moduleQuantityHeaderRow(moduleQuantity),
            _headerRow(
              'Pile Depth Considered (MM)',
              _pileDepthConsidered,
              valueFill: _BoqColors.blue,
              number: true,
            ),
            _headerRow('Ground Clearance (MM)', _groundClearance, number: true),
            _headerRow(
              'DC Capacity As per Table Considered (KWp)',
              _dcCapacity,
              fill: _BoqColors.green,
              number: true,
            ),
            _headerRow(
              'Tilt Angle',
              _tiltAngle,
              fill: _BoqColors.lavender,
              number: true,
            ),
            _headerRow('Project Name', _projectName),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _headerRow(
                        'Client Name',
                        _clientName,
                        fill: _BoqColors.yellow,
                      ),
                      _headerRow(
                        'EPC Contractor',
                        _epcContractor,
                        fill: _BoqColors.beige,
                      ),
                      _tripleHeaderRow(
                        'Pile Depth Considered',
                        _pileDepthConsidered,
                        'Ground Clearance',
                        _groundClearance,
                      ),
                      _headerRow(
                        'DC Capacity As per Table Considered',
                        _dcCapacity,
                        fill: _BoqColors.green,
                        suffix: ' KWp',
                        number: true,
                      ),
                      _headerRow(
                        'Tilt Angle',
                        _tiltAngle,
                        fill: _BoqColors.lavender,
                        number: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _headerRow(
                        'Module',
                        _moduleType,
                        valueFill: _BoqColors.blue,
                      ),
                      _headerRow(
                        'Module Wp',
                        _moduleWattPeak,
                        valueFill: _BoqColors.blue,
                        suffix: ' Wp',
                        number: true,
                      ),
                      for (final moduleQuantity in _moduleQuantities)
                        _moduleQuantityHeaderRow(moduleQuantity),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerRow(
    String label,
    TextEditingController controller, {
    Color fill = Colors.white,
    Color? valueFill,
    String suffix = '',
    bool number = false,
  }) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(flex: 2, child: _headerLabel(label, fill)),
          Expanded(
            flex: 6,
            child: _sheetField(
              controller,
              fill: valueFill ?? fill,
              suffix: suffix,
              number: number,
              required: label == 'Client Name',
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripleHeaderRow(
    String labelA,
    TextEditingController controllerA,
    String labelB,
    TextEditingController controllerB,
  ) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(flex: 2, child: _headerLabel(labelA, Colors.white)),
          Expanded(
            flex: 3,
            child: _sheetField(
              controllerA,
              fill: _BoqColors.blue,
              suffix: ' MM',
              number: true,
            ),
          ),
          Expanded(flex: 2, child: _headerLabel(labelB, Colors.white)),
          Expanded(
            child: _sheetField(controllerB, suffix: ' MM', number: true),
          ),
        ],
      ),
    );
  }

  Widget _moduleQuantityHeaderRow(_ModuleQuantityDraft moduleQuantity) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _headerLabel(moduleQuantity.label, Colors.white),
          ),
          Expanded(
            flex: 6,
            child: _sheetField(
              moduleQuantity.quantity,
              fill: _BoqColors.blue,
              suffix: ' Nos',
              number: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerLabel(String label, Color fill) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: Colors.black54),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController controller, {
    Color fill = Colors.white,
    String suffix = '',
    bool number = false,
    bool required = false,
  }) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: Colors.black54),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          suffixText: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        validator: required
            ? (value) => (value ?? '').trim().isEmpty ? 'Required' : null
            : null,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildEditableGrid() {
    return Container(
      width: _gridWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 1.1),
      ),
      child: Table(
        border: const TableBorder(
          horizontalInside: BorderSide(color: Colors.black87),
          verticalInside: BorderSide(color: Colors.black87),
        ),
        columnWidths: const {
          0: FixedColumnWidth(62),
          1: FixedColumnWidth(210),
          2: FixedColumnWidth(190),
          3: FixedColumnWidth(112),
          4: FixedColumnWidth(112),
          5: FixedColumnWidth(130),
          6: FixedColumnWidth(150),
          7: FixedColumnWidth(104),
          8: FixedColumnWidth(112),
          9: FixedColumnWidth(142),
          10: FixedColumnWidth(136),
          11: FixedColumnWidth(176),
          12: FixedColumnWidth(52),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [
              _tableHeader('Sr. No'),
              _tableHeader('Description'),
              _tableHeader('Sectional Details'),
              _tableHeader('Total Qty'),
              _tableHeader('Grade of Steel'),
              _tableHeader('Finish'),
              _tableHeader('Coating Thickness'),
              _tableHeader('Length (m)'),
              _tableHeader('Unit Wt (Kg/m)'),
              _tableHeader('Component wt. (kg)'),
              _tableHeader('Total Wt (Kg)'),
              _tableHeader('Total Wt Incl. Finish (Kg)'),
              _tableHeader(''),
            ],
          ),
          for (var i = 0; i < _lines.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
              ),
              children: [
                _tableText('${i + 1}'),
                _tableField(_lines[i].description),
                _tableField(_lines[i].section),
                _tableField(_lines[i].quantity, number: true),
                _tableField(_lines[i].gradeOfSteel),
                _tableField(_lines[i].finish),
                _tableField(_lines[i].coatingThickness),
                _tableField(_lines[i].length, number: true),
                _tableField(_lines[i].unitWeight, number: true),
                _tableText(_num(_lines[i].componentWeight)),
                _tableText(_num(_lines[i].totalWeight)),
                _tableField(
                  _lines[i].totalWeightWithFinishOverride,
                  number: true,
                  hint: _num(_lines[i].totalWeight),
                ),
                SizedBox(
                  height: 46,
                  child: IconButton(
                    tooltip: 'Remove line',
                    onPressed: () => _removeLine(i),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLines() {
    return Column(
      children: [
        for (var i = 0; i < _lines.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: zBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Line ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _removeLine(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _mobileField(_lines[i].description, 'Description', 260),
                    _mobileField(_lines[i].section, 'Sectional Details', 220),
                    _mobileField(
                      _lines[i].quantity,
                      'Total Quantity',
                      150,
                      number: true,
                    ),
                    _mobileField(_lines[i].gradeOfSteel, 'Grade of Steel', 150),
                    _mobileField(_lines[i].finish, 'Finish', 150),
                    _mobileField(
                      _lines[i].coatingThickness,
                      'Coating Thickness',
                      180,
                    ),
                    _mobileField(
                      _lines[i].length,
                      'Length (m)',
                      130,
                      number: true,
                    ),
                    _mobileField(
                      _lines[i].unitWeight,
                      'Unit Wt (Kg/m)',
                      160,
                      number: true,
                    ),
                    _readOnlyMobile(
                      'Component wt. (kg)',
                      _lines[i].componentWeight,
                    ),
                    _readOnlyMobile('Total Wt (Kg)', _lines[i].totalWeight),
                    _mobileField(
                      _lines[i].totalWeightWithFinishOverride,
                      'Total Wt Incl. Finish',
                      190,
                      number: true,
                      hint: _num(_lines[i].totalWeight),
                    ),
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

  Widget _buildSummaryBlock({required bool compact}) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add),
            label: const Text('Add Line'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: compact ? null : _gridWidth,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                color: _BoqColors.yellow,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Weight of Module Mounting Structure',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${_num(_totalWeight)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      '${_num(_totalWeightWithFinish)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFFE1F0F3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Weight of Module Mounting Structure (Considering ${_moduleWattPeak.text.trim().isEmpty ? '0' : _moduleWattPeak.text.trim()}Wp Panel)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${_num(_tonsPerMwp)} Ton/MWp',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Container(
      height: 50,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _tableField(
    TextEditingController controller, {
    bool number = false,
    String? hint,
  }) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 14,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _tableText(String text) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _desktopSheet({required Widget child}) {
    return Scrollbar(
      controller: _tableHorizontalController,
      thumbVisibility: true,
      notificationPredicate: (notification) => notification.depth == 0,
      child: SingleChildScrollView(
        controller: _tableHorizontalController,
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: child,
        ),
      ),
    );
  }

  Widget _mobileField(
    TextEditingController controller,
    String label,
    double width, {
    bool number = false,
    String? hint,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _readOnlyMobile(String label, double value) {
    return SizedBox(
      width: 170,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          _num(value),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  String _textNum(double value) {
    return value == 0 ? '' : '$value';
  }

  String _num(double value) => value.toStringAsFixed(2);
}

class _BoqLineDraft {
  String? itemId;
  final description = TextEditingController();
  final section = TextEditingController();
  final quantity = TextEditingController();
  final gradeOfSteel = TextEditingController();
  final finish = TextEditingController();
  final coatingThickness = TextEditingController();
  final length = TextEditingController();
  final unitWeight = TextEditingController();
  final totalWeightWithFinishOverride = TextEditingController();

  _BoqLineDraft();

  _BoqLineDraft.demo(_DemoBoqLine line) {
    description.text = line.description;
    section.text = line.section;
    quantity.text = _formatDemoNumber(line.quantity);
    gradeOfSteel.text = line.gradeOfSteel;
    finish.text = line.finish;
    coatingThickness.text = line.coatingThickness;
    length.text = _formatDemoNumber(line.length, decimals: 3);
    unitWeight.text = _formatDemoNumber(line.unitWeight);
    totalWeightWithFinishOverride.text = _formatDemoNumber(
      line.totalWeightWithFinish,
    );
  }

  _BoqLineDraft.fromModel(BoqItemModel model) {
    itemId = model.itemId;
    description.text = model.description;
    section.text = model.section;
    quantity.text = '${model.quantity}';
    gradeOfSteel.text = model.gradeOfSteel;
    finish.text = model.finish;
    coatingThickness.text = model.coatingThickness;
    length.text = '${model.length}';
    unitWeight.text = '${model.unitWeight}';
    final finishTotal = model.totalWeightWithFinish == 0
        ? model.calculatedTotalWeight
        : model.totalWeightWithFinish;
    totalWeightWithFinishOverride.text = '$finishTotal';
  }

  bool get isBlank {
    return description.text.trim().isEmpty &&
        section.text.trim().isEmpty &&
        quantity.text.trim().isEmpty &&
        length.text.trim().isEmpty &&
        unitWeight.text.trim().isEmpty;
  }

  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get lengthValue => double.tryParse(length.text.trim()) ?? 0;
  double get unitWeightValue => double.tryParse(unitWeight.text.trim()) ?? 0;
  double get componentWeight => lengthValue * unitWeightValue;
  double get totalWeight => componentWeight * quantityValue;
  double get totalWeightWithFinish {
    final entered = double.tryParse(totalWeightWithFinishOverride.text.trim());
    return entered == null || entered == 0 ? totalWeight : entered;
  }

  void dispose() {
    description.dispose();
    section.dispose();
    quantity.dispose();
    gradeOfSteel.dispose();
    finish.dispose();
    coatingThickness.dispose();
    length.dispose();
    unitWeight.dispose();
    totalWeightWithFinishOverride.dispose();
  }
}

class _ModuleQuantityDraft {
  final String label;
  final quantity = TextEditingController();

  _ModuleQuantityDraft({required this.label});

  void dispose() {
    quantity.dispose();
  }
}

class _BoqColors {
  static const yellow = Color(0xFFFFFF00);
  static const blue = Color(0xFF9DBFE3);
  static const beige = Color(0xFFF7ECE4);
  static const green = Color(0xFFEAF2E3);
  static const lavender = Color(0xFFE9E5F3);
}

class _DemoBoqLine {
  final String description;
  final String section;
  final double quantity;
  final String gradeOfSteel;
  final String finish;
  final String coatingThickness;
  final double length;
  final double unitWeight;
  final double totalWeightWithFinish;

  const _DemoBoqLine({
    required this.description,
    required this.section,
    required this.quantity,
    required this.gradeOfSteel,
    required this.finish,
    required this.coatingThickness,
    required this.length,
    required this.unitWeight,
    required this.totalWeightWithFinish,
  });
}

class _DemoBoqData {
  static const lines = [
    _DemoBoqLine(
      description: 'COLUMN',
      section: '150CS80X20X2.5',
      quantity: 874,
      gradeOfSteel: '350Mpa',
      finish: 'GAL (HDG)',
      coatingThickness: 'Min 80 MIC',
      length: 2.165,
      unitWeight: 6.48,
      totalWeightWithFinish: 13114.66,
    ),
    _DemoBoqLine(
      description: 'LOWER COLUMN',
      section: '80CU40X2',
      quantity: 874,
      gradeOfSteel: '250Mpa',
      finish: 'MS BLACK',
      coatingThickness: '-',
      length: 0.670,
      unitWeight: 2.39,
      totalWeightWithFinish: 1397.43,
    ),
    _DemoBoqLine(
      description: 'RAFTER',
      section: '100CS50X15X1.6',
      quantity: 874,
      gradeOfSteel: '550Mpa',
      finish: 'Galvalume',
      coatingThickness: 'AZ 150',
      length: 3.970,
      unitWeight: 2.73,
      totalWeightWithFinish: 9465.67,
    ),
    _DemoBoqLine(
      description: 'PURLIN',
      section: '70HU40X22X10X1.2',
      quantity: 464,
      gradeOfSteel: '550Mpa',
      finish: 'Galvalume',
      coatingThickness: 'AZ 150',
      length: 6.535,
      unitWeight: 2.29,
      totalWeightWithFinish: 6958.38,
    ),
    _DemoBoqLine(
      description: 'FRONT BRACING',
      section: '70CS40X15X1.6',
      quantity: 874,
      gradeOfSteel: '550Mpa',
      finish: 'Galvalume',
      coatingThickness: 'AZ 150',
      length: 2.188,
      unitWeight: 2.10,
      totalWeightWithFinish: 4015.55,
    ),
    _DemoBoqLine(
      description: 'BACK BRACING',
      section: '70CS40X15X1.6',
      quantity: 874,
      gradeOfSteel: '550Mpa',
      finish: 'Galvalume',
      coatingThickness: 'AZ 150',
      length: 1.736,
      unitWeight: 2.10,
      totalWeightWithFinish: 3186.12,
    ),
    _DemoBoqLine(
      description: 'CONNECTION CHANNEL',
      section: '70CS40X15X1.6',
      quantity: 1748,
      gradeOfSteel: '550Mpa',
      finish: 'Galvalume',
      coatingThickness: 'AZ 150',
      length: 0.230,
      unitWeight: 2.10,
      totalWeightWithFinish: 844.30,
    ),
  ];
}

String _formatDemoNumber(double value, {int decimals = 2}) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(decimals);
}
