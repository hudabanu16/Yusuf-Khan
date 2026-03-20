import 'package:flutter/material.dart';

import 'register_constants.dart';
import 'register_controller.dart';
import 'register_widgets.dart';

class RegisterScreenLocal extends StatefulWidget {
  const RegisterScreenLocal({super.key});

  @override
  State<RegisterScreenLocal> createState() => _RegisterScreenLocalState();
}

class _RegisterScreenLocalState extends State<RegisterScreenLocal> {
  late final RegisterController controller;

  @override
  void initState() {
    super.initState();
    controller = RegisterController()..initialize();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: regSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDynamicEntityFields() {
    if (controller.selectedEntityType == null) {
      return const SizedBox.shrink();
    }

    return RegisterWidgets.buildSectionCard(
      title: 'Entity-Specific Details',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          if (controller.needsCIN) ...[
            RegisterWidgets.buildResponsiveRow(
              children: [
                RegisterWidgets.buildTextField(
                  controller: controller.cinController,
                  label: 'CIN',
                  icon: Icons.confirmation_num_outlined,
                  hint: 'Corporate Identification Number',
                  required: true,
                ),
                RegisterWidgets.buildDropdownField<String>(
                  value: controller.selectedListingStatus,
                  label: 'Listing Status',
                  icon: Icons.query_stats_outlined,
                  items: RegisterConstants.listingStatuses,
                  required: true,
                  onChanged: controller.setSelectedListingStatus,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (controller.needsLLPIN) ...[
            RegisterWidgets.buildTextField(
              controller: controller.llpinController,
              label: 'LLPIN',
              icon: Icons.confirmation_num_outlined,
              hint: 'Limited Liability Partnership Identification Number',
              required: true,
            ),
            const SizedBox(height: 10),
          ],
          if (controller.needsFirmRegistration) ...[
            RegisterWidgets.buildResponsiveRow(
              children: [
                RegisterWidgets.buildTextField(
                  controller: controller.firmRegistrationController,
                  label: 'Firm Registration Number',
                  icon: Icons.app_registration_outlined,
                  hint: 'Partnership registration number',
                  required: true,
                ),
                RegisterWidgets.buildTextField(
                  controller: controller.managingPartnerController,
                  label: 'Managing Partner Name',
                  icon: Icons.person_outline,
                  hint: 'Name of managing partner',
                  required: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (controller.needsTrustRegistration) ...[
            RegisterWidgets.buildResponsiveRow(
              children: [
                RegisterWidgets.buildTextField(
                  controller: controller.trustRegistrationController,
                  label: controller.selectedEntityType == 'Society'
                      ? 'Society Registration Number'
                      : 'Trust Registration Number',
                  icon: Icons.app_registration_outlined,
                  hint: 'Registration number',
                  required: true,
                ),
                RegisterWidgets.buildTextField(
                  controller: controller.authorizedPersonController,
                  label: 'Authorized Person Name',
                  icon: Icons.person_outline,
                  hint: 'Trustee / Secretary / Authorized person',
                  required: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (controller.needsProprietorName) ...[
            RegisterWidgets.buildTextField(
              controller: controller.proprietorNameController,
              label: 'Proprietor Name',
              icon: Icons.person_outline,
              hint: 'Full name of proprietor',
              required: true,
            ),
            const SizedBox(height: 10),
          ],
          if (controller.needsKartaName) ...[
            RegisterWidgets.buildTextField(
              controller: controller.kartaNameController,
              label: 'Karta Name',
              icon: Icons.person_outline,
              hint: 'Full name of karta',
              required: true,
            ),
            const SizedBox(height: 10),
          ],
          if (controller.needsManagingPartner && !controller.needsFirmRegistration) ...[
            RegisterWidgets.buildTextField(
              controller: controller.managingPartnerController,
              label: 'Managing / Designated Partner Name',
              icon: Icons.person_outline,
              hint: 'Full name',
              required: true,
            ),
            const SizedBox(height: 10),
          ],
          if (controller.needsAuthorizedPerson &&
              !controller.needsTrustRegistration &&
              !controller.needsFirmRegistration) ...[
            RegisterWidgets.buildTextField(
              controller: controller.authorizedPersonController,
              label: 'Authorized Person Name',
              icon: Icons.person_outline,
              hint: 'Director / authorized signatory / manager',
              required: true,
            ),
            const SizedBox(height: 10),
          ],
          RegisterWidgets.buildDropdownField<String>(
            value: controller.selectedRegistrationStatus,
            label: 'Registration Status',
            icon: Icons.assignment_turned_in_outlined,
            items: RegisterConstants.registrationStatuses,
            required: true,
            onChanged: controller.setSelectedRegistrationStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final pageTitle = controller.isEditMode ? 'Edit Workspace' : 'Create Workspace';
    final cardTitle = controller.isEditMode
        ? 'Update your business workspace'
        : 'Create your business workspace';
    final cardSubtitle = controller.isEditMode
        ? 'Keep your workspace profile accurate and ready for operations.'
        : 'Set up your company profile to manage customers, inquiries, quotations and users.';

    return Scaffold(
      backgroundColor: regCanvasBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: regText),
        ),
        title: Text(
          pageTitle,
          style: const TextStyle(
            color: regText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: regBorder),
        ),
      ),
      body: controller.isLoading
          ? RegisterWidgets.buildLoadingView(controller.isEditMode)
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: regBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.045),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RegisterWidgets.buildTopIntro(
                        title: cardTitle,
                        subtitle: cardSubtitle,
                      ),
                      const SizedBox(height: 14),
                      RegisterWidgets.buildWizardHeader(controller),
                      const SizedBox(height: 16),
                      if (controller.currentStep == 0) ...[
                        RegisterWidgets.buildLogoUploadCard(
                          c: controller,
                          onPickLogo: () => controller.pickLogo(
                            onInfo: _showInfo,
                            onError: _showError,
                          ),
                          onRemoveLogo: controller.removeLogo,
                          isLoading: controller.isLoading,
                        ),
                        const SizedBox(height: 16),
                        RegisterWidgets.buildSectionCard(
                          title: 'Entity Information',
                          icon: Icons.business_center_outlined,
                          child: Column(
                            children: [
                              RegisterWidgets.buildResponsiveRow(
                                children: [
                                  RegisterWidgets.buildDropdownField<String>(
                                    value: controller.selectedEntityType,
                                    label: 'Entity Type',
                                    icon: Icons.account_balance_outlined,
                                    items: RegisterConstants.entityTypes,
                                    required: true,
                                    onChanged: controller.setSelectedEntityType,
                                  ),
                                  RegisterWidgets.buildDropdownField<String>(
                                    value: controller.selectedIndustryType,
                                    label: 'Industry Type',
                                    icon: Icons.category_outlined,
                                    items: RegisterConstants.industryTypes,
                                    required: true,
                                    onChanged: controller.setSelectedIndustryType,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              RegisterWidgets.buildDropdownField<String>(
                                value: controller.selectedSubIndustry,
                                label: 'Sub Industry',
                                icon: Icons.account_tree_outlined,
                                items: controller.availableSubIndustries,
                                required: true,
                                onChanged: controller.setSelectedSubIndustry,
                              ),
                              const SizedBox(height: 10),
                              RegisterWidgets.buildTextField(
                                controller: controller.entityNameController,
                                label: 'Entity / Firm Name',
                                icon: Icons.business_outlined,
                                hint: 'e.g. Your Business Name',
                                required: true,
                              ),
                              const SizedBox(height: 10),
                              RegisterWidgets.buildResponsiveRow(
                                children: [
                                  RegisterWidgets.buildTextField(
                                    controller: controller.phoneController,
                                    label: 'Phone Number',
                                    icon: Icons.phone_outlined,
                                    hint: '+91 XXXXX XXXXX',
                                    keyboardType: TextInputType.phone,
                                    required: true,
                                  ),
                                  RegisterWidgets.buildTextField(
                                    controller: controller.websiteController,
                                    label: 'Website',
                                    icon: Icons.language_outlined,
                                    hint: 'www.yourentity.com',
                                    keyboardType: TextInputType.url,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              RegisterWidgets.buildTextField(
                                controller: controller.emailController,
                                label: 'Business Email',
                                icon: Icons.email_outlined,
                                hint: 'info@entity.com',
                                keyboardType: TextInputType.emailAddress,
                                enabled: true,
                                required: true,
                                validator: (val) {
                                  final value = (val ?? '').trim();
                                  if (value.isEmpty) {
                                    return 'Business Email is required';
                                  }
                                  final emailRegex = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  );
                                  if (!emailRegex.hasMatch(value)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              RegisterWidgets.buildDropdownField<String>(
                                value: controller.selectedEmployeeRange,
                                label: 'Total Employees',
                                icon: Icons.groups_2_outlined,
                                items: RegisterConstants.employeeRanges,
                                required: true,
                                onChanged: controller.setSelectedEmployeeRange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildDynamicEntityFields(),
                      ] else ...[
                        RegisterWidgets.buildSectionCard(
                          title: 'Entity Address',
                          icon: Icons.location_on_outlined,
                          child: Column(
                            children: [
                              RegisterWidgets.buildTextField(
                                controller: controller.addressController,
                                label: 'Street Address',
                                icon: Icons.home_outlined,
                                hint: 'Building, street, area',
                                maxLines: 2,
                                required: true,
                              ),
                              const SizedBox(height: 10),
                              RegisterWidgets.buildResponsiveRow(
                                children: [
                                  RegisterWidgets.buildIndiaOnlyField(),
                                  RegisterWidgets.buildDropdownField<String>(
                                    value: controller.selectedStateValue,
                                    label: 'State',
                                    icon: Icons.map_outlined,
                                    items: RegisterConstants.indiaStates,
                                    required: true,
                                    onChanged: controller.setSelectedStateValue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              RegisterWidgets.buildResponsiveRow(
                                children: [
                                  RegisterWidgets.buildTextField(
                                    controller: controller.cityController,
                                    label: 'District / City',
                                    icon: Icons.location_city_outlined,
                                    hint: 'Enter district or city',
                                    required: true,
                                  ),
                                  RegisterWidgets.buildTextField(
                                    controller: controller.pincodeController,
                                    label: 'Pincode / Zip Code',
                                    icon: Icons.pin_drop_outlined,
                                    hint: '400001',
                                    keyboardType: TextInputType.number,
                                    required: true,
                                    validator: (val) {
                                      final value = (val ?? '').trim();
                                      if (value.isEmpty) {
                                        return 'Pincode / Zip Code is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        RegisterWidgets.buildOptionalTaxSection(
                          showTaxInfo: controller.showTaxInfo,
                          onToggle: controller.toggleShowTaxInfo,
                          gstinController: controller.gstinController,
                          panController: controller.panController,
                          buildTextField: RegisterWidgets.buildTextField,
                        ),
                        if (!controller.isEditMode) ...[
                          const SizedBox(height: 14),
                          RegisterWidgets.buildSectionCard(
                            title: 'Security',
                            icon: Icons.lock_outline,
                            child: Column(
                              children: [
                                RegisterWidgets.buildTextField(
                                  controller: controller.passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  hint: 'Minimum 6 characters',
                                  obscureText: controller.obscurePassword,
                                  required: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      controller.obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: regMuted,
                                      size: 19,
                                    ),
                                    onPressed: controller.toggleObscurePassword,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                RegisterWidgets.buildTextField(
                                  controller: controller.confirmPasswordController,
                                  label: 'Confirm Password',
                                  icon: Icons.lock_outline,
                                  hint: 'Re-enter password',
                                  obscureText: controller.obscureConfirmPassword,
                                  required: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      controller.obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: regMuted,
                                      size: 19,
                                    ),
                                    onPressed: controller.toggleObscureConfirmPassword,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: regFieldBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: regBorder),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.lock_open_rounded,
                                        size: 16,
                                        color: regSuccess,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This account will become the primary admin account for your entity workspace.',
                                          style: TextStyle(
                                            color: regMuted,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 18),
                      if (controller.currentStep == 0)
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: regBorder),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: regText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: controller.isLoading
                                      ? null
                                      : () => controller.goToNextStep(
                                    onError: _showError,
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: regSidebarTone,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Next',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: controller.isLoading
                                      ? null
                                      : controller.goToPreviousStep,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: regBorder),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Previous',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: regText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: controller.isLoading
                                      ? null
                                      : () async {
                                    final ok = await controller.saveProfile(
                                      onError: _showError,
                                      onSuccess: _showSuccess,
                                    );
                                    if (ok && mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: regSidebarTone,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    controller.isEditMode
                                        ? 'Save Changes'
                                        : 'Create Workspace',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (!controller.isEditMode) ...[
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'By creating an account, you are setting up a secure entity workspace.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: regMuted,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: RichText(
                              text: const TextSpan(
                                text: 'Already have an account? ',
                                style: TextStyle(
                                  color: regMuted,
                                  fontSize: 13.2,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Login here',
                                    style: TextStyle(
                                      color: regBlue,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildBody(),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}