import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScreensAddCustomer extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? existingDoc;
  final String companyId;
  final String currentUserUid;
  final String currentUserRole;

  const ScreensAddCustomer({
    super.key,
    this.existingDoc,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserRole,
  });

  @override
  State<ScreensAddCustomer> createState() => _ScreensAddCustomerState();
}

class _ScreensAddCustomerState extends State<ScreensAddCustomer> {
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();

  final _contactNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();

  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');

  final _customerTypeCustomController = TextEditingController();
  final _industryCustomController = TextEditingController();
  final _notesController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _isLoadingExisting = false;

  String? _customerType;
  String? _assignedToUid;
  String? _industry;
  String? _leadSource;
  String? _status;
  String? _priority;
  String? _customerStage;

  String _existingCreatedByUid = '';
  Timestamp? _existingCreatedAt;

  String _currentUserName = '';
  final Map<String, String> _cachedUserNames = {};

  bool get _canAssignOthers {
  final role = widget.currentUserRole.trim().toLowerCase();
  return role == 'director' ||
      role == 'md' ||
      role == 'ceo' ||
      role == 'sales_manager';
}

  bool get _isEdit => widget.existingDoc != null;

  CollectionReference<Map<String, dynamic>> get _customersCol =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers');

  CollectionReference<Map<String, dynamic>> get _companyUsersCol =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users');

  @override
  void initState() {
    super.initState();
    _assignedToUid = widget.currentUserUid;
    _status = 'Active';
    _priority = 'Medium';
    _leadSource = 'Direct';
    _customerStage = 'Potential Customer';
    _loadCurrentUserName();
    _loadExistingCustomer();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _businessEmailController.dispose();
    _websiteController.dispose();
    _gstController.dispose();
    _panController.dispose();

    _contactNameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();

    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();

    _customerTypeCustomController.dispose();
    _industryCustomController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final doc = await _companyUsersCol.doc(widget.currentUserUid).get();
      final data = doc.data() ?? {};
      _currentUserName =
          _extractUserName(data, fallbackUid: widget.currentUserUid);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  String _extractUserName(
      Map<String, dynamic> data, {
        required String fallbackUid,
      }) {
    final name = (data['name'] ??
        data['fullName'] ??
        data['displayName'] ??
        data['userName'] ??
        data['email'] ??
        '')
        .toString()
        .trim();

    return name.isEmpty ? fallbackUid : name;
  }

  Future<void> _loadExistingCustomer() async {
    final docRef = widget.existingDoc;
    if (docRef == null) return;

    setState(() => _isLoadingExisting = true);

    try {
      final snapshot = await docRef.get();
      final data = snapshot.data() ?? {};

      _companyController.text =
          (data['companyName'] ?? data['name'] ?? '').toString();
      _phoneController.text =
          (data['companyPhone'] ?? data['phone'] ?? '').toString();
      _altPhoneController.text = (data['alternatePhone'] ?? '').toString();
      _businessEmailController.text =
          (data['businessEmail'] ?? data['email'] ?? '').toString();
      _websiteController.text = (data['website'] ?? '').toString();
      _gstController.text = (data['gst'] ?? '').toString();
      _panController.text = (data['pan'] ?? '').toString();

      _contactNameController.text = (data['contactName'] ?? '').toString();
      _designationController.text = (data['designation'] ?? '').toString();
      _departmentController.text = (data['department'] ?? '').toString();

      _streetController.text = (data['street'] ?? '').toString();
      _cityController.text = (data['city'] ?? '').toString();
      _stateController.text = (data['state'] ?? '').toString();
      _pincodeController.text = (data['pincode'] ?? '').toString();
      _countryController.text = (data['country'] ?? 'India').toString();

      final savedCustomerType = (data['customerType'] ?? '').toString().trim();
      if (savedCustomerType.isEmpty) {
        _customerType = null;
        _customerTypeCustomController.clear();
      } else if (_customerTypeOptions.contains(savedCustomerType)) {
        _customerType = savedCustomerType;
        _customerTypeCustomController.clear();
      } else {
        _customerType = 'Other';
        _customerTypeCustomController.text = savedCustomerType;
      }

      final savedIndustry = (data['industry'] ?? '').toString().trim();
      if (savedIndustry.isEmpty) {
        _industry = null;
        _industryCustomController.clear();
      } else if (_industryOptions.contains(savedIndustry)) {
        _industry = savedIndustry;
        _industryCustomController.clear();
      } else {
        _industry = 'Other';
        _industryCustomController.text = savedIndustry;
      }

      final sourceValue = (data['leadSource'] ?? '').toString().trim();
      if (sourceValue.isNotEmpty && _leadSourceOptions.contains(sourceValue)) {
        _leadSource = sourceValue;
      }

      final statusValue = (data['status'] ?? '').toString().trim();
      if (statusValue.isNotEmpty && _statusOptions.contains(statusValue)) {
        _status = statusValue;
      }

      final priorityValue = (data['priority'] ?? '').toString().trim();
      if (priorityValue.isNotEmpty && _priorityOptions.contains(priorityValue)) {
        _priority = priorityValue;
      }

      final stageValue =
      (data['customerStage'] ?? 'Potential Customer').toString().trim();
      if (_customerStageOptions.contains(stageValue)) {
        _customerStage = stageValue;
      } else {
        _customerStage = 'Potential Customer';
      }

      _notesController.text = (data['notes'] ?? data['remarks'] ?? '').toString();

      final assigned = (data['assignedToUid'] ?? '').toString().trim();
      if (assigned.isNotEmpty) {
        _assignedToUid = assigned;
      }

      _existingCreatedByUid =
          (data['createdByUid'] ?? data['createdBy'] ?? '').toString();
      _existingCreatedAt = data['createdAt'] as Timestamp?;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load customer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingExisting = false);
      }
    }
  }

  Future<String> _getUserNameByUid(String uid) async {
    if (uid.trim().isEmpty) return '';
    if (_cachedUserNames.containsKey(uid)) return _cachedUserNames[uid]!;

    try {
      final doc = await _companyUsersCol.doc(uid).get();
      final data = doc.data() ?? {};
      final name = _extractUserName(data, fallbackUid: uid);
      _cachedUserNames[uid] = name;
      return name;
    } catch (_) {
      return uid;
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final assignedTo = _canAssignOthers
        ? (_assignedToUid ?? '').trim()
        : widget.currentUserUid;

    if (assignedTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select assigned user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final street = _streetController.text.trim();
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      final pincode = _pincodeController.text.trim();
      final country = _countryController.text.trim();

      final addressParts = <String>[
        street,
        city,
        state,
        pincode,
        country,
      ].where((e) => e.trim().isNotEmpty).toList();

      final combinedAddress = addressParts.join(', ');

      final customType = _customerTypeCustomController.text.trim();
      final customIndustry = _industryCustomController.text.trim();

      final finalCustomerType = _customerType == 'Other'
          ? (customType.isNotEmpty ? customType : 'Other')
          : (_customerType ?? '').trim();

      final finalIndustry = _industry == 'Other'
          ? (customIndustry.isNotEmpty ? customIndustry : 'Other')
          : (_industry ?? '').trim();

      final name = _companyController.text.trim();
      final gst = _gstController.text.trim();

      if (widget.existingDoc == null && gst.isNotEmpty) {
        final dupSnap = await _customersCol
            .where('companyName', isEqualTo: name)
            .where('gst', isEqualTo: gst)
            .limit(1)
            .get();

        if (dupSnap.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This Company Name + GST already exists'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
      }

      final assignedToName = await _getUserNameByUid(assignedTo);
      final currentUserName = _currentUserName.isNotEmpty
          ? _currentUserName
          : await _getUserNameByUid(widget.currentUserUid);

      final nowUpdateData = <String, dynamic>{
        'companyId': widget.companyId,

        'name': name,
        'companyName': name,
        'phone': _phoneController.text.trim(),
        'companyPhone': _phoneController.text.trim(),
        'alternatePhone': _altPhoneController.text.trim(),
        'email': _businessEmailController.text.trim(),
        'businessEmail': _businessEmailController.text.trim(),
        'gst': gst,
        'pan': _panController.text.trim(),
        'website': _websiteController.text.trim(),

        'customerType': finalCustomerType,
        'industry': finalIndustry,
        'leadSource': (_leadSource ?? '').trim(),
        'status': (_status ?? 'Active').trim(),
        'priority': (_priority ?? 'Medium').trim(),
        'customerStage': (_customerStage ?? 'Potential Customer').trim(),

        'address': combinedAddress,
        'street': street,
        'city': city,
        'state': state,
        'pincode': pincode,
        'country': country,

        'contactName': _contactNameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),

        'notes': _notesController.text.trim(),
        'remarks': _notesController.text.trim(),

        'assignedToUid': assignedTo,
        'assignedToName': assignedToName,
        'assignedByUid': widget.currentUserUid,
        'assignedByName': currentUserName,

        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.currentUserUid,
        'updatedByUid': widget.currentUserUid,
        'updatedByName': currentUserName,
      };

      if (widget.existingDoc == null) {
        final companyDocRef = await _customersCol.add({
          ...nowUpdateData,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.currentUserUid,
          'createdByUid': widget.currentUserUid,
          'createdByName': currentUserName,
          'recordOwnerUid': widget.currentUserUid,
          'recordOwnerName': currentUserName,
          'isActive': true,
          'contactsCount': 0,

          'followUpCount': 0,
          'lastFollowUpAt': null,
          'lastFollowUpByUid': '',
          'lastFollowUpByName': '',
          'lastFollowUpMode': '',
          'lastFollowUpSummary': '',
          'lastFollowUpOutcome': '',
          'nextFollowUpDate': null,
        });

        final contactName = _contactNameController.text.trim();
        final contactPhone = _phoneController.text.trim();
        final contactEmail = _businessEmailController.text.trim();

        final hasContactData = contactName.isNotEmpty ||
            _designationController.text.trim().isNotEmpty ||
            _departmentController.text.trim().isNotEmpty ||
            contactPhone.isNotEmpty ||
            contactEmail.isNotEmpty;

        if (hasContactData) {
          await companyDocRef.collection('contacts').add({
            'companyId': widget.companyId,
            'customerId': companyDocRef.id,
            'name': contactName,
            'designation': _designationController.text.trim(),
            'department': _departmentController.text.trim(),
            'phone': contactPhone,
            'email': contactEmail,
            'isPrimary': true,
            'isActive': true,
            'startDate': FieldValue.serverTimestamp(),
            'endDate': null,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': widget.currentUserUid,
            'createdByUid': widget.currentUserUid,
            'createdByName': currentUserName,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': widget.currentUserUid,
            'updatedByName': currentUserName,
          });

          await companyDocRef.update({'contactsCount': 1});
        }
      } else {
        await widget.existingDoc!.update({
          ...nowUpdateData,
          'createdBy': _existingCreatedByUid,
          'createdByUid': _existingCreatedByUid,
          'createdAt': _existingCreatedAt,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingDoc == null
                ? 'Customer created successfully'
                : 'Customer updated successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save customer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAssignUserDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companyUsersCol.where('isActive', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snap.hasError) {
          return Text(
            'Failed to load users: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final docs = snap.data?.docs.toList() ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        docs.sort((a, b) {
          final an = _extractUserName(a.data(), fallbackUid: a.id).toLowerCase();
          final bn = _extractUserName(b.data(), fallbackUid: b.id).toLowerCase();
          return an.compareTo(bn);
        });

        for (final d in docs) {
          _cachedUserNames[d.id] = _extractUserName(d.data(), fallbackUid: d.id);
        }

        if (docs.isEmpty) {
          return const Text('No active users found');
        }

        String? safeAssignedValue;

        final hasAssignedUser = docs.any((doc) => doc.id == _assignedToUid);

        if (hasAssignedUser) {
          safeAssignedValue = _assignedToUid;
        } else if (_canAssignOthers) {
          safeAssignedValue = null;
        } else {
          final currentUserExists =
          docs.any((doc) => doc.id == widget.currentUserUid);
          safeAssignedValue = currentUserExists ? widget.currentUserUid : null;
        }

        return DropdownButtonFormField<String>(
          initialValue: safeAssignedValue,
          decoration: _inputDecoration(
            label: 'Assign to',
            icon: Icons.person_pin_circle_outlined,
          ),
          items: docs.map((doc) {
            final data = doc.data();
            final name = _extractUserName(data, fallbackUid: doc.id);
            final role = (data['role'] ?? '').toString().trim();

            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(
                role.isEmpty ? name : '$name • $role',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _canAssignOthers
              ? (value) {
            setState(() {
              _assignedToUid = value;
            });
          }
              : null,
          validator: (value) {
            final finalValue = _canAssignOthers ? value : widget.currentUserUid;
            if (finalValue == null || finalValue.trim().isEmpty) {
              return 'Please select assigned user';
            }
            return null;
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 16,
        title: Text(_isEdit ? 'Edit Customer' : 'Add Customer'),
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 980;

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _buildAccountSection(),
                                    const SizedBox(height: 14),
                                    _buildPrimaryContactSection(),
                                    const SizedBox(height: 14),
                                    _buildAddressSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildClassificationSection(),
                                    const SizedBox(height: 14),
                                    _buildAssignmentSection(),
                                    const SizedBox(height: 14),
                                    _buildNotesSection(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _buildAccountSection(),
                            const SizedBox(height: 14),
                            _buildClassificationSection(),
                            const SizedBox(height: 14),
                            _buildAssignmentSection(),
                            const SizedBox(height: 14),
                            _buildPrimaryContactSection(),
                            const SizedBox(height: 14),
                            _buildAddressSection(),
                            const SizedBox(height: 14),
                            _buildNotesSection(),
                          ],
                        );
                      },
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

  Widget _buildAccountSection() {
    return _SectionBlock(
      title: 'Account Details',
      subtitle: 'Business identity and contact channels',
      child: Column(
        children: [
          _buildResponsiveRow(
            children: [
              _buildTextField(
                controller: _companyController,
                label: 'Company / Firm Name *',
                icon: Icons.apartment_outlined,
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              _buildTextField(
                controller: _websiteController,
                label: 'Website',
                icon: Icons.language_outlined,
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(
                controller: _phoneController,
                label: 'Primary Phone *',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              _buildTextField(
                controller: _altPhoneController,
                label: 'Alternate Phone',
                icon: Icons.local_phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(
                controller: _businessEmailController,
                label: 'Business Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final email = (v ?? '').trim();
                  if (email.isEmpty) return null;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter valid email';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _gstController,
                label: 'GST',
                icon: Icons.receipt_long_outlined,
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(
                controller: _panController,
                label: 'PAN',
                icon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationSection() {
    return _SectionBlock(
      title: 'CRM Classification',
      subtitle: 'Standard segmentation and lifecycle fields',
      child: Column(
        children: [
          _buildResponsiveRow(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _customerStage,
                decoration: _inputDecoration(
                  label: 'Customer Stage',
                  icon: Icons.account_tree_outlined,
                ),
                items: _customerStageOptions
                    .map(
                      (t) => DropdownMenuItem<String>(
                    value: t,
                    child: Text(t),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() => _customerStage = value);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _customerType,
                decoration: _inputDecoration(
                  label: 'Customer Type',
                  icon: Icons.groups_2_outlined,
                ),
                items: _customerTypeOptions
                    .map(
                      (t) => DropdownMenuItem<String>(
                    value: t,
                    child: Text(t, overflow: TextOverflow.ellipsis),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _customerType = value;
                    if (value != 'Other') {
                      _customerTypeCustomController.clear();
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _industry,
                decoration: _inputDecoration(
                  label: 'Industry',
                  icon: Icons.factory_outlined,
                ),
                items: _industryOptions
                    .map(
                      (t) => DropdownMenuItem<String>(
                    value: t,
                    child: Text(t, overflow: TextOverflow.ellipsis),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _industry = value;
                    if (value != 'Other') {
                      _industryCustomController.clear();
                    }
                  });
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _leadSource,
                decoration: _inputDecoration(
                  label: 'Lead Source',
                  icon: Icons.campaign_outlined,
                ),
                items: _leadSourceOptions
                    .map(
                      (t) => DropdownMenuItem<String>(
                    value: t,
                    child: Text(t),
                  ),
                )
                    .toList(),
                onChanged: (value) => setState(() => _leadSource = value),
              ),
            ],
          ),
          if (_customerType == 'Other' || _industry == 'Other') ...[
            const SizedBox(height: 12),
            _buildResponsiveRow(
              children: [
                _customerType == 'Other'
                    ? _buildTextField(
                  controller: _customerTypeCustomController,
                  label: 'Custom Customer Type',
                  icon: Icons.edit_outlined,
                )
                    : const SizedBox.shrink(),
                _industry == 'Other'
                    ? _buildTextField(
                  controller: _industryCustomController,
                  label: 'Custom Industry',
                  icon: Icons.tune_outlined,
                )
                    : const SizedBox.shrink(),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _inputDecoration(
                  label: 'Status',
                  icon: Icons.verified_user_outlined,
                ),
                items: _statusOptions
                    .map(
                      (t) => DropdownMenuItem<String>(
                    value: t,
                    child: Text(t),
                  ),
                )
                    .toList(),
                onChanged: (value) => setState(() => _status = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: _inputDecoration(
                  label: 'Priority',
                  icon: Icons.flag_outlined,
                ),
                items: _priorityOptions
                    .map(
                      (t) => DropdownMenuItem<String>(
                    value: t,
                    child: Text(t),
                  ),
                )
                    .toList(),
                onChanged: (value) => setState(() => _priority = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentSection() {
    return _SectionBlock(
      title: 'Ownership & Assignment',
      subtitle: 'Who owns and manages this customer record',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssignUserDropdown(),
          if (!_canAssignOthers) ...[
            const SizedBox(height: 10),
            Text(
              'You can create customer only for yourself.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryContactSection() {
    return _SectionBlock(
      title: 'Primary Contact',
      subtitle: 'Main person linked with this account',
      child: Column(
        children: [
          _buildTextField(
            controller: _contactNameController,
            label: 'Contact Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(
                controller: _designationController,
                label: 'Designation',
                icon: Icons.badge_outlined,
              ),
              _buildTextField(
                controller: _departmentController,
                label: 'Department',
                icon: Icons.account_tree_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return _SectionBlock(
      title: 'Business Address',
      subtitle: 'Registered or operating location',
      child: Column(
        children: [
          _buildTextField(
            controller: _streetController,
            label: 'Street Address',
            icon: Icons.home_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(
                controller: _cityController,
                label: 'City *',
                icon: Icons.location_city_outlined,
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              _buildTextField(
                controller: _stateController,
                label: 'State',
                icon: Icons.map_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(
                controller: _pincodeController,
                label: 'Pincode',
                icon: Icons.markunread_mailbox_outlined,
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                controller: _countryController,
                label: 'Country',
                icon: Icons.public_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _SectionBlock(
      title: 'Internal Notes',
      subtitle: 'Sales context, remarks or follow-up notes',
      child: _buildTextField(
        controller: _notesController,
        label: 'Notes / Remarks',
        icon: Icons.edit_note_outlined,
        maxLines: 5,
      ),
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit
                        ? 'Update the customer record after reviewing the details.'
                        : 'Save this new customer record to CRM.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 170,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCustomer,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                        : Icon(
                      _isEdit
                          ? Icons.save_outlined
                          : Icons.add_circle_outline,
                      size: 18,
                    ),
                    label: Text(_isEdit ? 'Update' : 'Save Customer'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildResponsiveRow({
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 700;

        if (isStacked) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade600, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
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
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label: label, icon: icon),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionBlock({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

const List<String> _customerStageOptions = [
  'Potential Customer',
  'Existing Customer',
];

const List<String> _customerTypeOptions = [
  'End Customer',
  'Distributor',
  'Dealer',
  'Channel Partner',
  'OEM',
  'System Integrator',
  'Contractor',
  'Fabricator',
  'Manufacturer',
  'Consultant',
  'Government',
  'Public Sector',
  'Educational Institution',
  'Service Provider',
  'Retailer',
  'Trader',
  'Other',
];

const List<String> _industryOptions = [
  'Automotive',
  'Aerospace & Defense',
  'Construction',
  'Engineering',
  'Energy & Power',
  'EPC',
  'Fabrication',
  'Food & Beverage',
  'Healthcare & Medical',
  'Infrastructure',
  'Manufacturing',
  'Marine & Shipbuilding',
  'Metal & Steel',
  'Mining',
  'Oil & Gas',
  'Pharmaceuticals',
  'Railways',
  'Renewable Energy',
  'Textiles',
  'Trading',
  'Utilities',
  'Warehousing & Logistics',
  'Other',
];

const List<String> _leadSourceOptions = [
  'Direct',
  'Reference',
  'Website',
  'WhatsApp',
  'Email Campaign',
  'Phone Call',
  'Sales Visit',
  'Exhibition',
  'Distributor',
  'Digital Marketing',
  'Marketplace',
  'Tender',
  'Other',
];

const List<String> _statusOptions = [
  'Active',
  'Prospect',
  'Lead',
  'Dormant',
  'Blocked',
];

const List<String> _priorityOptions = [
  'Low',
  'Medium',
  'High',
  'Critical',
];