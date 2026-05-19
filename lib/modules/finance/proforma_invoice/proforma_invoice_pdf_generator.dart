import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'proforma_screen.dart';

// =========================================================
// 1. PROFORMA PREVIEW SCREEN
// =========================================================
class ProformaPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<ProformaLocalItem> items;

  const ProformaPreviewScreen({
    super.key,
    required this.data,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = '${data['proformaNumber'] ?? 'Proforma_Invoice'}.pdf'
        .replaceAll('/', '_')
        .replaceAll(' ', '_');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proforma Invoice Preview'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PdfPreview(
        build: (format) => generateProformaPdf(data, items),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: fileName,
        previewPageMargin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(0),
      ),
    );
  }
}

// =========================================================
// 2. PDF GENERATOR LOGIC
// =========================================================
Future<Uint8List> generateProformaPdf(
  Map<String, dynamic> data,
  List<ProformaLocalItem> items,
) async {
  debugPrint("Quotation Number (FINAL): ${data['quotationNumber']}");

  final pdf = pw.Document();

  pw.ImageProvider? logoImage;
  final String logoUrl = data['companyLogoUrl']?.toString() ?? '';
  if (logoUrl.isNotEmpty) {
    try {
      logoImage = await networkImage(logoUrl);
    } catch (e) {
      logoImage = null;
    }
  }

  String safeStr(dynamic val) => val?.toString().trim() ?? '';
  double safeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  final bool isInterState = data['isInterState'] == true;
  final String inquiryNumber = safeStr(data['inquiryNumber']);
  final String quotationNumber = safeStr(data['quotationNumber']);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          // ==============================
          // HEADER SECTION
          // ==============================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        height: 50,
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Image(logoImage),
                      ),
                    pw.Text(
                      safeStr(data['companyName']).toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      safeStr(data['companyAddress']),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (safeStr(data['companyGst']).isNotEmpty)
                      pw.Text(
                        'GSTIN: ${data['companyGst']}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    if (safeStr(data['companyPan']).isNotEmpty)
                      pw.Text(
                        'PAN: ${data['companyPan']}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (safeStr(data['companyPhone']).isNotEmpty)
                      pw.Text(
                        'Phone: ${data['companyPhone']}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (safeStr(data['companyEmail']).isNotEmpty)
                      pw.Text(
                        'Email: ${data['companyEmail']}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PROFORMA INVOICE',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfRow(
                            'PI Number:',
                            safeStr(data['proformaNumber']),
                          ),
                          pw.SizedBox(height: 4),
                          _buildPdfRow(
                            'Date:',
                            safeStr(data['proformaDateStr']),
                          ),
                          if (inquiryNumber.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            _buildPdfRow('Inquiry Ref:', inquiryNumber),
                          ],
                          if (quotationNumber.isNotEmpty &&
                              quotationNumber !=
                                  safeStr(data['proformaNumber'])) ...[
                            pw.SizedBox(height: 4),
                            _buildPdfRow('Quotation No:', quotationNumber),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),

          // ==============================
          // PARTY DETAILS (BILL TO / SHIP TO)
          // ==============================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BILL TO:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      safeStr(data['clientName']),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      safeStr(data['clientAddress']),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (safeStr(data['customerState']).isNotEmpty)
                      pw.Text(
                        'State: ${data['customerState']}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (safeStr(data['gstNo']).isNotEmpty)
                      pw.Text(
                        'GSTIN: ${data['gstNo']}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    if (safeStr(data['contactPerson']).isNotEmpty ||
                        safeStr(data['clientMobile']).isNotEmpty)
                      pw.Text(
                        'Contact: ${safeStr(data['contactPerson'])} ${safeStr(data['clientMobile']).isNotEmpty ? '(${data['clientMobile']})' : ''}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SHIP TO:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      safeStr(data['shippingName']),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      safeStr(data['shippingAddress']),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (safeStr(data['shippingState']).isNotEmpty)
                      pw.Text(
                        'State: ${data['shippingState']}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (safeStr(data['shippingGst']).isNotEmpty)
                      pw.Text(
                        'GSTIN: ${data['shippingGst']}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    if (safeStr(data['shippingContactPerson']).isNotEmpty ||
                        safeStr(data['shippingMobile']).isNotEmpty)
                      pw.Text(
                        'Contact: ${safeStr(data['shippingContactPerson'])} ${safeStr(data['shippingMobile']).isNotEmpty ? '(${data['shippingMobile']})' : ''}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ==============================
          // LINE ITEMS TABLE
          // ==============================
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 4,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headers: [
              'Sn',
              'Item & Description',
              'HSN',
              'Qty',
              'UOM',
              'Rate',
              'Disc%',
              'Tax%',
              'Total',
            ],
            data: List.generate(items.length, (index) {
              final item = items[index];
              final double totalTaxPct =
                  item.cgstPercent + item.sgstPercent + item.igstPercent;
              return [
                (index + 1).toString(),
                '${item.name}${item.description.isNotEmpty ? '\n${item.description}' : ''}',
                item.hsnCode,
                item.quantity.toStringAsFixed(2),
                item.uom,
                item.unitPrice.toStringAsFixed(2),
                item.discountPercent.toStringAsFixed(2),
                totalTaxPct.toStringAsFixed(2),
                item.totalAmount.toStringAsFixed(2),
              ];
            }),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(45),
              3: const pw.FixedColumnWidth(35),
              4: const pw.FixedColumnWidth(30),
              5: const pw.FixedColumnWidth(50),
              6: const pw.FixedColumnWidth(35),
              7: const pw.FixedColumnWidth(35),
              8: const pw.FixedColumnWidth(65),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
            },
          ),

          pw.SizedBox(height: 15),

          // ==============================
          // TOTALS & TERMS SUMMARY
          // ==============================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildBankDetails(data['bankDetails'] ?? {}),
                    pw.SizedBox(height: 15),
                    _buildDynamicTerms(data['dynamicTerms'] ?? []),
                  ],
                ),
              ),
              pw.SizedBox(width: 15),
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Column(
                    children: [
                      _buildSummaryRow(
                        'Subtotal',
                        safeDouble(data['totalSubtotal']),
                      ),
                      if (safeDouble(data['totalItemDiscount']) > 0)
                        _buildSummaryRow(
                          'Item Discounts',
                          -safeDouble(data['totalItemDiscount']),
                          color: PdfColors.red800,
                        ),
                      if (safeDouble(data['globalDiscountAmount']) > 0)
                        _buildSummaryRow(
                          'Global Discount',
                          -safeDouble(data['globalDiscountAmount']),
                          color: PdfColors.red800,
                        ),

                      pw.Divider(color: PdfColors.blue200),
                      _buildSummaryRow(
                        'Taxable Amount',
                        safeDouble(data['totalTaxableAmount']),
                        bold: true,
                      ),

                      if (!isInterState) ...[
                        _buildSummaryRow('CGST', safeDouble(data['totalCgst'])),
                        _buildSummaryRow('SGST', safeDouble(data['totalSgst'])),
                      ] else ...[
                        _buildSummaryRow('IGST', safeDouble(data['totalIgst'])),
                      ],

                      if (safeDouble(data['roundOff']) != 0)
                        _buildSummaryRow(
                          'Round Off',
                          safeDouble(data['roundOff']),
                        ),

                      pw.Divider(color: PdfColors.blue900, thickness: 1.5),
                      _buildSummaryRow(
                        'GRAND TOTAL',
                        safeDouble(data['finalTotal']),
                        bold: true,
                        size: 14,
                      ),

                      if (safeDouble(data['advanceAmount']) > 0) ...[
                        pw.SizedBox(height: 8),
                        pw.Divider(
                          color: PdfColors.grey400,
                          borderStyle: pw.BorderStyle.dashed,
                        ),
                        _buildSummaryRow(
                          'Advance (${safeStr(data['advancePercent'])}%)',
                          safeDouble(data['advanceAmount']),
                          color: PdfColors.green800,
                          bold: true,
                        ),
                        _buildSummaryRow(
                          'Balance (${safeStr(data['balancePercent'])}%)',
                          safeDouble(data['balanceAmount']),
                          bold: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 40),

          // ==============================
          // SIGNATURE SECTION
          // ==============================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'For ${safeStr(data['companyName'])}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(
                    safeStr(data['signatureName']),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (safeStr(data['signatureDesignation']).isNotEmpty)
                    pw.Text(
                      safeStr(data['signatureDesignation']),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (safeStr(data['signaturePhone']).isNotEmpty)
                    pw.Text(
                      safeStr(data['signaturePhone']),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                ],
              ),
            ],
          ),
        ];
      },
    ),
  );

  return pdf.save();
}

// ---------------------------------------------------------
// COMPONENT BUILDERS FOR PDF
// ---------------------------------------------------------

pw.Widget _buildPdfRow(String label, String value) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(width: 8),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}

pw.Widget _buildSummaryRow(
  String label,
  double amount, {
  bool bold = false,
  double size = 10,
  PdfColor? color,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
        pw.Text(
          amount.toStringAsFixed(2),
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildBankDetails(Map<String, dynamic> bank) {
  final String accountName = bank['accountHolderName']?.toString().trim() ?? '';
  final String bankName = bank['bankName']?.toString().trim() ?? '';
  final String accountNo = bank['accountNumber']?.toString().trim() ?? '';
  final String ifsc = bank['ifsc']?.toString().trim() ?? '';
  final String branch = bank['branch']?.toString().trim() ?? '';
  final String branchAddress = bank['branchAddress']?.toString().trim() ?? '';
  final String micr = bank['micr']?.toString().trim() ?? '';
  final String swift = bank['swift']?.toString().trim() ?? '';

  if (accountName.isEmpty &&
      bankName.isEmpty &&
      accountNo.isEmpty &&
      ifsc.isEmpty) {
    return pw.SizedBox();
  }

  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bank Details',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.Divider(color: PdfColors.grey300),
        if (accountName.isNotEmpty) _buildPdfRow('Account Name:', accountName),
        if (bankName.isNotEmpty) _buildPdfRow('Bank Name:', bankName),
        if (branch.isNotEmpty) _buildPdfRow('Branch:', branch),
        if (branchAddress.isNotEmpty)
          _buildPdfRow('Branch Address:', branchAddress),
        if (accountNo.isNotEmpty) _buildPdfRow('Account No:', accountNo),
        if (ifsc.isNotEmpty) _buildPdfRow('IFSC / RTGS Code:', ifsc),
        if (micr.isNotEmpty) _buildPdfRow('MICR Code:', micr),
        if (swift.isNotEmpty) _buildPdfRow('SWIFT Code:', swift),
      ],
    ),
  );
}

pw.Widget _buildDynamicTerms(List<dynamic> terms) {
  if (terms.isEmpty) return pw.SizedBox();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Terms & Conditions',
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.SizedBox(height: 4),
      ...terms.map((t) {
        final title = t['title']?.toString().trim() ?? '';
        final val = t['value']?.toString().trim() ?? '';
        if (title.isEmpty && val.isEmpty) return pw.SizedBox();
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
              children: [
                if (title.isNotEmpty)
                  pw.TextSpan(
                    text: '$title: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                pw.TextSpan(text: val),
              ],
            ),
          ),
        );
      }),
    ],
  );
}
