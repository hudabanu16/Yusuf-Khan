// FILE PATH: lib/models/company_model.dart

class CompanyModel {
  final String companyId;
  final String companyName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String gstin;
  final String pan;
  final String website;
  final String createdByUid;
  final String adminUid;
  final String plan;
  final bool isActive;
  final String industryType;

  CompanyModel({
    required this.companyId,
    required this.companyName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.gstin,
    required this.pan,
    required this.website,
    required this.createdByUid,
    required this.adminUid,
    required this.plan,
    required this.isActive,
    required this.industryType,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'gstin': gstin,
      'pan': pan,
      'website': website,
      'createdByUid': createdByUid,
      'adminUid': adminUid,
      'plan': plan,
      'isActive': isActive,
      'industryType': industryType,
    };
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    final rawIndustry = (map['industryType'] ?? map['businessCategory'] ?? '').toString();
    final finalIndustry = (rawIndustry.toLowerCase().contains('export') && rawIndustry.toLowerCase().contains('import'))
        ? 'export_import'
        : rawIndustry;

    return CompanyModel(
      companyId: (map['companyId'] ?? '').toString(),
      companyName: (map['companyName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      pincode: (map['pincode'] ?? '').toString(),
      gstin: (map['gstin'] ?? '').toString(),
      pan: (map['pan'] ?? '').toString(),
      website: (map['website'] ?? '').toString(),
      createdByUid: (map['createdByUid'] ?? '').toString(),
      adminUid: (map['adminUid'] ?? '').toString(),
      plan: (map['plan'] ?? 'trial').toString(),
      isActive: map['isActive'] ?? true,
      industryType: finalIndustry,
    );
  }
}