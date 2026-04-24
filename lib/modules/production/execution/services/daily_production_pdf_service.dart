import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:QUIK/modules/production/execution/models/production_entry_model.dart';
import 'package:QUIK/modules/production/execution/models/production_line_model.dart';

class DailyProductionPdfService {
  const DailyProductionPdfService._();

  static Future<Uint8List> buildDailyProductionPdf({
    required ProductionEntryModel entry,
    required List<ProductionLineModel> lines,
  }) async {
    final pdf = pw.Document();
    final totalQuantity = lines.fold<double>(
      0,
      (sum, line) => sum + line.quantity,
    );
    final chunks = <List<ProductionLineModel>>[];
    for (var i = 0; i < lines.length; i += 22) {
      chunks.add(
        lines.sublist(i, i + 22 > lines.length ? lines.length : i + 22),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => [
          _header(entry),
          for (var i = 0; i < chunks.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 10),
            _registerTable(chunks[i]),
          ],
          _totalQuantityRow(totalQuantity),
          pw.SizedBox(height: 10),
          _itemSummary(lines),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _header(ProductionEntryModel entry) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
      child: pw.Column(
        children: [
          pw.Container(
            height: 28,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF6E6C8),
            ),
            child: pw.Text(
              'DAILY PRODUCTION REGISTER',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Row(
            children: [
              _headerCell('Date', _dateLabel(entry.date)),
              _headerCell('Shift', entry.shift),
              _headerCell('Operator', entry.operatorId),
              _headerCell('Work Center', entry.workCenterId),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _registerTable(List<ProductionLineModel> lines) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(width: 0.65, color: PdfColors.blueGrey800),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEFF3F8),
      ),
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey900,
      ),
      cellStyle: const pw.TextStyle(
        fontSize: 7.4,
        color: PdfColors.blueGrey900,
      ),
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      columnWidths: const {
        0: pw.FixedColumnWidth(26),
        1: pw.FixedColumnWidth(90),
        2: pw.FixedColumnWidth(116),
        3: pw.FixedColumnWidth(100),
        4: pw.FixedColumnWidth(56),
        5: pw.FixedColumnWidth(78),
        6: pw.FixedColumnWidth(104),
        7: pw.FixedColumnWidth(54),
        8: pw.FixedColumnWidth(142),
      },
      headers: const [
        'Sr\nNo',
        'Client Name',
        'Item Name',
        'Section',
        'Length\n(mm)',
        'Operation',
        'Hole / Slot Size',
        'Quantity',
        'Remarks',
      ],
      data: [
        for (final line in lines)
          [
            line.lineNo.toString(),
            line.clientName,
            line.description,
            line.section,
            _num(line.length, decimals: 0),
            line.operationType,
            line.holeSize,
            _num(line.quantity, decimals: 0),
            line.remarks,
          ],
      ],
    );
  }

  static pw.Widget _totalQuantityRow(double totalQuantity) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.65)),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 8,
            child: pw.Container(
              height: 24,
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.only(right: 10),
              color: const PdfColor.fromInt(0xFFF6E6C8),
              child: pw.Text(
                'Total Quantity',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Container(
            width: 120,
            height: 24,
            alignment: pw.Alignment.center,
            color: const PdfColor.fromInt(0xFFF6E6C8),
            child: pw.Text(
              '${_num(totalQuantity, decimals: 0)} Nos',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemSummary(List<ProductionLineModel> lines) {
    final totals = <String, double>{};
    for (final line in lines) {
      final key = line.description.trim().isEmpty
          ? 'Unspecified item'
          : line.description.trim();
      totals[key] = (totals[key] ?? 0) + line.quantity;
    }

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: const PdfColor.fromInt(0xFFF6E6C8),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              'Item-wise Quantity Summary',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Wrap(
            children: [
              for (final entry in totals.entries)
                pw.Container(
                  width: 180,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.4),
                  ),
                  child: pw.Text(
                    '${entry.key}: ${_num(entry.value, decimals: 0)} Nos',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _headerCell(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        height: 28,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.55)),
        child: pw.Row(
          children: [
            pw.Text(
              '$label: ',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  static String _num(num value, {int decimals = 2}) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(decimals);
  }
}
