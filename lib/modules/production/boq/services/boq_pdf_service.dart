import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:QUIK/modules/production/boq/models/boq_item_model.dart';
import 'package:QUIK/modules/production/boq/models/boq_model.dart';

class BoqPdfService {
  const BoqPdfService._();

  static Future<Uint8List> buildBoqPdf({
    required BoqModel boq,
    required List<BoqItemModel> items,
  }) async {
    final pdf = pw.Document();
    final totalWeight = items.fold<double>(
      0,
      (sum, item) => sum + item.calculatedTotalWeight,
    );
    final totalWithFinish = items.fold<double>(
      0,
      (sum, item) => sum + _finishTotal(item),
    );
    final dcCapacity = boq.dcCapacity == 0 ? boq.capacityKW : boq.dcCapacity;
    final tonsPerMwp = dcCapacity == 0 ? 0.0 : totalWithFinish / dcCapacity;
    final itemChunks = <List<BoqItemModel>>[];
    for (var i = 0; i < items.length; i += 18) {
      itemChunks.add(
        items.sublist(i, i + 18 > items.length ? items.length : i + 18),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(14),
        build: (context) => [
          _sheetHeader(boq),
          for (var i = 0; i < itemChunks.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 10),
            _itemsTable(itemChunks[i]),
          ],
          _summaryRow(
            totalWeight: totalWeight,
            totalWithFinish: totalWithFinish,
            moduleWattPeak: boq.moduleWattPeak,
            tonsPerMwp: tonsPerMwp,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _itemsTable(List<BoqItemModel> items) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(width: 0.65),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
      headerStyle: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 6.8),
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(24),
        1: pw.FixedColumnWidth(98),
        2: pw.FixedColumnWidth(88),
        3: pw.FixedColumnWidth(44),
        4: pw.FixedColumnWidth(42),
        5: pw.FixedColumnWidth(54),
        6: pw.FixedColumnWidth(58),
        7: pw.FixedColumnWidth(42),
        8: pw.FixedColumnWidth(42),
        9: pw.FixedColumnWidth(58),
        10: pw.FixedColumnWidth(66),
        11: pw.FixedColumnWidth(74),
      },
      headers: const [
        'Sr. No',
        'Description',
        'Sectional Details',
        'Total\nQuantity',
        'Grade of\nSteel',
        'Finish',
        'Coating\nThickness',
        'Length\n(m)',
        'Unit. Wt\n(Kg/m)',
        'Component\nwt. (kg)',
        'Total Wt\n(Kg)',
        'Total Wt Incl.\nFinish (Kg)',
      ],
      data: [
        for (final item in items)
          [
            item.lineNo.toString(),
            item.description,
            item.section,
            _num(item.quantity, decimals: 0),
            item.gradeOfSteel,
            item.finish,
            item.coatingThickness,
            _num(item.length, decimals: 3),
            _num(item.unitWeight),
            _num(item.calculatedComponentWeight),
            _num(item.calculatedTotalWeight),
            _num(_finishTotal(item)),
          ],
      ],
    );
  }

  static pw.Widget _sheetHeader(BoqModel boq) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.9)),
      child: pw.Column(
        children: [
          _cell(
            'MODULE MOUNTING STRUCTURE BOQ',
            color: const PdfColor.fromInt(0xFFF7ECE4),
            bold: true,
            height: 26,
            fontSize: 10,
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  children: [
                    _labelValueRow(
                      'Client Name',
                      boq.clientName,
                      labelColor: PdfColors.yellow,
                      valueColor: PdfColors.yellow,
                    ),
                    _labelValueRow(
                      'EPC Contractor',
                      boq.epcContractor,
                      labelColor: const PdfColor.fromInt(0xFFF7ECE4),
                      valueColor: const PdfColor.fromInt(0xFFF7ECE4),
                    ),
                    _tripleRow(
                      'Pile Depth Considered',
                      '${_num(boq.pileDepthConsidered, decimals: 0)} MM',
                      'Ground Clearance',
                      '${_num(boq.groundClearance, decimals: 0)} MM',
                      valueColor: const PdfColor.fromInt(0xFF9DBFE3),
                    ),
                    _labelValueRow(
                      'DC Capacity As per Table Considered',
                      '${_num(boq.dcCapacity == 0 ? boq.capacityKW : boq.dcCapacity)} KWp',
                      labelColor: const PdfColor.fromInt(0xFFEAF2E3),
                      valueColor: const PdfColor.fromInt(0xFFEAF2E3),
                    ),
                    _labelValueRow(
                      'Tilt Angle',
                      _num(boq.tiltAngle, decimals: 1),
                      labelColor: const PdfColor.fromInt(0xFFE9E5F3),
                      valueColor: const PdfColor.fromInt(0xFFE9E5F3),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  children: [
                    _labelValueRow(
                      'Module',
                      boq.moduleType,
                      valueColor: const PdfColor.fromInt(0xFF9DBFE3),
                    ),
                    _labelValueRow(
                      'Module Wp',
                      '${_num(boq.moduleWattPeak, decimals: 0)} Wp',
                      valueColor: const PdfColor.fromInt(0xFF9DBFE3),
                    ),
                    for (final moduleQuantity in _moduleQuantityRows(boq))
                      _labelValueRow(
                        moduleQuantity.label,
                        '${_num(moduleQuantity.quantity)} ${moduleQuantity.uom}',
                        valueColor: const PdfColor.fromInt(0xFF9DBFE3),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow({
    required double totalWeight,
    required double totalWithFinish,
    required double moduleWattPeak,
    required double tonsPerMwp,
  }) {
    return pw.Column(
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 9,
                child: _cell(
                  'Weight of Module Mounting Structure',
                  color: PdfColors.yellow,
                  bold: true,
                  height: 24,
                ),
              ),
              pw.Expanded(
                child: _cell(
                  '${_num(totalWeight)} kg',
                  color: PdfColors.yellow,
                  bold: true,
                  height: 24,
                ),
              ),
              pw.Expanded(
                child: _cell(
                  '${_num(totalWithFinish)} kg',
                  color: PdfColors.yellow,
                  bold: true,
                  height: 24,
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 10,
                child: _cell(
                  'Weight of Module Mounting Structure (Considering ${_num(moduleWattPeak, decimals: 0)}Wp Panel)',
                  color: const PdfColor.fromInt(0xFFE1F0F3),
                  bold: true,
                  height: 22,
                ),
              ),
              pw.Expanded(
                child: _cell(
                  '${_num(tonsPerMwp)} Ton/MWp',
                  color: const PdfColor.fromInt(0xFFE1F0F3),
                  bold: true,
                  height: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _labelValueRow(
    String label,
    String value, {
    PdfColor labelColor = PdfColors.white,
    PdfColor valueColor = PdfColors.white,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 2,
          child: _cell(label, color: labelColor, bold: true, height: 24),
        ),
        pw.Expanded(
          flex: 6,
          child: _cell(value, color: valueColor, bold: true, height: 24),
        ),
      ],
    );
  }

  static pw.Widget _tripleRow(
    String labelA,
    String valueA,
    String labelB,
    String valueB, {
    PdfColor valueColor = PdfColors.white,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(flex: 2, child: _cell(labelA, bold: true, height: 24)),
        pw.Expanded(
          flex: 3,
          child: _cell(valueA, color: valueColor, bold: true, height: 24),
        ),
        pw.Expanded(flex: 2, child: _cell(labelB, bold: true, height: 24)),
        pw.Expanded(child: _cell(valueB, bold: true, height: 24)),
      ],
    );
  }

  static pw.Widget _cell(
    String value, {
    PdfColor color = PdfColors.white,
    bool bold = false,
    double height = 22,
    double fontSize = 8,
  }) {
    return pw.Container(
      height: height,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: color,
        border: pw.Border.all(width: 0.55),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.center,
        maxLines: 2,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static double _finishTotal(BoqItemModel item) {
    return item.totalWeightWithFinish == 0
        ? item.calculatedTotalWeight
        : item.totalWeightWithFinish;
  }

  static List<BoqModuleQuantityModel> _moduleQuantityRows(BoqModel boq) {
    const labels = ['2PX26', '2PX13', '2PX7'];
    return labels
        .map((label) {
          final matches = boq.moduleQuantities.where(
            (item) => item.label == label,
          );
          if (matches.isNotEmpty) return matches.first;
          return BoqModuleQuantityModel(label: label, quantity: 0);
        })
        .toList(growable: false);
  }

  static String _num(num value, {int decimals = 2}) {
    if (value == 0) return decimals == 0 ? '0' : '0.00';
    return value.toStringAsFixed(decimals);
  }
}
