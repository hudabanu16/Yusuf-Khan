import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ScreensAddContact extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentSnapshot<Map<String, dynamic>>? contactDoc;

  const ScreensAddContact({
    super.key,
    required this.companyRef,
    this.contactDoc,
  });

  @override
  State<ScreensAddContact> createState() => _ScreensAddContactState();
}

class _ScreensAddContactState extends State<ScreensAddContact> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isPrimary = false;
  bool _isSaving = false;
  bool _isLoadingCompany = true;

  String _companyName = '';
  String _companyLocation = '';

  CollectionReference<Map<String, dynamic>> get _contactsRef =>
      widget.companyRef.collection('contacts');

  bool get _isEdit => widget.contactDoc != null;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();

    final doc = widget.contactDoc;
    if (doc != null) {
      final data = doc.data() ?? {};

      _nameController.text = (data['name'] ?? '').toString();
      _designationController.text = (data['designation'] ?? '').toString();
      _departmentController.text = (data['department'] ?? '').toString();
      _emailController.text = (data['email'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      _isPrimary = data['isPrimary'] == true;
    }
  }

  Future<void> _loadCompanyInfo() async {
    try {
      final snapshot = await widget.companyRef.get();
      final data = snapshot.data() ?? {};

      final companyName =
      (data['companyName'] ?? data['name'] ?? '').toString();

      final city = (data['city'] ?? '').toString().trim();
      final state = (data['state'] ?? '').toString().trim();

      String location = '';
      if (city.isNotEmpty && state.isNotEmpty) {
        location = '$city, $state';
      } else if (city.isNotEmpty) {
        location = city;
      } else if (state.isNotEmpty) {
        location = state;
      }

      if (!mounted) return;
      setState(() {
        _companyName = companyName;
        _companyLocation = location;
        _isLoadingCompany = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCompany = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _unsetOtherPrimaryContacts() async {
    final existingContacts = await _contactsRef.get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in existingContacts.docs) {
      final isSameDoc =
          widget.contactDoc != null && doc.id == widget.contactDoc!.id;
      if (isSameDoc) continue;

      final data = doc.data();
      if (data['isPrimary'] == true) {
        batch.update(doc.reference, {
          'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isPrimary) {
        await _unsetOtherPrimaryContacts();
      }

      final baseData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'isPrimary': _isPrimary,
        'isActive': true,
      };

      if (widget.contactDoc == null) {
        await _contactsRef.add({
          ...baseData,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.uid,
          'createdByUid': currentUser.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUser.uid,
          'updatedByUid': currentUser.uid,
        });
      } else {
        await widget.contactDoc!.reference.update({
          ...baseData,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUser.uid,
          'updatedByUid': currentUser.uid,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.contactDoc == null ? 'Contact created' : 'Contact updated',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save contact: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.shade600, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label: label, icon: icon),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _buildResponsiveRow({
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 700;

        if (stacked) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Contact' : 'Add Contact'),
      ),
      body: _isLoadingCompany
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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

                            if (isWide) {
                              return Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        _SectionCard(
                                          title: 'Contact Information',
                                          subtitle:
                                          'Basic details of the person',
                                          icon: Icons.person_outline,
                                          child: Column(
                                            children: [
                                              _buildTextField(
                                                controller:
                                                _nameController,
                                                label: 'Contact Name *',
                                                icon: Icons.person_outline,
                                                validator: (v) =>
                                                v == null ||
                                                    v.trim()
                                                        .isEmpty
                                                    ? 'Required'
                                                    : null,
                                              ),
                                              const SizedBox(height: 14),
                                              _buildResponsiveRow(
                                                children: [
                                                  _buildTextField(
                                                    controller:
                                                    _designationController,
                                                    label: 'Designation',
                                                    icon: Icons
                                                        .badge_outlined,
                                                  ),
                                                  _buildTextField(
                                                    controller:
                                                    _departmentController,
                                                    label: 'Department',
                                                    icon: Icons
                                                        .account_tree_outlined,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _SectionCard(
                                          title: 'Communication Details',
                                          subtitle:
                                          'Official contact information',
                                          icon: Icons.call_outlined,
                                          child: Column(
                                            children: [
                                              _buildResponsiveRow(
                                                children: [
                                                  _buildTextField(
                                                    controller:
                                                    _emailController,
                                                    label: 'Email',
                                                    icon: Icons
                                                        .email_outlined,
                                                    keyboardType:
                                                    TextInputType
                                                        .emailAddress,
                                                    validator: (v) {
                                                      final text = (v ?? '')
                                                          .trim();
                                                      if (text.isEmpty) {
                                                        return null;
                                                      }
                                                      if (!RegExp(
                                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                                      ).hasMatch(text)) {
                                                        return 'Enter valid email';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                  _buildTextField(
                                                    controller:
                                                    _phoneController,
                                                    label: 'Phone',
                                                    icon: Icons
                                                        .phone_outlined,
                                                    keyboardType:
                                                    TextInputType
                                                        .phone,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        _SectionCard(
                                          title: 'Role in Company',
                                          subtitle:
                                          'Use this to mark key point of contact',
                                          icon: Icons
                                              .verified_user_outlined,
                                          child: Column(
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                const EdgeInsets.all(
                                                    14),
                                                decoration: BoxDecoration(
                                                  color:
                                                  _isPrimary
                                                      ? Colors.green
                                                      .shade50
                                                      : Colors.grey
                                                      .shade50,
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(14),
                                                  border: Border.all(
                                                    color:
                                                    _isPrimary
                                                        ? Colors.green
                                                        .shade200
                                                        : Colors.grey
                                                        .shade300,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Checkbox(
                                                      value: _isPrimary,
                                                      onChanged: (v) {
                                                        setState(() {
                                                          _isPrimary =
                                                              v ?? false;
                                                        });
                                                      },
                                                    ),
                                                    const SizedBox(
                                                        width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                        children: [
                                                          const Text(
                                                            'Primary contact for this company',
                                                            style:
                                                            TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .w700,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            _isPrimary
                                                                ? 'This contact will become the main company contact.'
                                                                : 'Enable this if this person is the main point of contact.',
                                                            style:
                                                            TextStyle(
                                                              fontSize:
                                                              12.5,
                                                              color: Colors
                                                                  .grey
                                                                  .shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _SectionCard(
                                          title: 'Tips',
                                          subtitle:
                                          'Recommended CRM usage',
                                          icon: Icons.lightbulb_outline,
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: const [
                                              _TipLine(
                                                text:
                                                'Use official company email whenever possible.',
                                              ),
                                              SizedBox(height: 8),
                                              _TipLine(
                                                text:
                                                'Mark only one contact as primary for cleaner CRM data.',
                                              ),
                                              SizedBox(height: 8),
                                              _TipLine(
                                                text:
                                                'Add designation and department for better follow-up tracking.',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                _SectionCard(
                                  title: 'Contact Information',
                                  subtitle:
                                  'Basic details of the person',
                                  icon: Icons.person_outline,
                                  child: Column(
                                    children: [
                                      _buildTextField(
                                        controller: _nameController,
                                        label: 'Contact Name *',
                                        icon: Icons.person_outline,
                                        validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Required'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildTextField(
                                        controller:
                                        _designationController,
                                        label: 'Designation',
                                        icon: Icons.badge_outlined,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildTextField(
                                        controller:
                                        _departmentController,
                                        label: 'Department',
                                        icon:
                                        Icons.account_tree_outlined,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _SectionCard(
                                  title: 'Communication Details',
                                  subtitle:
                                  'Official contact information',
                                  icon: Icons.call_outlined,
                                  child: Column(
                                    children: [
                                      _buildTextField(
                                        controller: _emailController,
                                        label: 'Email',
                                        icon: Icons.email_outlined,
                                        keyboardType:
                                        TextInputType.emailAddress,
                                        validator: (v) {
                                          final text =
                                          (v ?? '').trim();
                                          if (text.isEmpty) {
                                            return null;
                                          }
                                          if (!RegExp(
                                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                          ).hasMatch(text)) {
                                            return 'Enter valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildTextField(
                                        controller: _phoneController,
                                        label: 'Phone',
                                        icon: Icons.phone_outlined,
                                        keyboardType:
                                        TextInputType.phone,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _SectionCard(
                                  title: 'Role in Company',
                                  subtitle:
                                  'Use this to mark key point of contact',
                                  icon:
                                  Icons.verified_user_outlined,
                                  child: Container(
                                    width: double.infinity,
                                    padding:
                                    const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: _isPrimary
                                          ? Colors.green.shade50
                                          : Colors.grey.shade50,
                                      borderRadius:
                                      BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _isPrimary
                                            ? Colors.green.shade200
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _isPrimary,
                                          onChanged: (v) {
                                            setState(() {
                                              _isPrimary = v ?? false;
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                            children: [
                                              const Text(
                                                'Primary contact for this company',
                                                style: TextStyle(
                                                  fontWeight:
                                                  FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _isPrimary
                                                    ? 'This contact will become the main company contact.'
                                                    : 'Enable this if this person is the main point of contact.',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: Colors
                                                      .grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomSaveBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.indigo.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              color: Colors.white,
              size: 28,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Update Contact Record' : 'Create New Contact',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _companyName.isEmpty
                    ? 'Manage customer contact details professionally'
                    : 'Company: $_companyName${_companyLocation.isNotEmpty ? " • $_companyLocation" : ""}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isPrimary) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'Primary Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit
                        ? 'Review the details and update this contact record.'
                        : 'Review the details and save this new contact record.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 170,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                        : Icon(
                      _isEdit
                          ? Icons.save_outlined
                          : Icons.add_circle_outline,
                    ),
                    label: Text(_isEdit ? 'Update' : 'Save Contact'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade50,
                child: Icon(
                  icon,
                  size: 20,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  final String text;

  const _TipLine({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}