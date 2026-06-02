// FILE PATH: lib/modules/crm/customers/customer_visit_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerVisitModel {
  final String id;
  final String companyId;
  final String createdBy;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final bool isDeleted;

  // Visit Metadata
  final String visitNumber;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String visitDuration;
  final String gpsLocation;
  final List<String> attachments;
  final String status;
  final String outcome;

  // Customer Details
  final String customerId;
  final String customerName;
  final String contactPerson;
  final String designation;
  final String mobile;
  final String email;
  final String address;
  final String location;
  final String assignedEmployee;

  // Purpose & Core Context
  final String purpose;
  final DateTime? visitDate;
  final String priority;

  // Dynamic Integration Fields
  final bool leadGenerated;
  final String linkedInquiryId;
  final String linkedQuotationId;
  final String linkedServiceTicketId;

  // Discussion & Feedback Fields
  final String discussionNotes;
  final String quotationStatus;
  final String customerFeedback;
  final String priceFeedback;
  final String competitorFeedback;
  final String technicalTopics;

  // Financial Follow-up Fields
  final double outstandingAmount;
  final DateTime? paymentCommitmentDate;
  final String paymentRemarks;

  // Service & Operations Fields
  final String serviceObservation;
  final String actionTaken;
  final String recommendation;
  final String complaintDescription;
  final String complaintSeverity;
  final String temporaryResolution;
  final String installationNotes;
  final String machineStatus;
  final String customerAcceptance;
  final DateTime? nextServiceDate;

  // General Internal Notes
  final String internalNotes;

  // Follow-up
  final bool followupRequired;
  final DateTime? followupDate;
  final String followupType;
  final String followupPriority;
  final String followupRemarks;

  CustomerVisitModel({
    required this.id,
    required this.companyId,
    required this.createdBy,
    required this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.isDeleted = false,
    required this.visitNumber,
    this.checkInTime,
    this.checkOutTime,
    this.visitDuration = '',
    this.gpsLocation = '',
    this.attachments = const [],
    this.status = 'Draft',
    this.outcome = '',
    required this.customerId,
    required this.customerName,
    this.contactPerson = '',
    this.designation = '',
    this.mobile = '',
    this.email = '',
    this.address = '',
    this.location = '',
    this.assignedEmployee = '',
    required this.purpose,
    this.visitDate,
    this.priority = 'Medium',
    this.leadGenerated = false,
    this.linkedInquiryId = '',
    this.linkedQuotationId = '',
    this.linkedServiceTicketId = '',
    this.discussionNotes = '',
    this.quotationStatus = '',
    this.customerFeedback = '',
    this.priceFeedback = '',
    this.competitorFeedback = '',
    this.technicalTopics = '',
    this.outstandingAmount = 0.0,
    this.paymentCommitmentDate,
    this.paymentRemarks = '',
    this.serviceObservation = '',
    this.actionTaken = '',
    this.recommendation = '',
    this.complaintDescription = '',
    this.complaintSeverity = 'Medium',
    this.temporaryResolution = '',
    this.installationNotes = '',
    this.machineStatus = '',
    this.customerAcceptance = '',
    this.nextServiceDate,
    this.internalNotes = '',
    this.followupRequired = false,
    this.followupDate,
    this.followupType = 'Call',
    this.followupPriority = 'Medium',
    this.followupRemarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'visitNumber': visitNumber,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'visitDuration': visitDuration,
      'gpsLocation': gpsLocation,
      'attachments': attachments,
      'status': status,
      'outcome': outcome,
      'customerId': customerId,
      'customerName': customerName,
      'contactPerson': contactPerson,
      'designation': designation,
      'mobile': mobile,
      'email': email,
      'address': address,
      'location': location,
      'assignedEmployee': assignedEmployee,
      'purpose': purpose,
      'visitDate': visitDate != null ? Timestamp.fromDate(visitDate!) : null,
      'priority': priority,
      'leadGenerated': leadGenerated,
      'linkedInquiryId': linkedInquiryId,
      'linkedQuotationId': linkedQuotationId,
      'linkedServiceTicketId': linkedServiceTicketId,
      'discussionNotes': discussionNotes,
      'quotationStatus': quotationStatus,
      'customerFeedback': customerFeedback,
      'priceFeedback': priceFeedback,
      'competitorFeedback': competitorFeedback,
      'technicalTopics': technicalTopics,
      'outstandingAmount': outstandingAmount,
      'paymentCommitmentDate': paymentCommitmentDate != null ? Timestamp.fromDate(paymentCommitmentDate!) : null,
      'paymentRemarks': paymentRemarks,
      'serviceObservation': serviceObservation,
      'actionTaken': actionTaken,
      'recommendation': recommendation,
      'complaintDescription': complaintDescription,
      'complaintSeverity': complaintSeverity,
      'temporaryResolution': temporaryResolution,
      'installationNotes': installationNotes,
      'machineStatus': machineStatus,
      'customerAcceptance': customerAcceptance,
      'nextServiceDate': nextServiceDate != null ? Timestamp.fromDate(nextServiceDate!) : null,
      'internalNotes': internalNotes,
      'followupRequired': followupRequired,
      'followupDate': followupDate != null ? Timestamp.fromDate(followupDate!) : null,
      'followupType': followupType,
      'followupPriority': followupPriority,
      'followupRemarks': followupRemarks,
    };
  }

  factory CustomerVisitModel.fromMap(Map<String, dynamic> map, String docId) {
    return CustomerVisitModel(
      id: docId,
      companyId: map['companyId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      updatedBy: map['updatedBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      isDeleted: map['isDeleted'] ?? false,
      visitNumber: map['visitNumber'] ?? '',
      checkInTime: (map['checkInTime'] as Timestamp?)?.toDate(),
      checkOutTime: (map['checkOutTime'] as Timestamp?)?.toDate(),
      visitDuration: map['visitDuration'] ?? '',
      gpsLocation: map['gpsLocation'] ?? '',
      attachments: List<String>.from(map['attachments'] ?? []),
      status: map['status'] ?? 'Draft',
      outcome: map['outcome'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      designation: map['designation'] ?? '',
      mobile: map['mobile'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      location: map['location'] ?? '',
      assignedEmployee: map['assignedEmployee'] ?? '',
      purpose: map['purpose'] ?? 'Other',
      visitDate: (map['visitDate'] as Timestamp?)?.toDate(),
      priority: map['priority'] ?? 'Medium',
      leadGenerated: map['leadGenerated'] ?? false,
      linkedInquiryId: map['linkedInquiryId'] ?? '',
      linkedQuotationId: map['linkedQuotationId'] ?? '',
      linkedServiceTicketId: map['linkedServiceTicketId'] ?? '',
      discussionNotes: map['discussionNotes'] ?? '',
      quotationStatus: map['quotationStatus'] ?? '',
      customerFeedback: map['customerFeedback'] ?? '',
      priceFeedback: map['priceFeedback'] ?? '',
      competitorFeedback: map['competitorFeedback'] ?? '',
      technicalTopics: map['technicalTopics'] ?? '',
      outstandingAmount: (map['outstandingAmount'] ?? 0.0).toDouble(),
      paymentCommitmentDate: (map['paymentCommitmentDate'] as Timestamp?)?.toDate(),
      paymentRemarks: map['paymentRemarks'] ?? '',
      serviceObservation: map['serviceObservation'] ?? '',
      actionTaken: map['actionTaken'] ?? '',
      recommendation: map['recommendation'] ?? '',
      complaintDescription: map['complaintDescription'] ?? '',
      complaintSeverity: map['complaintSeverity'] ?? 'Medium',
      temporaryResolution: map['temporaryResolution'] ?? '',
      installationNotes: map['installationNotes'] ?? '',
      machineStatus: map['machineStatus'] ?? '',
      customerAcceptance: map['customerAcceptance'] ?? '',
      nextServiceDate: (map['nextServiceDate'] as Timestamp?)?.toDate(),
      internalNotes: map['internalNotes'] ?? '',
      followupRequired: map['followupRequired'] ?? false,
      followupDate: (map['followupDate'] as Timestamp?)?.toDate(),
      followupType: map['followupType'] ?? 'Call',
      followupPriority: map['followupPriority'] ?? 'Medium',
      followupRemarks: map['followupRemarks'] ?? '',
    );
  }
}