// FILE PATH: lib/modules/crm/contacts/add_contact/add_contact_form_sections.dart
part of '../screens_add_contact.dart';

extension _AddContactFormSections on _ScreensAddContactState {

  Widget _buildIdentitySection({required bool compact}) {
    final statusDropdown = AddContactDropdown(
      label: 'Contact Status',
      value: _contactStatus,
      icon: Icons.toggle_on_outlined,
      items: const ['Active', 'Inactive', 'Left Company', 'Do Not Contact'],
      onChanged: (v) => setState(() => _contactStatus = v!),
    );

    return AddContactSectionCard(
      title: 'Identity & Status',
      subtitle: '',
      icon: Icons.person_outline,
      child: Column(
        children: [
          compact
              ? Column(
            children: [
              AddContactTextField(controller: _nameController, label: 'Full Name', icon: Icons.badge_outlined, isRequired: true),
              const SizedBox(height: 16),
              statusDropdown,
            ],
          )
              : AddContactResponsiveRow(
            children: [
              AddContactTextField(controller: _nameController, label: 'Full Name', icon: Icons.badge_outlined, isRequired: true),
              statusDropdown,
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: _isPrimary ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isPrimary ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
            ),
            child: SwitchListTile(
              title: const Text('Primary Contact', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Main point of contact for this customer', style: TextStyle(fontSize: 12)),
              value: _isPrimary,
              activeColor: const Color(0xFF16A34A),
              onChanged: _setPrimaryContact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection({required bool compact}) {
    final designationField = AddContactTextField(controller: _designationController, label: 'Designation / Job Title', icon: Icons.work_outline);
    final departmentDropdown = AddContactDropdown(
      label: 'Department', value: _department, icon: Icons.account_tree_outlined,
      items: const ['Management', 'Purchase', 'Accounts', 'Sales', 'IT', 'Maintenance', 'Projects', 'Quality', 'Stores', 'Production', 'Other'],
      onChanged: (v) => setState(() => _department = v!),
    );
    final decisionRoleDropdown = AddContactDropdown(
      label: 'Decision Role', value: _decisionRole, icon: Icons.how_to_reg_outlined,
      items: const ['Decision Maker', 'Influencer', 'Evaluator', 'Gatekeeper', 'User', 'Other'],
      onChanged: (v) => setState(() => _decisionRole = v!),
    );
    final authorityDropdown = AddContactDropdown(
      label: 'Authority Level', value: _authorityLevel, icon: Icons.admin_panel_settings_outlined,
      items: const ['C-Level / Board', 'VP / Director', 'Manager / Head', 'Executive / Staff'],
      onChanged: (v) => setState(() => _authorityLevel = v!),
    );

    return AddContactSectionCard(
      title: 'Role & Organization',
      subtitle: '',
      icon: Icons.corporate_fare_outlined,
      child: Column(
        children: [
          if (_companyAddresses.isNotEmpty) ...[
            DropdownButtonFormField<String?>(
              value: _linkedAddressId,
              decoration: InputDecoration(
                labelText: 'Linked Location / Factory',
                labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF94A3B8)),
                filled: true, fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Corporate / Not specific to location', style: TextStyle(fontSize: 14, color: Colors.grey))),
                ..._companyAddresses.map((addr) {
                  final id = addr['id']?.toString() ?? addr['label']?.toString() ?? '';
                  final label = addr['label']?.toString().isNotEmpty == true ? addr['label'].toString() : '${addr['city']}, ${addr['state']}';
                  if (id.isEmpty) return const DropdownMenuItem(value: '', child: SizedBox.shrink());
                  return DropdownMenuItem(value: id, child: Text(label, style: const TextStyle(fontSize: 14)));
                }).where((item) => item.value != ''),
              ],
              onChanged: (val) {
                setState(() {
                  _linkedAddressId = val;
                  if (val != null) {
                    final match = _companyAddresses.firstWhere((a) => a['id'] == val || a['label'] == val, orElse: () => {});
                    _linkedAddressLabel = match['label']?.toString().isNotEmpty == true ? match['label'].toString() : '${match['city']}, ${match['state']}';
                  } else {
                    _linkedAddressLabel = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          compact
              ? Column(children: [designationField, const SizedBox(height: 16), departmentDropdown])
              : AddContactResponsiveRow(children: [designationField, departmentDropdown]),
          const SizedBox(height: 16),
          compact
              ? Column(children: [decisionRoleDropdown, const SizedBox(height: 16), authorityDropdown])
              : AddContactResponsiveRow(children: [decisionRoleDropdown, authorityDropdown]),
          const SizedBox(height: 16),
          AddContactDropdown(
            label: 'Contact Type Category', value: _contactType, icon: Icons.category_outlined,
            items: const ['Commercial', 'Technical', 'Management', 'Service', 'Dispatch', 'Emergency', 'General'],
            onChanged: (v) => setState(() => _contactType = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationSection({required bool compact}) {
    final primaryPhone = AddContactTextField(controller: _phoneController, label: 'Primary Mobile', icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone);
    final altPhone = AddContactTextField(controller: _alternatePhoneController, label: 'Alternate Mobile', icon: Icons.phone_iphone_outlined, keyboardType: TextInputType.phone);
    final officePhone = AddContactTextField(controller: _officePhoneController, label: 'Office Phone (Landline)', icon: Icons.desk_outlined, keyboardType: TextInputType.phone);
    final extension = AddContactTextField(controller: _extensionController, label: 'Extension', icon: Icons.numbers_outlined, keyboardType: TextInputType.phone);
    final email = AddContactTextField(controller: _emailController, label: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress);
    final prefComm = AddContactDropdown(
      label: 'Preferred Communication Mode', value: _preferredComm, icon: Icons.forum_outlined,
      items: const ['Phone', 'WhatsApp', 'Email', 'Any'],
      onChanged: (v) => setState(() => _preferredComm = v!),
    );

    return AddContactSectionCard(
      title: 'Communication & Contacts',
      subtitle: '',
      icon: Icons.contact_phone_outlined,
      child: Column(
        children: [
          compact
              ? Column(children: [primaryPhone, const SizedBox(height: 16), altPhone])
              : AddContactResponsiveRow(children: [primaryPhone, altPhone]),
          const SizedBox(height: 16),
          compact
              ? Column(children: [officePhone, const SizedBox(height: 16), extension])
              : Row(
            children: [
              Expanded(flex: 2, child: officePhone),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: extension),
            ],
          ),
          const SizedBox(height: 16),
          compact
              ? Column(children: [email, const SizedBox(height: 16), prefComm])
              : AddContactResponsiveRow(children: [email, prefComm]),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection({required bool compact}) {
    final linkedin = AddContactTextField(controller: _linkedinController, label: 'LinkedIn Profile URL', icon: Icons.link_outlined, keyboardType: TextInputType.url);
    final assistant = AddContactTextField(controller: _assistantNameController, label: 'Assistant / Secretary Name', icon: Icons.support_agent_outlined);

    return AddContactSectionCard(
      title: 'Additional Information',
      subtitle: '',
      icon: Icons.info_outline,
      child: Column(
        children: [
          compact
              ? Column(children: [linkedin, const SizedBox(height: 16), assistant])
              : AddContactResponsiveRow(children: [linkedin, assistant]),
          const SizedBox(height: 16),
          AddContactTextField(controller: _internalNotesController, label: 'Internal Notes', icon: Icons.note_alt_outlined, maxLines: 3),
          const SizedBox(height: 16),
          AddContactTextField(controller: _escalationNotesController, label: 'Escalation Guidelines / Remarks', icon: Icons.warning_amber_outlined, maxLines: 2),
        ],
      ),
    );
  }
}