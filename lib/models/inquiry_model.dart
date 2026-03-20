// lib/models/inquiry_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Inquiry {
  final String id;
  final String companyId;

  final String inquiryNumber;
  final String subject;

  final String customerId;
  final String customerName;

  final String contactId;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final String contactDesignation;

  final String source;          // Phone / WhatsApp / Email / Visit / Tender / Website
  final String sourceReference; // L&T, IndiaMART, JustDial etc.
  final String channelRef;      // kept for old code compatibility
  final String inquiryType;     // Product / Service / Project / Both

  final String requiredProducts;
  final String location;
  final String quantityScope;   // new field
  final String quantityNote;    // old compatibility field
  final String expectedValue;   // new field
  final String budgetNote;      // old compatibility field
  final String deliveryTimeline;

  final String notes;
  final String internalNotes;

  final String priority;        // Hot / Warm / Cold
  final String status;          // Open / Quotation Pending / Quotation Sent / Won / Lost / Not Qualified

  final DateTime? nextFollowUpDate;
  final DateTime? expectedClosureDate;
  final String lastFollowUpNote;

  final String linkedQuotationId;

  final String assignedToUid;
  final String assignedToName;
  final String assignedToRole;
  final String assignedByUid;

  final DateTime? createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String updatedBy;

  final bool isActive;

  Inquiry({
    required this.id,
    required this.companyId,
    required this.inquiryNumber,
    required this.subject,
    required this.customerId,
    required this.customerName,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.contactEmail,
    required this.contactDesignation,
    required this.source,
    required this.sourceReference,
    required this.channelRef,
    required this.inquiryType,
    required this.requiredProducts,
    required this.location,
    required this.quantityScope,
    required this.quantityNote,
    required this.expectedValue,
    required this.budgetNote,
    required this.deliveryTimeline,
    required this.notes,
    required this.internalNotes,
    required this.priority,
    required this.status,
    required this.nextFollowUpDate,
    required this.expectedClosureDate,
    required this.lastFollowUpNote,
    required this.linkedQuotationId,
    required this.assignedToUid,
    required this.assignedToName,
    required this.assignedToRole,
    required this.assignedByUid,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
    required this.isActive,
  });

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _toStr(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static bool _toBool(dynamic value, {bool fallback = true}) {
    if (value is bool) return value;
    return fallback;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final s = _toStr(value);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  factory Inquiry.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final sourceReference = _firstNonEmpty([
      data['sourceReference'],
      data['channelRef'],
    ]);

    final quantityScope = _firstNonEmpty([
      data['quantityScope'],
      data['quantityNote'],
    ]);

    final expectedValue = _firstNonEmpty([
      data['expectedValue'],
      data['budgetNote'],
    ]);

    return Inquiry(
      id: doc.id,
      companyId: _toStr(data['companyId']),
      inquiryNumber: _toStr(data['inquiryNumber']),
      subject: _toStr(data['subject']),
      customerId: _toStr(data['customerId']),
      customerName: _toStr(data['customerName']),
      contactId: _toStr(data['contactId']),
      contactName: _toStr(data['contactName']),
      contactPhone: _toStr(data['contactPhone']),
      contactEmail: _toStr(data['contactEmail']),
      contactDesignation: _toStr(data['contactDesignation']),
      source: _toStr(data['source']),
      sourceReference: sourceReference,
      channelRef: sourceReference,
      inquiryType: _toStr(data['inquiryType']),
      requiredProducts: _toStr(data['requiredProducts']),
      location: _toStr(data['location']),
      quantityScope: quantityScope,
      quantityNote: quantityScope,
      expectedValue: expectedValue,
      budgetNote: expectedValue,
      deliveryTimeline: _toStr(data['deliveryTimeline']),
      notes: _toStr(data['notes']),
      internalNotes: _toStr(data['internalNotes']),
      priority: _toStr(data['priority']),
      status: _toStr(data['status']),
      nextFollowUpDate: _toDate(data['nextFollowUpDate']),
      expectedClosureDate: _toDate(data['expectedClosureDate']),
      lastFollowUpNote: _toStr(data['lastFollowUpNote']),
      linkedQuotationId: _toStr(data['linkedQuotationId']),
      assignedToUid: _toStr(data['assignedToUid']),
      assignedToName: _toStr(data['assignedToName']),
      assignedToRole: _toStr(data['assignedToRole']),
      assignedByUid: _toStr(data['assignedByUid']),
      createdAt: _toDate(data['createdAt']),
      createdBy: _toStr(data['createdBy']),
      updatedAt: _toDate(data['updatedAt']),
      updatedBy: _toStr(data['updatedBy']),
      isActive: _toBool(data['isActive'], fallback: true),
    );
  }

  factory Inquiry.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final sourceReference = _firstNonEmpty([
      data['sourceReference'],
      data['channelRef'],
    ]);

    final quantityScope = _firstNonEmpty([
      data['quantityScope'],
      data['quantityNote'],
    ]);

    final expectedValue = _firstNonEmpty([
      data['expectedValue'],
      data['budgetNote'],
    ]);

    return Inquiry(
      id: id,
      companyId: _toStr(data['companyId']),
      inquiryNumber: _toStr(data['inquiryNumber']),
      subject: _toStr(data['subject']),
      customerId: _toStr(data['customerId']),
      customerName: _toStr(data['customerName']),
      contactId: _toStr(data['contactId']),
      contactName: _toStr(data['contactName']),
      contactPhone: _toStr(data['contactPhone']),
      contactEmail: _toStr(data['contactEmail']),
      contactDesignation: _toStr(data['contactDesignation']),
      source: _toStr(data['source']),
      sourceReference: sourceReference,
      channelRef: sourceReference,
      inquiryType: _toStr(data['inquiryType']),
      requiredProducts: _toStr(data['requiredProducts']),
      location: _toStr(data['location']),
      quantityScope: quantityScope,
      quantityNote: quantityScope,
      expectedValue: expectedValue,
      budgetNote: expectedValue,
      deliveryTimeline: _toStr(data['deliveryTimeline']),
      notes: _toStr(data['notes']),
      internalNotes: _toStr(data['internalNotes']),
      priority: _toStr(data['priority']),
      status: _toStr(data['status']),
      nextFollowUpDate: _toDate(data['nextFollowUpDate']),
      expectedClosureDate: _toDate(data['expectedClosureDate']),
      lastFollowUpNote: _toStr(data['lastFollowUpNote']),
      linkedQuotationId: _toStr(data['linkedQuotationId']),
      assignedToUid: _toStr(data['assignedToUid']),
      assignedToName: _toStr(data['assignedToName']),
      assignedToRole: _toStr(data['assignedToRole']),
      assignedByUid: _toStr(data['assignedByUid']),
      createdAt: _toDate(data['createdAt']),
      createdBy: _toStr(data['createdBy']),
      updatedAt: _toDate(data['updatedAt']),
      updatedBy: _toStr(data['updatedBy']),
      isActive: _toBool(data['isActive'], fallback: true),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'companyId': companyId,

      'inquiryNumber': inquiryNumber,
      'subject': subject,

      'customerId': customerId,
      'customerName': customerName,

      'contactId': contactId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'contactDesignation': contactDesignation,

      'source': source,
      'sourceReference': sourceReference,
      'channelRef': sourceReference,

      'inquiryType': inquiryType,

      'requiredProducts': requiredProducts,
      'location': location,

      'quantityScope': quantityScope,
      'quantityNote': quantityScope,

      'expectedValue': expectedValue,
      'budgetNote': expectedValue,

      'deliveryTimeline': deliveryTimeline,

      'notes': notes,
      'internalNotes': internalNotes,

      'priority': priority,
      'status': status,

      'nextFollowUpDate':
      nextFollowUpDate == null ? null : Timestamp.fromDate(nextFollowUpDate!),
      'expectedClosureDate': expectedClosureDate == null
          ? null
          : Timestamp.fromDate(expectedClosureDate!),

      'lastFollowUpNote': lastFollowUpNote,
      'linkedQuotationId': linkedQuotationId,

      'assignedToUid': assignedToUid,
      'assignedToName': assignedToName,
      'assignedToRole': assignedToRole,
      'assignedByUid': assignedByUid,

      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };

    if (!isUpdate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['createdBy'] = createdBy;
    }

    return map;
  }

  Inquiry copyWith({
    String? id,
    String? companyId,
    String? inquiryNumber,
    String? subject,
    String? customerId,
    String? customerName,
    String? contactId,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? contactDesignation,
    String? source,
    String? sourceReference,
    String? channelRef,
    String? inquiryType,
    String? requiredProducts,
    String? location,
    String? quantityScope,
    String? quantityNote,
    String? expectedValue,
    String? budgetNote,
    String? deliveryTimeline,
    String? notes,
    String? internalNotes,
    String? priority,
    String? status,
    DateTime? nextFollowUpDate,
    bool clearNextFollowUpDate = false,
    DateTime? expectedClosureDate,
    bool clearExpectedClosureDate = false,
    String? lastFollowUpNote,
    String? linkedQuotationId,
    String? assignedToUid,
    String? assignedToName,
    String? assignedToRole,
    String? assignedByUid,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isActive,
  }) {
    final effectiveSourceReference =
        sourceReference ?? channelRef ?? this.sourceReference;

    final effectiveQuantityScope =
        quantityScope ?? quantityNote ?? this.quantityScope;

    final effectiveExpectedValue =
        expectedValue ?? budgetNote ?? this.expectedValue;

    return Inquiry(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      inquiryNumber: inquiryNumber ?? this.inquiryNumber,
      subject: subject ?? this.subject,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      contactDesignation: contactDesignation ?? this.contactDesignation,
      source: source ?? this.source,
      sourceReference: effectiveSourceReference,
      channelRef: effectiveSourceReference,
      inquiryType: inquiryType ?? this.inquiryType,
      requiredProducts: requiredProducts ?? this.requiredProducts,
      location: location ?? this.location,
      quantityScope: effectiveQuantityScope,
      quantityNote: effectiveQuantityScope,
      expectedValue: effectiveExpectedValue,
      budgetNote: effectiveExpectedValue,
      deliveryTimeline: deliveryTimeline ?? this.deliveryTimeline,
      notes: notes ?? this.notes,
      internalNotes: internalNotes ?? this.internalNotes,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      nextFollowUpDate: clearNextFollowUpDate
          ? null
          : (nextFollowUpDate ?? this.nextFollowUpDate),
      expectedClosureDate: clearExpectedClosureDate
          ? null
          : (expectedClosureDate ?? this.expectedClosureDate),
      lastFollowUpNote: lastFollowUpNote ?? this.lastFollowUpNote,
      linkedQuotationId: linkedQuotationId ?? this.linkedQuotationId,
      assignedToUid: assignedToUid ?? this.assignedToUid,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedToRole: assignedToRole ?? this.assignedToRole,
      assignedByUid: assignedByUid ?? this.assignedByUid,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isActive: isActive ?? this.isActive,
    );
  }
}