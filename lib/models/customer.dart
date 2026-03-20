class Customer {
  final String id;

  // Core
  final String name;
  final String companyName;
  final String phone;
  final String companyPhone;
  final String alternatePhone;
  final String email;
  final String businessEmail;
  final String website;
  final String gst;
  final String pan;
  final String address;

  // Classification
  final String customerType;
  final String industry;
  final String leadSource;
  final String status;
  final String priority;

  // Primary contact snapshot
  final String contactName;
  final String designation;
  final String department;

  // Address breakdown
  final String street;
  final String city;
  final String state;
  final String pincode;
  final String country;

  // Assignment / ownership
  final String companyId;
  final String assignedToUid;
  final String assignedByUid;
  final String createdBy;
  final String createdByUid;
  final String updatedBy;
  final String updatedByUid;
  final String recordOwnerUid;

  // Notes
  final String notes;
  final String remarks;

  // Flags
  final bool isActive;

  const Customer({
    required this.id,

    required this.name,
    required this.companyName,
    required this.phone,
    required this.companyPhone,
    required this.alternatePhone,
    required this.email,
    required this.businessEmail,
    required this.website,
    required this.gst,
    required this.pan,
    required this.address,

    required this.customerType,
    required this.industry,
    required this.leadSource,
    required this.status,
    required this.priority,

    required this.contactName,
    required this.designation,
    required this.department,

    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,

    required this.companyId,
    required this.assignedToUid,
    required this.assignedByUid,
    required this.createdBy,
    required this.createdByUid,
    required this.updatedBy,
    required this.updatedByUid,
    required this.recordOwnerUid,

    required this.notes,
    required this.remarks,

    required this.isActive,
  });

  factory Customer.empty() {
    return const Customer(
      id: '',
      name: '',
      companyName: '',
      phone: '',
      companyPhone: '',
      alternatePhone: '',
      email: '',
      businessEmail: '',
      website: '',
      gst: '',
      pan: '',
      address: '',
      customerType: '',
      industry: '',
      leadSource: '',
      status: '',
      priority: '',
      contactName: '',
      designation: '',
      department: '',
      street: '',
      city: '',
      state: '',
      pincode: '',
      country: 'India',
      companyId: '',
      assignedToUid: '',
      assignedByUid: '',
      createdBy: '',
      createdByUid: '',
      updatedBy: '',
      updatedByUid: '',
      recordOwnerUid: '',
      notes: '',
      remarks: '',
      isActive: true,
    );
  }

  Customer copyWith({
    String? id,

    String? name,
    String? companyName,
    String? phone,
    String? companyPhone,
    String? alternatePhone,
    String? email,
    String? businessEmail,
    String? website,
    String? gst,
    String? pan,
    String? address,

    String? customerType,
    String? industry,
    String? leadSource,
    String? status,
    String? priority,

    String? contactName,
    String? designation,
    String? department,

    String? street,
    String? city,
    String? state,
    String? pincode,
    String? country,

    String? companyId,
    String? assignedToUid,
    String? assignedByUid,
    String? createdBy,
    String? createdByUid,
    String? updatedBy,
    String? updatedByUid,
    String? recordOwnerUid,

    String? notes,
    String? remarks,

    bool? isActive,
  }) {
    return Customer(
      id: id ?? this.id,

      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      companyPhone: companyPhone ?? this.companyPhone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      email: email ?? this.email,
      businessEmail: businessEmail ?? this.businessEmail,
      website: website ?? this.website,
      gst: gst ?? this.gst,
      pan: pan ?? this.pan,
      address: address ?? this.address,

      customerType: customerType ?? this.customerType,
      industry: industry ?? this.industry,
      leadSource: leadSource ?? this.leadSource,
      status: status ?? this.status,
      priority: priority ?? this.priority,

      contactName: contactName ?? this.contactName,
      designation: designation ?? this.designation,
      department: department ?? this.department,

      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      country: country ?? this.country,

      companyId: companyId ?? this.companyId,
      assignedToUid: assignedToUid ?? this.assignedToUid,
      assignedByUid: assignedByUid ?? this.assignedByUid,
      createdBy: createdBy ?? this.createdBy,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      recordOwnerUid: recordOwnerUid ?? this.recordOwnerUid,

      notes: notes ?? this.notes,
      remarks: remarks ?? this.remarks,

      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // Core
      'name': name,
      'companyName': companyName.isNotEmpty ? companyName : name,
      'phone': phone,
      'companyPhone': companyPhone.isNotEmpty ? companyPhone : phone,
      'alternatePhone': alternatePhone,
      'email': email,
      'businessEmail': businessEmail.isNotEmpty ? businessEmail : email,
      'website': website,
      'gst': gst,
      'pan': pan,
      'address': address,

      // Classification
      'customerType': customerType,
      'industry': industry,
      'leadSource': leadSource,
      'status': status,
      'priority': priority,

      // Primary contact snapshot
      'contactName': contactName,
      'designation': designation,
      'department': department,

      // Address breakdown
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,

      // Assignment / ownership
      'companyId': companyId,
      'assignedToUid': assignedToUid,
      'assignedByUid': assignedByUid,
      'createdBy': createdBy,
      'createdByUid': createdByUid,
      'updatedBy': updatedBy,
      'updatedByUid': updatedByUid,
      'recordOwnerUid': recordOwnerUid,

      // Notes
      'notes': notes,
      'remarks': remarks,

      // Flags
      'isActive': isActive,
    };
  }

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    final resolvedName = (map['companyName'] ?? map['name'] ?? '').toString();
    final resolvedPhone =
    (map['companyPhone'] ?? map['phone'] ?? '').toString();
    final resolvedEmail =
    (map['businessEmail'] ?? map['email'] ?? '').toString();

    return Customer(
      id: id,

      // Core
      name: (map['name'] ?? resolvedName).toString(),
      companyName: resolvedName,
      phone: (map['phone'] ?? resolvedPhone).toString(),
      companyPhone: resolvedPhone,
      alternatePhone: (map['alternatePhone'] ?? '').toString(),
      email: (map['email'] ?? resolvedEmail).toString(),
      businessEmail: resolvedEmail,
      website: (map['website'] ?? '').toString(),
      gst: (map['gst'] ?? '').toString(),
      pan: (map['pan'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),

      // Classification
      customerType: (map['customerType'] ?? '').toString(),
      industry: (map['industry'] ?? '').toString(),
      leadSource: (map['leadSource'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      priority: (map['priority'] ?? '').toString(),

      // Primary contact snapshot
      contactName: (map['contactName'] ?? '').toString(),
      designation: (map['designation'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),

      // Address breakdown
      street: (map['street'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      pincode: (map['pincode'] ?? '').toString(),
      country: (map['country'] ?? 'India').toString(),

      // Assignment / ownership
      companyId: (map['companyId'] ?? '').toString(),
      assignedToUid: (map['assignedToUid'] ?? '').toString(),
      assignedByUid: (map['assignedByUid'] ?? '').toString(),
      createdBy: (map['createdBy'] ?? '').toString(),
      createdByUid: (map['createdByUid'] ?? '').toString(),
      updatedBy: (map['updatedBy'] ?? '').toString(),
      updatedByUid: (map['updatedByUid'] ?? '').toString(),
      recordOwnerUid: (map['recordOwnerUid'] ?? '').toString(),

      // Notes
      notes: (map['notes'] ?? '').toString(),
      remarks: (map['remarks'] ?? '').toString(),

      // Flags
      isActive: map['isActive'] == null ? true : map['isActive'] == true,
    );
  }
}