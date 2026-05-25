// FILE PATH: lib/modules/crm/contacts/add_contact/add_contact_layout_sections.dart
part of '../screens_add_contact.dart';

extension _AddContactLayoutSections on _ScreensAddContactState {
  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 860;
                  return isWide
                      ? _buildWideContactForm()
                      : _buildCompactContactForm();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideContactForm() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column
        Expanded(
          flex: 11,
          child: Column(
            children: [
              _buildIdentitySection(compact: false),
              const SizedBox(height: 24),
              _buildCommunicationSection(compact: false),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column
        Expanded(
          flex: 9,
          child: Column(
            children: [
              _buildRoleSection(compact: true),
              const SizedBox(height: 24),
              _buildAdditionalInfoSection(compact: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactContactForm() {
    return Column(
      children: [
        _buildIdentitySection(compact: true),
        const SizedBox(height: 24),
        _buildRoleSection(compact: true),
        const SizedBox(height: 24),
        _buildCommunicationSection(compact: true),
        const SizedBox(height: 24),
        _buildAdditionalInfoSection(compact: true),
      ],
    );
  }
}