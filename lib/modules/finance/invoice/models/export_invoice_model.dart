import 'package:cloud_firestore/cloud_firestore.dart';
import 'export_invoice_item.dart';

/// 🔁 REUSABLE PARTY MODEL (DRY)
class Party {
  final String name;
  final String address;
  final String country;
  final String state;
  final String stateCode;
  final String gstin;
  final String pan;
  final String iec;
  final String contactPerson;
  final String email;
  final String phone;

  Party({
    required this.name,
    required this.address,
    required this.country,
    this.state = '',
    this.stateCode = '',
    this.gstin = '',
    this.pan = '',
    this.iec = '',
    this.contactPerson = '',
    this.email = '',
    this.phone = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'country': country,
      'state': state,
      'stateCode': stateCode,
      'gstin': gstin,
      'pan': pan,
      'iec': iec,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
    };
  }

  factory Party.fromMap(Map<String, dynamic> map) {
    return Party(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      country: map['country'] ?? '',
      state: map['state'] ?? '',
      stateCode: map['stateCode'] ?? '',
      gstin: map['gstin'] ?? '',
      pan: map['pan'] ?? '',
      iec: map['iec'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
    );
  }
}

/// 📦 EXPORT DETAILS
class ExportDetails {
  final String exportType;
  final String lutNumber;
  final String lutValidity;
  final String adCode;
  final String portCode;
  final String portOfLoading;
  final String portOfDischarge;
  final String countryOfOrigin;
  final String countryOfDestination;
  final String incoterm;

  ExportDetails({
    required this.exportType,
    this.lutNumber = '',
    this.lutValidity = '',
    this.adCode = '',
    required this.portCode,
    required this.portOfLoading,
    required this.portOfDischarge,
    required this.countryOfOrigin,
    required this.countryOfDestination,
    this.incoterm = 'FOB',
  });

  Map<String, dynamic> toMap() {
    return {
      'exportType': exportType,
      'lutNumber': lutNumber,
      'lutValidity': lutValidity,
      'adCode': adCode,
      'portCode': portCode,
      'portOfLoading': portOfLoading,
      'portOfDischarge': portOfDischarge,
      'countryOfOrigin': countryOfOrigin,
      'countryOfDestination': countryOfDestination,
      'incoterm': incoterm,
    };
  }

  factory ExportDetails.fromMap(Map<String, dynamic> map) {
    return ExportDetails(
      exportType: map['exportType'] ?? 'WITH_LUT',
      lutNumber: map['lutNumber'] ?? '',
      lutValidity: map['lutValidity'] ?? '',
      adCode: map['adCode'] ?? '',
      portCode: map['portCode'] ?? '',
      portOfLoading: map['portOfLoading'] ?? '',
      portOfDischarge: map['portOfDischarge'] ?? '',
      countryOfOrigin: map['countryOfOrigin'] ?? '',
      countryOfDestination: map['countryOfDestination'] ?? '',
      incoterm: map['incoterm'] ?? 'FOB',
    );
  }
}

/// 🚚 LOGISTICS & PACKING
class Logistics {
  final String preCarriageBy;
  final String modeOfTransport;
  final String vesselOrFlight;
  final String shippingBillNo;
  final DateTime? shippingBillDate;
  final String airwayBillNo;
  final String marksAndNos; // ✅ NEW FIELD
  final int numberOfPackages;
  final double grossWeight;
  final double netWeight;

  Logistics({
    this.preCarriageBy = '',
    this.modeOfTransport = '',
    this.vesselOrFlight = '',
    this.shippingBillNo = '',
    this.shippingBillDate,
    this.airwayBillNo = '',
    this.marksAndNos = '', // ✅ NEW FIELD
    this.numberOfPackages = 0,
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'preCarriageBy': preCarriageBy,
      'modeOfTransport': modeOfTransport,
      'vesselOrFlight': vesselOrFlight,
      'shippingBillNo': shippingBillNo,
      'shippingBillDate': shippingBillDate != null ? Timestamp.fromDate(shippingBillDate!) : null,
      'airwayBillNo': airwayBillNo,
      'marksAndNos': marksAndNos, // ✅ Added
      'numberOfPackages': numberOfPackages,
      'grossWeight': grossWeight,
      'netWeight': netWeight,
    };
  }

  factory Logistics.fromMap(Map<String, dynamic> map) {
    return Logistics(
      preCarriageBy: map['preCarriageBy'] ?? '',
      modeOfTransport: map['modeOfTransport'] ?? '',
      vesselOrFlight: map['vesselOrFlight'] ?? '',
      shippingBillNo: map['shippingBillNo'] ?? '',
      shippingBillDate: map['shippingBillDate'] != null ? (map['shippingBillDate'] as Timestamp).toDate() : null,
      airwayBillNo: map['airwayBillNo'] ?? '',
      marksAndNos: map['marksAndNos'] ?? '', // ✅ Added
      numberOfPackages: map['numberOfPackages'] ?? 0,
      grossWeight: (map['grossWeight'] ?? 0).toDouble(),
      netWeight: (map['netWeight'] ?? 0).toDouble(),
    );
  }
}

/// 💰 TAX DETAILS
class TaxDetails {
  final double taxableValue;
  final double igstRate;
  final double igstAmount;
  final bool reverseCharge;

  TaxDetails({
    required this.taxableValue,
    required this.igstRate,
    required this.igstAmount,
    this.reverseCharge = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'taxableValue': taxableValue,
      'igstRate': igstRate,
      'igstAmount': igstAmount,
      'reverseCharge': reverseCharge,
    };
  }

  factory TaxDetails.fromMap(Map<String, dynamic> map) {
    return TaxDetails(
      taxableValue: (map['taxableValue'] ?? 0).toDouble(),
      igstRate: (map['igstRate'] ?? 0).toDouble(),
      igstAmount: (map['igstAmount'] ?? 0).toDouble(),
      reverseCharge: map['reverseCharge'] ?? false,
    );
  }
}

/// 💳 PAYMENT DETAILS & BANK
class PaymentDetails {
  final String paymentMode;
  final String paymentReference;
  final String terms;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String swiftCode;
  final String bankAddress;

  PaymentDetails({
    this.paymentMode = 'Wire Transfer (TT)',
    this.paymentReference = '',
    this.terms = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.swiftCode = '',
    this.bankAddress = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentMode': paymentMode,
      'paymentReference': paymentReference,
      'terms': terms,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifsc': ifsc,
      'swiftCode': swiftCode,
      'bankAddress': bankAddress,
    };
  }

  factory PaymentDetails.fromMap(Map<String, dynamic> map) {
    return PaymentDetails(
      paymentMode: map['paymentMode'] ?? 'Wire Transfer (TT)',
      paymentReference: map['paymentReference'] ?? '',
      terms: map['terms'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      ifsc: map['ifsc'] ?? '',
      swiftCode: map['swiftCode'] ?? '',
      bankAddress: map['bankAddress'] ?? '',
    );
  }
}

/// 📊 TOTALS (INCLUDING INR)
class Totals {
  final double subTotal;
  final double freight;
  final double insurance;
  final double packing;
  final double tax;
  final double grandTotal;
  final double grandTotalInr;

  Totals({
    required this.subTotal,
    this.freight = 0,
    this.insurance = 0,
    this.packing = 0,
    required this.tax,
    required this.grandTotal,
    required this.grandTotalInr,
  });

  Map<String, dynamic> toMap() {
    return {
      'subTotal': subTotal,
      'freight': freight,
      'insurance': insurance,
      'packing': packing,
      'tax': tax,
      'grandTotal': grandTotal,
      'grandTotalInr': grandTotalInr,
    };
  }

  factory Totals.fromMap(Map<String, dynamic> map) {
    return Totals(
      subTotal: (map['subTotal'] ?? 0).toDouble(),
      freight: (map['freight'] ?? 0).toDouble(),
      insurance: (map['insurance'] ?? 0).toDouble(),
      packing: (map['packing'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0).toDouble(),
      grandTotalInr: (map['grandTotalInr'] ?? 0).toDouble(),
    );
  }
}

/// 🧾 MAIN EXPORT INVOICE MODEL
class ExportInvoiceModel {
  final String id;
  final String companyId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String currency;
  final double exchangeRate;
  final String placeOfSupply;
  final String status;
  final String createdBy;

  final Party supplier;
  final Party buyer;
  final Party consignee;

  final ExportDetails exportDetails;
  final Logistics logistics;
  final List<ExportInvoiceItem> items;
  final TaxDetails taxDetails;
  final Totals totals;
  final PaymentDetails paymentDetails;

  final String declaration;
  final String notes;
  final String authorizedSignatory;

  final DateTime createdAt;
  final DateTime updatedAt;

  ExportInvoiceModel({
    required this.id,
    required this.companyId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.currency,
    required this.exchangeRate,
    required this.placeOfSupply,
    required this.status,
    required this.createdBy,
    required this.supplier,
    required this.buyer,
    required this.consignee,
    required this.exportDetails,
    required this.logistics,
    required this.items,
    required this.taxDetails,
    required this.totals,
    required this.paymentDetails,
    required this.declaration,
    this.notes = '',
    this.authorizedSignatory = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'currency': currency,
      'exchangeRate': exchangeRate,
      'placeOfSupply': placeOfSupply,
      'status': status,
      'createdBy': createdBy,
      'supplier': supplier.toMap(),
      'buyer': buyer.toMap(),
      'consignee': consignee.toMap(),
      'exportDetails': exportDetails.toMap(),
      'logistics': logistics.toMap(),
      'items': items.map((e) => e.toMap()).toList(),
      'taxDetails': taxDetails.toMap(),
      'totals': totals.toMap(),
      'paymentDetails': paymentDetails.toMap(),
      'declaration': declaration,
      'notes': notes,
      'authorizedSignatory': authorizedSignatory,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ExportInvoiceModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExportInvoiceModel(
      id: docId,
      companyId: map['companyId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      invoiceDate: (map['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currency: map['currency'] ?? 'USD',
      exchangeRate: (map['exchangeRate'] ?? 1).toDouble(),
      placeOfSupply: map['placeOfSupply'] ?? '',
      status: map['status'] ?? 'Draft',
      createdBy: map['createdBy'] ?? '',
      supplier: Party.fromMap(map['supplier'] ?? {}),
      buyer: Party.fromMap(map['buyer'] ?? {}),
      consignee: Party.fromMap(map['consignee'] ?? {}),
      exportDetails: ExportDetails.fromMap(map['exportDetails'] ?? {}),
      logistics: Logistics.fromMap(map['logistics'] ?? {}),
      items: List<ExportInvoiceItem>.from(
        (map['items'] ?? []).map((x) => ExportInvoiceItem.fromMap(x, x['id'] ?? docId)),
      ),
      taxDetails: TaxDetails.fromMap(map['taxDetails'] ?? {}),
      totals: Totals.fromMap(map['totals'] ?? {}),
      paymentDetails: PaymentDetails.fromMap(map['paymentDetails'] ?? {}),
      declaration: map['declaration'] ?? '',
      notes: map['notes'] ?? '',
      authorizedSignatory: map['authorizedSignatory'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}