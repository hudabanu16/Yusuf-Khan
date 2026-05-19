part of '../screens_add_contact.dart';

extension _AddContactLayoutSections on _ScreensAddContactState {
  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
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
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildContactInformationSection(compact: false),
              const SizedBox(height: 16),
              _buildCommunicationDetailsSection(compact: false),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildCompanyRoleSection(),
              const SizedBox(height: 16),
              _buildTipsSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactContactForm() {
    return Column(
      children: [
        _buildContactInformationSection(compact: true),
        const SizedBox(height: 16),
        _buildCommunicationDetailsSection(compact: true),
        const SizedBox(height: 16),
        _buildCompanyRoleSection(),
      ],
    );
  }
}
