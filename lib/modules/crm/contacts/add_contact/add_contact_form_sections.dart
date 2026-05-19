part of '../screens_add_contact.dart';

extension _AddContactFormSections on _ScreensAddContactState {
  Widget _buildContactInformationSection({required bool compact}) {
    final designationField = AddContactTextField(
      controller: _designationController,
      label: 'Designation',
      icon: Icons.badge_outlined,
    );
    final departmentField = AddContactTextField(
      controller: _departmentController,
      label: 'Department',
      icon: Icons.account_tree_outlined,
    );

    return AddContactSectionCard(
      title: 'Contact Information',
      subtitle: 'Basic details of the person',
      icon: Icons.person_outline,
      child: Column(
        children: [
          AddContactTextField(
            controller: _nameController,
            label: 'Contact Name *',
            icon: Icons.person_outline,
            validator: _validateRequiredContactName,
          ),
          const SizedBox(height: 14),
          if (compact) ...[
            designationField,
            const SizedBox(height: 14),
            departmentField,
          ] else
            AddContactResponsiveRow(
              children: [designationField, departmentField],
            ),
        ],
      ),
    );
  }

  Widget _buildCommunicationDetailsSection({required bool compact}) {
    final emailField = AddContactTextField(
      controller: _emailController,
      label: 'Email',
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      validator: _validateOptionalEmail,
    );
    final phoneField = AddContactTextField(
      controller: _phoneController,
      label: 'Phone',
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
    );

    return AddContactSectionCard(
      title: 'Communication Details',
      subtitle: 'Official contact information',
      icon: Icons.call_outlined,
      child: compact
          ? Column(
              children: [emailField, const SizedBox(height: 14), phoneField],
            )
          : AddContactResponsiveRow(children: [emailField, phoneField]),
    );
  }

  Widget _buildCompanyRoleSection() {
    return AddContactSectionCard(
      title: 'Role in Company',
      subtitle: 'Use this to mark key point of contact',
      icon: Icons.verified_user_outlined,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isPrimary ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isPrimary ? Colors.green.shade200 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Checkbox(value: _isPrimary, onChanged: _setPrimaryContact),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Primary contact for this company',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isPrimary
                        ? 'This contact will become the main company contact.'
                        : 'Enable this if this person is the main point of contact.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsSection() {
    return const AddContactSectionCard(
      title: 'Tips',
      subtitle: 'Recommended CRM usage',
      icon: Icons.lightbulb_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddContactTipLine(
            text: 'Use official company email whenever possible.',
          ),
          SizedBox(height: 8),
          AddContactTipLine(
            text: 'Mark only one contact as primary for cleaner CRM data.',
          ),
          SizedBox(height: 8),
          AddContactTipLine(
            text:
                'Add designation and department for better follow-up tracking.',
          ),
        ],
      ),
    );
  }

  String? _validateRequiredContactName(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _validateOptionalEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter valid email';
    }
    return null;
  }
}
