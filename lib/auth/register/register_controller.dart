import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/core/modules/models/app_module.dart';
import 'package:QUIK/core/modules/module_registry.dart';

import 'register_constants.dart';
import 'register_workspace_service.dart';
import 'verify_workspace_otp_screen.dart';

class RegisterController extends ChangeNotifier {
  RegisterController({RegisterWorkspaceService? service})
      : _service = service ?? RegisterWorkspaceService();

  final RegisterWorkspaceService _service;
  final formKey = GlobalKey<FormState>();

  final entityNameController = TextEditingController();
  final addressController = TextEditingController();
  final stateController = TextEditingController();
  final cityController = TextEditingController();
  final pincodeController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final gstinController = TextEditingController();
  final panController = TextEditingController();
  final iecController = TextEditingController();
  final websiteController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final cinController = TextEditingController();
  final llpinController = TextEditingController();
  final firmRegistrationController = TextEditingController();
  final trustRegistrationController = TextEditingController();
  final proprietorNameController = TextEditingController();
  final kartaNameController = TextEditingController();
  final managingPartnerController = TextEditingController();
  final authorizedPersonController = TextEditingController();

  Uint8List? logoBytes;
  String? logoUrl;

  bool isLoading = false;
  bool isEditMode = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool showTaxInfo = false;

  int currentStep = 0;

  final Set<String> _selectedWorkspaceModuleIds = {
    ModuleIds.crm,
    ModuleIds.sales,
    ModuleIds.service,
    ModuleIds.inventory,
    ModuleIds.finance,
    ModuleIds.reports,
  };

  String? selectedEntityType;
  String? selectedEmployeeRange;
  String? selectedIndustryType;
  String? selectedSubIndustry;
  String? selectedListingStatus;
  String? selectedRegistrationStatus;
  String? selectedStateValue;

  List<String> get availableSubIndustries {
    if (selectedIndustryType == null) return [];
    return RegisterConstants.subIndustriesByIndustry[selectedIndustryType!] ??
        [];
  }

  bool get needsCIN {
    return selectedEntityType == 'Private Limited Company' ||
        selectedEntityType == 'Public Limited Company' ||
        selectedEntityType == 'One Person Company (OPC)' ||
        selectedEntityType == 'Section 8 Company' ||
        selectedEntityType == 'Subsidiary Company' ||
        selectedEntityType == 'Government Company';
  }

  bool get needsLLPIN =>
      selectedEntityType == 'Limited Liability Partnership (LLP)';

  bool get needsFirmRegistration => selectedEntityType == 'Partnership Firm';

  bool get needsTrustRegistration =>
      selectedEntityType == 'Trust' || selectedEntityType == 'Society';

  bool get needsProprietorName => selectedEntityType == 'Proprietorship';

  bool get needsKartaName =>
      selectedEntityType == 'Hindu Undivided Family (HUF)';

  bool get needsManagingPartner =>
      selectedEntityType == 'Partnership Firm' ||
          selectedEntityType == 'Limited Liability Partnership (LLP)';

  bool get needsAuthorizedPerson =>
      selectedEntityType == 'Public Limited Company' ||
          selectedEntityType == 'Private Limited Company' ||
          selectedEntityType == 'One Person Company (OPC)' ||
          selectedEntityType == 'Section 8 Company' ||
          selectedEntityType == 'Trust' ||
          selectedEntityType == 'Society' ||
          selectedEntityType == 'Branch Office' ||
          selectedEntityType == 'Liaison Office' ||
          selectedEntityType == 'Subsidiary Company' ||
          selectedEntityType == 'Foreign Company' ||
          selectedEntityType == 'Government Company' ||
          selectedEntityType == 'Statutory Corporation';

  static const Set<String> requiredWorkspaceModuleIds = {
    ModuleIds.administration,
    ModuleIds.settings,
  };

  static const Set<String> selectableWorkspaceModuleIds = {
    ModuleIds.crm,
    ModuleIds.sales,
    ModuleIds.service,
    ModuleIds.inventory,
    ModuleIds.finance,
    ModuleIds.reports,
    ModuleIds.iot,
    ModuleIds.production,
  };

  List<AppModule> get requiredWorkspaceModules {
    return ModuleRegistry.activeModules
        .where((module) => requiredWorkspaceModuleIds.contains(module.id))
        .toList(growable: false);
  }

  List<AppModule> get selectableWorkspaceModules {
    return ModuleRegistry.activeModules
        .where((module) => selectableWorkspaceModuleIds.contains(module.id))
        .toList(growable: false);
  }

  Set<String> get enabledWorkspaceModuleIds {
    return {...requiredWorkspaceModuleIds, ..._selectedWorkspaceModuleIds};
  }

  bool isWorkspaceModuleSelected(String moduleId) {
    return enabledWorkspaceModuleIds.contains(moduleId);
  }

  void toggleWorkspaceModule(String moduleId, bool enabled) {
    if (requiredWorkspaceModuleIds.contains(moduleId) ||
        !selectableWorkspaceModuleIds.contains(moduleId)) {
      return;
    }

    if (enabled) {
      _selectedWorkspaceModuleIds.add(moduleId);
    } else {
      _selectedWorkspaceModuleIds.remove(moduleId);
    }

    notifyListeners();
  }

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      await _loadExistingProfile();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> adminPermissions() {
    return {
      'dashboard': true,
      'customers': true,
      'contacts': true,
      'products': true,
      'inquiries': true,
      'quotations': true,
      'reports': true,
      'userManagement': true,
    };
  }

  Future<void> pickLogo({
    required void Function(String) onInfo,
    required void Function(String) onError,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        onInfo('No logo selected');
        return;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        onError('Unable to read logo file');
        return;
      }

      logoBytes = file.bytes;
      // 🔥 CRITICAL FIX: Do NOT set logoUrl = null here!
      // If we erase the old URL now, the Service cannot delete the old file from Storage.
      notifyListeners();
    } catch (e) {
      onError('Failed to pick logo: $e');
    }
  }

  void removeLogo() {
    logoBytes = null;
    logoUrl = null;
    notifyListeners();
  }

  Future<void> _loadExistingProfile() async {
    final user = await _service.getLocalCurrentUser();
    if (user == null) return;

    isEditMode = true;

    entityNameController.text =
        (user['entityName'] ?? user['companyName'] ?? '').toString();
    addressController.text = (user['address'] ?? user['streetAddress'] ?? '')
        .toString();
    stateController.text = (user['state'] ?? '').toString();
    cityController.text = (user['district'] ?? user['city'] ?? '').toString();
    pincodeController.text = (user['pincode'] ?? '').toString();
    emailController.text = (user['email'] ?? '').toString();
    phoneController.text = (user['phone'] ?? '').toString();
    gstinController.text = (user['gstin'] ?? '').toString();
    panController.text = (user['pan'] ?? '').toString();
    iecController.text = (user['iecCode'] ?? '').toString();
    websiteController.text = (user['website'] ?? '').toString();

    cinController.text = (user['cin'] ?? '').toString();
    llpinController.text = (user['llpin'] ?? '').toString();
    firmRegistrationController.text = (user['firmRegistrationNumber'] ?? '')
        .toString();
    trustRegistrationController.text = (user['trustRegistrationNumber'] ?? '')
        .toString();
    proprietorNameController.text = (user['proprietorName'] ?? '').toString();
    kartaNameController.text = (user['kartaName'] ?? '').toString();
    managingPartnerController.text = (user['managingPartnerName'] ?? '')
        .toString();
    authorizedPersonController.text = (user['authorizedPersonName'] ?? '')
        .toString();

    selectedEntityType = (user['entityType'] ?? '').toString().isEmpty
        ? null
        : user['entityType'].toString();

    selectedEmployeeRange = (user['employeeRange'] ?? '').toString().isEmpty
        ? null
        : user['employeeRange'].toString();

    selectedIndustryType =
    (user['industryType'] ?? user['businessCategory'] ?? '')
        .toString()
        .isEmpty
        ? null
        : (user['industryType'] ?? user['businessCategory']).toString();

    selectedSubIndustry = (user['subIndustry'] ?? '').toString().isEmpty
        ? null
        : user['subIndustry'].toString();

    selectedListingStatus = (user['listingStatus'] ?? '').toString().isEmpty
        ? null
        : user['listingStatus'].toString();

    selectedRegistrationStatus =
    (user['registrationStatus'] ?? '').toString().isEmpty
        ? null
        : user['registrationStatus'].toString();

    final savedState = stateController.text.trim();
    selectedStateValue = RegisterConstants.indiaStates.contains(savedState)
        ? savedState
        : null;

    String? validLogoUrl;
    final possibleLogos = [
      user['companyLogoUrl'],
      user['logoUrl'],
      user['logoPath']
    ];

    for (final l in possibleLogos) {
      if (l != null && l.toString().trim().isNotEmpty) {
        validLogoUrl = l.toString().trim();
        break;
      }
    }

    logoUrl = validLogoUrl;

    if (gstinController.text.trim().isNotEmpty ||
        panController.text.trim().isNotEmpty ||
        iecController.text.trim().isNotEmpty) {
      showTaxInfo = true;
    }
  }

  String resolvedDisplayName() {
    if (authorizedPersonController.text.trim().isNotEmpty) {
      return authorizedPersonController.text.trim();
    }
    if (proprietorNameController.text.trim().isNotEmpty) {
      return proprietorNameController.text.trim();
    }
    if (kartaNameController.text.trim().isNotEmpty) {
      return kartaNameController.text.trim();
    }
    if (managingPartnerController.text.trim().isNotEmpty) {
      return managingPartnerController.text.trim();
    }
    return entityNameController.text.trim();
  }

  Map<String, dynamic> buildCompanyPayload({required String? logoUrlValue}) {
    return {
      'entityName': entityNameController.text.trim(),
      'companyName': entityNameController.text.trim(),
      'entityType': selectedEntityType ?? '',
      'employeeRange': selectedEmployeeRange ?? '',
      'businessCategory': selectedIndustryType ?? '',
      'industryType': selectedIndustryType ?? '',
      'subIndustry': selectedSubIndustry ?? '',
      'listingStatus': selectedListingStatus ?? '',
      'registrationStatus': selectedRegistrationStatus ?? '',
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
      'streetAddress': addressController.text.trim(),
      'country': 'India',
      'countryCode': 'IN',
      'state': stateController.text.trim(),
      'district': cityController.text.trim(),
      'city': cityController.text.trim(),
      'pincode': pincodeController.text.trim(),
      'gstin': gstinController.text.trim(),
      'pan': panController.text.trim(),
      if (iecController.text.trim().isNotEmpty)
        'iecCode': iecController.text.trim(),
      'website': websiteController.text.trim(),
      'cin': cinController.text.trim(),
      'llpin': llpinController.text.trim(),
      'firmRegistrationNumber': firmRegistrationController.text.trim(),
      'trustRegistrationNumber': trustRegistrationController.text.trim(),
      'proprietorName': proprietorNameController.text.trim(),
      'kartaName': kartaNameController.text.trim(),
      'managingPartnerName': managingPartnerController.text.trim(),
      'authorizedPersonName': authorizedPersonController.text.trim(),

      'logoUrl': logoUrlValue ?? '',
      'companyLogoUrl': logoUrlValue ?? '',
    };
  }

  void goToNextStep({required void Function(String) onError}) {
    if (currentStep == 1) {
      if (isEditMode) return;

      if (addressController.text.trim().isEmpty) {
        onError('Please enter street address');
        return;
      }
      if (stateController.text.trim().isEmpty ||
          cityController.text.trim().isEmpty) {
        onError('Please enter state and district/city');
        return;
      }
      if (pincodeController.text.trim().isEmpty) {
        onError('Please enter pincode / zip code');
        return;
      }

      currentStep = 2;
      notifyListeners();
      return;
    }

    if (currentStep != 0) return;

    if (selectedEntityType == null || selectedEntityType!.trim().isEmpty) {
      onError('Please select entity type');
      return;
    }
    if (selectedIndustryType == null || selectedIndustryType!.trim().isEmpty) {
      onError('Please select industry type');
      return;
    }
    if (selectedSubIndustry == null || selectedSubIndustry!.trim().isEmpty) {
      onError('Please select sub industry');
      return;
    }
    if (entityNameController.text.trim().isEmpty) {
      onError('Please enter entity / firm name');
      return;
    }
    if (phoneController.text.trim().isEmpty) {
      onError('Please enter phone number');
      return;
    }
    if (emailController.text.trim().isEmpty) {
      onError('Please enter business email');
      return;
    }
    if (selectedEmployeeRange == null ||
        selectedEmployeeRange!.trim().isEmpty) {
      onError('Please select total employees');
      return;
    }
    if (selectedRegistrationStatus == null ||
        selectedRegistrationStatus!.trim().isEmpty) {
      onError('Please select registration status');
      return;
    }

    currentStep = 1;
    notifyListeners();
  }

  void goToPreviousStep() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    required BuildContext context,
    required void Function(String) onError,
    required void Function(String) onSuccess,
  }) async {
    if (!(formKey.currentState?.validate() ?? false)) return false;

    if (selectedEntityType == null || selectedEntityType!.trim().isEmpty) {
      onError('Please select entity type');
      return false;
    }
    if (selectedEmployeeRange == null ||
        selectedEmployeeRange!.trim().isEmpty) {
      onError('Please select total employees');
      return false;
    }
    if (selectedIndustryType == null || selectedIndustryType!.trim().isEmpty) {
      onError('Please select industry type');
      return false;
    }
    if (selectedSubIndustry == null || selectedSubIndustry!.trim().isEmpty) {
      onError('Please select sub industry');
      return false;
    }
    if (stateController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty) {
      onError('Please enter state and district/city');
      return false;
    }
    if (selectedRegistrationStatus == null ||
        selectedRegistrationStatus!.trim().isEmpty) {
      onError('Please select registration status');
      return false;
    }

    if (!isEditMode) {
      if (passwordController.text != confirmPasswordController.text) {
        onError('Passwords do not match');
        return false;
      }
      if (passwordController.text.length < 6) {
        onError('Password must be at least 6 characters');
        return false;
      }
    }

    isLoading = true;
    notifyListeners();

    try {
      if (isEditMode) {
        final localUser = await _service.getLocalCurrentUser();
        if (localUser == null) {
          throw Exception('Local user not found');
        }

        final current = _service.currentFirebaseUser;
        if (current == null) {
          throw Exception('No logged in Firebase user found');
        }

        final uid = current.uid;
        final email = emailController.text.trim().toLowerCase();

        final uploadedLogoUrl = await _service.uploadLogoIfNeeded(
          uid: uid,
          logoBytes: logoBytes,
          existingLogoUrl: logoUrl,
        );

        logoUrl = uploadedLogoUrl;
        logoBytes = null;

        final companyData = buildCompanyPayload(logoUrlValue: uploadedLogoUrl);

        final companyId = await _service.ensureCompanyForExistingUser(
          uid: uid,
          email: email,
          displayName: resolvedDisplayName(),
          logoUrl: uploadedLogoUrl,
          companyData: companyData,
          adminPermissions: adminPermissions(),
        );

        await _service.updateLocalUser(
          localUserId: localUser['id'] as int,
          data: companyData,
        );

        await _service.updateWorkspaceForExistingUser(
          uid: uid,
          companyId: companyId,
          email: email,
          displayName: resolvedDisplayName(),
          logoUrl: uploadedLogoUrl,
          companyData: companyData,
          adminPermissions: adminPermissions(),
        );

        onSuccess('Workspace updated successfully');
        return true;
      }

      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text;

      final tempUid = DateTime.now().millisecondsSinceEpoch.toString();
      final uploadedLogoUrl = await _service.uploadLogoIfNeeded(
        uid: tempUid,
        logoBytes: logoBytes,
        existingLogoUrl: logoUrl,
      );

      logoUrl = uploadedLogoUrl;
      logoBytes = null;

      final companyData = buildCompanyPayload(logoUrlValue: uploadedLogoUrl);
      final selectedModuleIds = enabledWorkspaceModuleIds;

      final registrationId = await _service.createWorkspaceRegistrationDraft(
        email: email,
        displayName: resolvedDisplayName(),
        logoUrl: uploadedLogoUrl,
        companyData: companyData,
        adminPermissions: adminPermissions(),
        enabledModuleIds: selectedModuleIds,
      );

      if (!context.mounted) return false;

      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyWorkspaceOtpScreen(
            registrationId: registrationId,
            businessEmail: email,
            entityName: entityNameController.text.trim(),
            password: password,
            enabledModuleIds: selectedModuleIds,
          ),
        ),
      );

      if (verified == true) {
        onSuccess('Business email verified and workspace created successfully');
        return true;
      }

      return false;
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already registered.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'weak-password':
          msg = 'Password is too weak.';
          break;
        default:
          msg = e.message ?? e.code;
      }
      onError('Firebase error: $msg');
      return false;
    } catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedEntityType(String? value) {
    selectedEntityType = value;
    cinController.clear();
    llpinController.clear();
    firmRegistrationController.clear();
    trustRegistrationController.clear();
    proprietorNameController.clear();
    kartaNameController.clear();
    managingPartnerController.clear();
    authorizedPersonController.clear();

    if (selectedEntityType != 'Public Limited Company' &&
        selectedEntityType != 'Private Limited Company' &&
        selectedEntityType != 'One Person Company (OPC)' &&
        selectedEntityType != 'Subsidiary Company' &&
        selectedEntityType != 'Government Company') {
      selectedListingStatus = null;
    }

    notifyListeners();
  }

  void setSelectedIndustryType(String? value) {
    selectedIndustryType = value;
    selectedSubIndustry = null;
    notifyListeners();
  }

  void setSelectedSubIndustry(String? value) {
    selectedSubIndustry = value;
    notifyListeners();
  }

  void setSelectedEmployeeRange(String? value) {
    selectedEmployeeRange = value;
    notifyListeners();
  }

  void setSelectedListingStatus(String? value) {
    selectedListingStatus = value;
    notifyListeners();
  }

  void setSelectedRegistrationStatus(String? value) {
    selectedRegistrationStatus = value;
    notifyListeners();
  }

  void setSelectedStateValue(String? value) {
    selectedStateValue = value;
    stateController.text = value ?? '';
    notifyListeners();
  }

  void toggleShowTaxInfo() {
    showTaxInfo = !showTaxInfo;
    notifyListeners();
  }

  void toggleObscurePassword() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void toggleObscureConfirmPassword() {
    obscureConfirmPassword = !obscureConfirmPassword;
    notifyListeners();
  }

  @override
  void dispose() {
    entityNameController.dispose();
    addressController.dispose();
    stateController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    emailController.dispose();
    phoneController.dispose();
    gstinController.dispose();
    panController.dispose();
    iecController.dispose();
    websiteController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    cinController.dispose();
    llpinController.dispose();
    firmRegistrationController.dispose();
    trustRegistrationController.dispose();
    proprietorNameController.dispose();
    kartaNameController.dispose();
    managingPartnerController.dispose();
    authorizedPersonController.dispose();

    super.dispose();
  }
}