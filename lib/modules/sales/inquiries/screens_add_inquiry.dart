import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScreensAddInquiry extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserRole;

  const ScreensAddInquiry({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserRole,
  });

  @override
  State<ScreensAddInquiry> createState() => _ScreensAddInquiryState();
}

class _ScreensAddInquiryState extends State<ScreensAddInquiry> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  String? _selectedContactId;
  String? _selectedSource;
  String? _selectedType;
  String? _selectedPriority;
  String? _selectedStatus;
  String? _assignedToUid;

  DateTime? _nextFollowUpDate;
  DateTime? _expectedClosureDate;

  final _subjectController = TextEditingController();
  final _sourceRefController = TextEditingController();
  final _requiredProductsController = TextEditingController();
  final _quantityController = TextEditingController();
  final _expectedValueController = TextEditingController();
  final _deliveryTimelineController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _internalNotesController = TextEditingController();

  bool _isSaving = false;

  Map<String, dynamic>? _selectedCustomerData;
  Map<String, dynamic>? _selectedContactData;
  Map<String, dynamic>? _assignedUserData;

  bool get _canAssignOthers =>
      widget.currentUserRole == 'admin' || widget.currentUserRole == 'manager';

  CollectionReference<Map<String, dynamic>> get _companyCustomersRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers');

  CollectionReference<Map<String, dynamic>> get _companyUsersRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users');

  CollectionReference<Map<String, dynamic>> get _companyInquiriesRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('inquiries');

  @override
  void initState() {
    super.initState();
    _assignedToUid = widget.currentUserUid;
    _selectedPriority = 'Warm';
    _selectedStatus = 'Open';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _sourceRefController.dispose();
    _requiredProductsController.dispose();
    _quantityController.dispose();
    _expectedValueController.dispose();
    _deliveryTimelineController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  InputDecoration _dec(
      String label, {
        String? hint,
        Widget? prefixIcon,
        Widget? suffixIcon,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF2563EB),
                  size: 20,
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
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
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

  Widget _twoCol({
    required Widget left,
    required Widget right,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              left,
              const SizedBox(height: 14),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _metaPill({
    required String label,
    required IconData icon,
    Color? color,
  }) {
    final tone = color ?? const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: tone.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateInquiryNumber() {
    final now = DateTime.now();
    final yyyy = now.year.toString();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return 'INQ-$yyyy$mm$dd-$hh$min$ss';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _pickDate({
    required DateTime? initialValue,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialValue ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      onPicked(picked);
    }
  }

  Future<void> _loadCustomerData(String customerId) async {
    final doc = await _companyCustomersRef.doc(customerId).get();
    _selectedCustomerData = doc.data();
  }

  Future<void> _loadContactData(String customerId, String contactId) async {
    final doc = await _companyCustomersRef
        .doc(customerId)
        .collection('contacts')
        .doc(contactId)
        .get();
    _selectedContactData = doc.data();
  }

  Future<void> _loadAssignedUserData(String userId) async {
    final doc = await _companyUsersRef.doc(userId).get();
    _assignedUserData = doc.data();
  }

  Future<void> _saveInquiry() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null || _selectedCustomerId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer')),
      );
      return;
    }

    final assignedTo = _canAssignOthers
        ? (_assignedToUid ?? '').trim()
        : widget.currentUserUid;

    if (assignedTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select assigned user')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _loadCustomerData(_selectedCustomerId!);

      if (_selectedContactId != null && _selectedContactId!.isNotEmpty) {
        await _loadContactData(_selectedCustomerId!, _selectedContactId!);
      } else {
        _selectedContactData = null;
      }

      await _loadAssignedUserData(assignedTo);

      final customerData = _selectedCustomerData ?? {};
      final contactData = _selectedContactData ?? {};
      final assignedUserData = _assignedUserData ?? {};

      final customerName =
      (customerData['companyName'] ?? customerData['name'] ?? '')
          .toString()
          .trim();

      final inquiryNumber = _generateInquiryNumber();

      await _companyInquiriesRef.add({
        'companyId': widget.companyId,

        // Inquiry identity
        'inquiryNumber': inquiryNumber,
        'subject': _subjectController.text.trim(),

        // Customer snapshot
        'customerId': _selectedCustomerId,
        'customerName': customerName,

        // Contact snapshot
        'contactId': _selectedContactId ?? '',
        'contactName': (contactData['name'] ?? '').toString().trim(),
        'contactPhone': (contactData['phone'] ?? '').toString().trim(),
        'contactEmail': (contactData['email'] ?? '').toString().trim(),
        'contactDesignation':
        (contactData['designation'] ?? '').toString().trim(),

        // Inquiry details
        'source': (_selectedSource ?? '').trim(),
        'sourceReference': _sourceRefController.text.trim(),
        'channelRef': _sourceRefController.text.trim(),
        'inquiryType': (_selectedType ?? '').trim(),
        'requiredProducts': _requiredProductsController.text.trim(),
        'quantityScope': _quantityController.text.trim(),
        'quantityNote': _quantityController.text.trim(),
        'expectedValue': _expectedValueController.text.trim(),
        'budgetNote': _expectedValueController.text.trim(),
        'deliveryTimeline': _deliveryTimelineController.text.trim(),
        'location': _locationController.text.trim(),
        'notes': _notesController.text.trim(),
        'internalNotes': _internalNotesController.text.trim(),

        // CRM fields
        'priority': (_selectedPriority ?? 'Warm').trim(),
        'status': (_selectedStatus ?? 'Open').trim(),

        // Dates / pipeline
        'nextFollowUpDate': _nextFollowUpDate == null
            ? null
            : Timestamp.fromDate(_nextFollowUpDate!),
        'expectedClosureDate': _expectedClosureDate == null
            ? null
            : Timestamp.fromDate(_expectedClosureDate!),
        'lastFollowUpNote': '',
        'linkedQuotationId': '',

        // Assignment snapshot
        'assignedToUid': assignedTo,
        'assignedToName': (assignedUserData['name'] ?? '').toString().trim(),
        'assignedToRole': (assignedUserData['role'] ?? '').toString().trim(),
        'assignedByUid': widget.currentUserUid,

        // Ownership & audit
        'recordOwnerUid': widget.currentUserUid,
        'createdBy': widget.currentUserUid,
        'createdByUid': widget.currentUserUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.currentUserUid,
        'updatedByUid': widget.currentUserUid,
        'updatedAt': FieldValue.serverTimestamp(),

        // Optional reporting flags
        'isActive': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildCustomerDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companyCustomersRef.orderBy('companyName').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          );
        }

        if (snap.hasError) {
          return Text(
            'Failed to load customers: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final allDocs = snap.data?.docs.toList() ?? [];

        final docs = _canAssignOthers
            ? allDocs
            : allDocs.where((doc) {
          final data = doc.data();
          final createdByUid =
          (data['createdByUid'] ?? data['createdBy'] ?? '')
              .toString()
              .trim();
          final assignedToUid =
          (data['assignedToUid'] ?? '').toString().trim();

          return createdByUid == widget.currentUserUid ||
              assignedToUid == widget.currentUserUid;
        }).toList();

        docs.sort((a, b) {
          final ad = a.data();
          final bd = b.data();
          final an =
          (ad['companyName'] ?? ad['name'] ?? '').toString().toLowerCase();
          final bn =
          (bd['companyName'] ?? bd['name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'No customers found',
              style: TextStyle(color: Color(0xFF92400E)),
            ),
          );
        }

        final safeSelectedValue = docs.any((d) => d.id == _selectedCustomerId)
            ? _selectedCustomerId
            : null;

        return DropdownButtonFormField<String>(
          value: safeSelectedValue,
          decoration: _dec(
            'Select Customer *',
            prefixIcon: const Icon(Icons.apartment_outlined),
          ),
          validator: (value) =>
          value == null || value.trim().isEmpty ? 'Required' : null,
          items: docs.map((doc) {
            final data = doc.data();
            final name = (data['companyName'] ?? data['name'] ?? '').toString();
            return DropdownMenuItem(
              value: doc.id,
              child: Text(name.isEmpty ? '(Unnamed Customer)' : name),
            );
          }).toList(),
          onChanged: (val) async {
            setState(() {
              _selectedCustomerId = val;
              _selectedContactId = null;
              _selectedCustomerData = null;
              _selectedContactData = null;
            });

            if (val != null) {
              await _loadCustomerData(val);
              if (mounted) setState(() {});
            }
          },
        );
      },
    );
  }

  Widget _buildContactDropdown() {
    if (_selectedCustomerId == null || _selectedCustomerId!.trim().isEmpty) {
      return const SizedBox();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companyCustomersRef
          .doc(_selectedCustomerId)
          .collection('contacts')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          );
        }

        if (snap.hasError) {
          return Text(
            'Failed to load contacts: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'No active contacts for selected customer',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          );
        }

        final safeSelectedValue = docs.any((d) => d.id == _selectedContactId)
            ? _selectedContactId
            : null;

        return DropdownButtonFormField<String>(
          value: safeSelectedValue,
          decoration: _dec(
            'Select Contact',
            prefixIcon: const Icon(Icons.person_outline),
          ),
          items: docs.map((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final designation = (data['designation'] ?? '').toString();
            return DropdownMenuItem(
              value: doc.id,
              child: Text(
                designation.isEmpty ? name : '$name ($designation)',
              ),
            );
          }).toList(),
          onChanged: (v) async {
            setState(() {
              _selectedContactId = v;
              _selectedContactData = null;
            });

            if (v != null && _selectedCustomerId != null) {
              await _loadContactData(_selectedCustomerId!, v);
              if (mounted) setState(() {});
            }
          },
        );
      },
    );
  }

  Widget _buildAssignUserDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companyUsersRef.where('isActive', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          );
        }

        if (snap.hasError) {
          return Text(
            'Failed to load users: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final docs = snap.data?.docs.toList() ?? [];
        docs.sort((a, b) {
          final an = (a.data()['name'] ?? '').toString().toLowerCase();
          final bn = (b.data()['name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'No active users found',
              style: TextStyle(color: Color(0xFF92400E)),
            ),
          );
        }

        final safeAssignedValue = docs.any((d) => d.id == _assignedToUid)
            ? _assignedToUid
            : (_canAssignOthers ? null : widget.currentUserUid);

        return DropdownButtonFormField<String>(
          value: safeAssignedValue,
          decoration: _dec(
            'Assign To *',
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
          validator: (value) {
            final finalValue = _canAssignOthers ? value : widget.currentUserUid;
            if (finalValue == null || finalValue.trim().isEmpty) {
              return 'Please select assigned user';
            }
            return null;
          },
          items: docs.map((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final role = (data['role'] ?? '').toString();
            return DropdownMenuItem(
              value: doc.id,
              child: Text(name.isEmpty ? doc.id : '$name ($role)'),
            );
          }).toList(),
          onChanged: _canAssignOthers
              ? (v) async {
            setState(() => _assignedToUid = v);
            if (v != null) {
              await _loadAssignedUserData(v);
              if (mounted) setState(() {});
            }
          }
              : null,
        );
      },
    );
  }

  Widget _buildSelectedPreview() {
    final customerName = (_selectedCustomerData?['companyName'] ??
        _selectedCustomerData?['name'] ??
        '')
        .toString()
        .trim();
    final contactName = (_selectedContactData?['name'] ?? '').toString().trim();
    final contactPhone =
    (_selectedContactData?['phone'] ?? '').toString().trim();
    final contactEmail =
    (_selectedContactData?['email'] ?? '').toString().trim();

    if (customerName.isEmpty && contactName.isEmpty) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (customerName.isNotEmpty)
            Text(
              customerName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF111827),
              ),
            ),
          if (contactName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Contact: $contactName',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ],
          if (contactPhone.isNotEmpty)
            Text(
              'Phone: $contactPhone',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          if (contactEmail.isNotEmpty)
            Text(
              'Email: $contactEmail',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _dec(
          label,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          suffixIcon: value != null
              ? IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
          )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _formatDate(value),
          style: TextStyle(
            fontSize: 14,
            color: value == null
                ? const Color(0xFF6B7280)
                : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignedPreviewName =
    (_assignedUserData?['name'] ?? '').toString().trim();
    final assignedPreviewRole =
    (_assignedUserData?['role'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.white,
        title: const Text(
          'New Inquiry',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveInquiry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save Inquiry'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF1E3A8A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Wrap(
                      runSpacing: 12,
                      spacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Sales Inquiry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Capture requirement, source, ownership and follow-up details in proper CRM format.',
                              style: TextStyle(
                                color: Color(0xFFDCE7FF),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metaPill(
                              label: _selectedStatus ?? 'Open',
                              icon: Icons.flag_outlined,
                              color: const Color(0xFF2563EB),
                            ),
                            _metaPill(
                              label: _selectedPriority ?? 'Warm',
                              icon: Icons.local_fire_department_outlined,
                              color: const Color(0xFFD97706),
                            ),
                            if (assignedPreviewName.isNotEmpty)
                              _metaPill(
                                label: assignedPreviewRole.isEmpty
                                    ? assignedPreviewName
                                    : '$assignedPreviewName ($assignedPreviewRole)',
                                icon: Icons.badge_outlined,
                                color: const Color(0xFF0F766E),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    title: 'Customer & Contact',
                    subtitle:
                    'Select the customer and the contact person related to this inquiry.',
                    icon: Icons.business_center_outlined,
                    child: Column(
                      children: [
                        _buildCustomerDropdown(),
                        const SizedBox(height: 14),
                        if (_selectedCustomerId != null) ...[
                          _buildContactDropdown(),
                          _buildSelectedPreview(),
                        ],
                      ],
                    ),
                  ),

                  _sectionCard(
                    title: 'Inquiry Classification',
                    subtitle:
                    'Capture subject, source, type, priority, status and ownership.',
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        _twoCol(
                          left: TextFormField(
                            controller: _subjectController,
                            decoration: _dec(
                              'Inquiry Subject *',
                              hint:
                              'Example: Requirement for 400A inverter welding machine',
                              prefixIcon: const Icon(Icons.title_outlined),
                            ),
                            validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          right: _buildAssignUserDropdown(),
                        ),
                        const SizedBox(height: 14),
                        if (!_canAssignOthers)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 14),
                              child: Text(
                                'You can create inquiry only for yourself.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        _twoCol(
                          left: DropdownButtonFormField<String>(
                            value: _selectedSource,
                            decoration: _dec(
                              'Inquiry Source',
                              prefixIcon: const Icon(Icons.hub_outlined),
                            ),
                            items: const [
                              'Phone Call',
                              'WhatsApp',
                              'Email',
                              'Visit',
                              'Tender',
                              'Website',
                              'IndiaMART',
                              'Reference',
                              'Exhibition',
                              'Other',
                            ]
                                .map(
                                  (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ),
                            )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedSource = v),
                          ),
                          right: TextFormField(
                            controller: _sourceRefController,
                            decoration: _dec(
                              'Source Reference',
                              hint:
                              'Example: L&T, IndiaMART lead, existing client',
                              prefixIcon: const Icon(Icons.link_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: _dec(
                              'Inquiry Type',
                              prefixIcon: const Icon(Icons.category_outlined),
                            ),
                            items: const ['Product', 'Service', 'Project', 'Both']
                                .map(
                                  (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ),
                            )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedType = v),
                          ),
                          right: DropdownButtonFormField<String>(
                            value: _selectedPriority,
                            decoration: _dec(
                              'Priority',
                              prefixIcon: const Icon(
                                  Icons.local_fire_department_outlined),
                            ),
                            items: const ['Hot', 'Warm', 'Cold']
                                .map(
                                  (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ),
                            )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedPriority = v),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: _dec(
                              'Status',
                              prefixIcon: const Icon(Icons.flag_outlined),
                            ),
                            items: const [
                              'Open',
                              'Qualified',
                              'Quotation Pending',
                              'Quotation Sent',
                              'Follow-up Pending',
                              'Won',
                              'Lost',
                              'Not Qualified',
                            ]
                                .map(
                                  (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ),
                            )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedStatus = v),
                          ),
                          right: _buildDateSelector(
                            label: 'Next Follow-up Date',
                            value: _nextFollowUpDate,
                            onTap: () async {
                              await _pickDate(
                                initialValue: _nextFollowUpDate,
                                onPicked: (date) {
                                  setState(() => _nextFollowUpDate = date);
                                },
                              );
                            },
                            onClear: () {
                              setState(() => _nextFollowUpDate = null);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    title: 'Requirement & Commercial Details',
                    subtitle:
                    'Capture exact requirement, scope, expected value and timeline.',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _requiredProductsController,
                          maxLines: 5,
                          decoration: _dec(
                            'Requirement / Products Needed *',
                            hint:
                            'Write product, model, specs, application, amperage, accessories, quantity requirement, etc.',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 72),
                              child: Icon(Icons.description_outlined),
                            ),
                          ),
                          validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: TextFormField(
                            controller: _quantityController,
                            decoration: _dec(
                              'Quantity / Scope',
                              hint:
                              'Example: 5 machines / 1 line / 200 kg wire',
                              prefixIcon: const Icon(Icons.numbers_outlined),
                            ),
                          ),
                          right: TextFormField(
                            controller: _expectedValueController,
                            keyboardType: TextInputType.number,
                            decoration: _dec(
                              'Expected Deal Value',
                              hint: 'Example: 250000',
                              prefixIcon:
                              const Icon(Icons.currency_rupee_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: TextFormField(
                            controller: _deliveryTimelineController,
                            decoration: _dec(
                              'Delivery Timeline',
                              hint: 'Example: Immediate / 2 weeks / 30 days',
                              prefixIcon:
                              const Icon(Icons.local_shipping_outlined),
                            ),
                          ),
                          right: _buildDateSelector(
                            label: 'Expected Closure Date',
                            value: _expectedClosureDate,
                            onTap: () async {
                              await _pickDate(
                                initialValue: _expectedClosureDate,
                                onPicked: (date) {
                                  setState(() => _expectedClosureDate = date);
                                },
                              );
                            },
                            onClear: () {
                              setState(() => _expectedClosureDate = null);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _locationController,
                          decoration: _dec(
                            'Location / Site',
                            hint: 'Example: Mumbai, Nagothane, Dubai site',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    title: 'Notes & Internal Remarks',
                    subtitle:
                    'Keep follow-up points, customer remarks and internal sales notes.',
                    icon: Icons.sticky_note_2_outlined,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration: _dec(
                            'Customer Notes',
                            hint:
                            'Example: Client needs brochure and urgent quotation by Friday.',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 52),
                              child: Icon(Icons.notes_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _internalNotesController,
                          maxLines: 4,
                          decoration: _dec(
                            'Internal Notes',
                            hint:
                            'Example: Good lead, decision maker involved, competitor is ESAB.',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 52),
                              child: Icon(Icons.lock_outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveInquiry,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Saving...' : 'Save Inquiry'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}