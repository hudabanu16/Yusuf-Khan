import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/models/inquiry_model.dart';

class ScreensInquiryForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? existingDoc;
  final Inquiry? existingInquiry;

  /// kept for compatibility
  final String currentUserId;

  const ScreensInquiryForm({
    super.key,
    required this.existingDoc,
    required this.existingInquiry,
    required this.currentUserId,
  });

  @override
  State<ScreensInquiryForm> createState() => _ScreensInquiryFormState();
}

class _ScreensInquiryFormState extends State<ScreensInquiryForm> {
  final _formKey = GlobalKey<FormState>();

  final _subjectController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _sourceRefController = TextEditingController();
  final _requiredProductsController = TextEditingController();
  final _quantityScopeController = TextEditingController();
  final _expectedValueController = TextEditingController();
  final _deliveryTimelineController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _internalNotesController = TextEditingController();
  final _lastFollowUpNoteController = TextEditingController();
  final _linkedQuotationIdController = TextEditingController();

  String _priority = 'Warm';
  String _status = 'Open';
  String _source = '';
  String _inquiryType = '';
  String? _assignedToUid;
  String _assignedToName = '';
  String _assignedToRole = '';

  bool _saving = false;
  bool _canManageAssignment = false;
  String? _companyId;

  DateTime? _nextFollowUpDate;
  DateTime? _expectedClosureDate;

  Map<String, dynamic>? _existingRawData;

  bool get _isEditing => widget.existingDoc != null;

  @override
  void initState() {
    super.initState();
    _hydrateFromInquiry();
    _loadExtraData();
  }

  void _hydrateFromInquiry() {
    final iq = widget.existingInquiry;
    if (iq == null) return;

    _subjectController.text = iq.subject;
    _customerNameController.text = iq.customerName;
    _contactNameController.text = iq.contactName;
    _contactPhoneController.text = iq.contactPhone;
    _contactEmailController.text = iq.contactEmail;
    _sourceRefController.text = iq.sourceReference;
    _requiredProductsController.text = iq.requiredProducts;
    _quantityScopeController.text = iq.quantityScope;
    _expectedValueController.text = iq.expectedValue;
    _deliveryTimelineController.text = iq.deliveryTimeline;
    _locationController.text = iq.location;
    _notesController.text = iq.notes;
    _internalNotesController.text = iq.internalNotes;
    _lastFollowUpNoteController.text = iq.lastFollowUpNote;
    _linkedQuotationIdController.text = iq.linkedQuotationId;

    _priority = iq.priority.isEmpty ? 'Warm' : iq.priority;
    _status = iq.status.isEmpty ? 'Open' : iq.status;
    _source = iq.source;
    _inquiryType = iq.inquiryType;
    _assignedToUid = iq.assignedToUid.isEmpty ? null : iq.assignedToUid;
    _assignedToName = iq.assignedToName;
    _assignedToRole = iq.assignedToRole;
    _companyId = iq.companyId.isEmpty ? null : iq.companyId;
    _nextFollowUpDate = iq.nextFollowUpDate;
    _expectedClosureDate = iq.expectedClosureDate;
  }

  Future<void> _loadExtraData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final rootUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final rootUserData = rootUserDoc.data() ?? {};
      final role = (rootUserData['role'] ?? '').toString().trim();
      _canManageAssignment = role == 'admin' || role == 'manager';

      _companyId = _firstNonEmpty([
        _companyId,
        rootUserData['companyId'],
      ]);

      if (widget.existingDoc != null) {
        final existingSnap = await widget.existingDoc!.get();
        final data = existingSnap.data() ?? {};
        _existingRawData = data;

        _companyId = _firstNonEmpty([
          data['companyId'],
          _companyId,
        ]);

        final assignedTo = (data['assignedToUid'] ?? '').toString().trim();
        _assignedToUid = assignedTo.isEmpty ? _assignedToUid : assignedTo;

        _assignedToName = _firstNonEmpty([
          data['assignedToName'],
          _assignedToName,
        ]);

        _assignedToRole = _firstNonEmpty([
          data['assignedToRole'],
          _assignedToRole,
        ]);

        _subjectController.text = _firstNonEmpty([
          data['subject'],
          _subjectController.text,
        ]);

        _customerNameController.text = _firstNonEmpty([
          data['customerName'],
          _customerNameController.text,
        ]);

        _contactNameController.text = _firstNonEmpty([
          data['contactName'],
          _contactNameController.text,
        ]);

        _contactPhoneController.text = _firstNonEmpty([
          data['contactPhone'],
          _contactPhoneController.text,
        ]);

        _contactEmailController.text = _firstNonEmpty([
          data['contactEmail'],
          _contactEmailController.text,
        ]);

        _sourceRefController.text = _firstNonEmpty([
          data['sourceReference'],
          data['channelRef'],
          _sourceRefController.text,
        ]);

        _quantityScopeController.text = _firstNonEmpty([
          data['quantityScope'],
          data['quantityNote'],
          _quantityScopeController.text,
        ]);

        _expectedValueController.text = _firstNonEmpty([
          data['expectedValue'],
          data['budgetNote'],
          _expectedValueController.text,
        ]);

        _requiredProductsController.text = _firstNonEmpty([
          data['requiredProducts'],
          _requiredProductsController.text,
        ]);

        _deliveryTimelineController.text = _firstNonEmpty([
          data['deliveryTimeline'],
          _deliveryTimelineController.text,
        ]);

        _locationController.text = _firstNonEmpty([
          data['location'],
          _locationController.text,
        ]);

        _notesController.text = _firstNonEmpty([
          data['notes'],
          _notesController.text,
        ]);

        _internalNotesController.text = _firstNonEmpty([
          data['internalNotes'],
          _internalNotesController.text,
        ]);

        _lastFollowUpNoteController.text = _firstNonEmpty([
          data['lastFollowUpNote'],
          _lastFollowUpNoteController.text,
        ]);

        _linkedQuotationIdController.text = _firstNonEmpty([
          data['linkedQuotationId'],
          _linkedQuotationIdController.text,
        ]);

        _source = _firstNonEmpty([
          data['source'],
          _source,
        ]);

        _inquiryType = _firstNonEmpty([
          data['inquiryType'],
          _inquiryType,
        ]);

        final nextFollowUpTs = data['nextFollowUpDate'] as Timestamp?;
        final expectedClosureTs = data['expectedClosureDate'] as Timestamp?;

        _nextFollowUpDate = nextFollowUpTs?.toDate() ?? _nextFollowUpDate;
        _expectedClosureDate =
            expectedClosureTs?.toDate() ?? _expectedClosureDate;

        _priority = _firstNonEmpty([
          data['priority'],
          _priority,
        ]);

        _status = _firstNonEmpty([
          data['status'],
          _status,
        ]);
      }

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _customerNameController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _sourceRefController.dispose();
    _requiredProductsController.dispose();
    _quantityScopeController.dispose();
    _expectedValueController.dispose();
    _deliveryTimelineController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _internalNotesController.dispose();
    _lastFollowUpNoteController.dispose();
    _linkedQuotationIdController.dispose();
    super.dispose();
  }

  Future<void> _pickNextFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextFollowUpDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _nextFollowUpDate = picked);
    }
  }

  Future<void> _pickExpectedClosureDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedClosureDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _expectedClosureDate = picked);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Not selected';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _dec(
        label,
        hint: hint,
        prefixIcon: prefixIcon,
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        return null;
      },
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
    bool textWhite = false,
  }) {
    final tone = color ?? const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withOpacity(textWhite ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textWhite ? Colors.white : tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textWhite ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onSelect,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _dec(
          label,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          suffixIcon: value == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
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

  Future<Map<String, String>> _loadAssignedUserMeta(String uid) async {
    if (_companyId == null || _companyId!.isEmpty) {
      return {'name': '', 'role': ''};
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data() ?? {};
      return {
        'name': (data['name'] ?? '').toString().trim(),
        'role': (data['role'] ?? '').toString().trim(),
      };
    } catch (_) {
      return {'name': '', 'role': ''};
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      String assignedToName = _assignedToName;
      String assignedToRole = _assignedToRole;

      if (_canManageAssignment &&
          _assignedToUid != null &&
          _assignedToUid!.trim().isNotEmpty) {
        final userMeta = await _loadAssignedUserMeta(_assignedToUid!.trim());
        assignedToName = userMeta['name'] ?? '';
        assignedToRole = userMeta['role'] ?? '';
      }

      final editableData = <String, dynamic>{
        'subject': _subjectController.text.trim(),

        'customerName': _customerNameController.text.trim(),
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'contactEmail': _contactEmailController.text.trim(),

        'source': _source.trim(),
        'sourceReference': _sourceRefController.text.trim(),
        'channelRef': _sourceRefController.text.trim(),

        'inquiryType': _inquiryType.trim(),

        'requiredProducts': _requiredProductsController.text.trim(),

        'quantityScope': _quantityScopeController.text.trim(),
        'quantityNote': _quantityScopeController.text.trim(),

        'expectedValue': _expectedValueController.text.trim(),
        'budgetNote': _expectedValueController.text.trim(),

        'deliveryTimeline': _deliveryTimelineController.text.trim(),
        'location': _locationController.text.trim(),

        'notes': _notesController.text.trim(),
        'internalNotes': _internalNotesController.text.trim(),
        'lastFollowUpNote': _lastFollowUpNoteController.text.trim(),

        'priority': _priority,
        'status': _status,

        'nextFollowUpDate': _nextFollowUpDate == null
            ? null
            : Timestamp.fromDate(_nextFollowUpDate!),
        'expectedClosureDate': _expectedClosureDate == null
            ? null
            : Timestamp.fromDate(_expectedClosureDate!),

        'linkedQuotationId': _linkedQuotationIdController.text.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'updatedByUid': user.uid,
        'updatedByEmail': user.email ?? '',
      };

      if (_canManageAssignment) {
        editableData['assignedToUid'] = (_assignedToUid ?? '').trim();
        editableData['assignedToName'] = assignedToName;
        editableData['assignedToRole'] = assignedToRole;
        editableData['assignedByUid'] = user.uid;
      }

      if (!_isEditing) {
        if (_companyId == null || _companyId!.isEmpty) {
          throw Exception('Company ID missing for creating inquiry');
        }

        final finalAssignedToUid =
        (_assignedToUid ?? user.uid).toString().trim().isEmpty
            ? user.uid
            : (_assignedToUid ?? user.uid).toString().trim();

        if (finalAssignedToUid == user.uid &&
            (assignedToName.isEmpty || assignedToRole.isEmpty)) {
          final currentMeta = await _loadAssignedUserMeta(user.uid);
          assignedToName = currentMeta['name'] ?? assignedToName;
          assignedToRole = currentMeta['role'] ?? assignedToRole;
        }

        final createData = <String, dynamic>{
          ...editableData,
          'companyId': _companyId,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
          'createdByUid': user.uid,
          'createdByEmail': user.email ?? '',
          'assignedToUid': finalAssignedToUid,
          'assignedToName': assignedToName,
          'assignedToRole': assignedToRole,
          'assignedByUid': user.uid,
          'isActive': true,
        };

        await FirebaseFirestore.instance
            .collection('companies')
            .doc(_companyId)
            .collection('inquiries')
            .add(createData);
      } else {
        await widget.existingDoc!.update(editableData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Inquiry updated' : 'Inquiry created'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildAssignmentSection() {
    if (!_canManageAssignment || _companyId == null || _companyId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, color: Color(0xFF6B7280)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _assignedToName.isNotEmpty
                    ? 'Assigned to: $_assignedToName'
                    : 'Assignment available for admin/manager only',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('users')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Failed to load users: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final docs = snapshot.data?.docs.toList() ?? [];
        if (docs.isEmpty) return const SizedBox();

        docs.sort((a, b) {
          final an = (a.data()['name'] ?? '').toString().toLowerCase();
          final bn = (b.data()['name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

        final safeValue =
        docs.any((d) => d.id == _assignedToUid) ? _assignedToUid : null;

        return DropdownButtonFormField<String>(
          value: safeValue,
          decoration: _dec(
            'Assign To',
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
          items: docs.map((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final role = (data['role'] ?? '').toString();
            return DropdownMenuItem(
              value: doc.id,
              child: Text(name.isEmpty ? doc.id : '$name ($role)'),
            );
          }).toList(),
          onChanged: (value) async {
            setState(() {
              _assignedToUid = value;
            });

            if (value != null && value.trim().isNotEmpty) {
              final meta = await _loadAssignedUserMeta(value.trim());
              _assignedToName = meta['name'] ?? '';
              _assignedToRole = meta['role'] ?? '';
              if (mounted) setState(() {});
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inquiryNumber = _firstNonEmpty([
      widget.existingInquiry?.inquiryNumber,
      _existingRawData?['inquiryNumber'],
    ]);
    final assignedToName = _firstNonEmpty([
      _assignedToName,
      _existingRawData?['assignedToName'],
    ]);
    final linkedQuotationId = _linkedQuotationIdController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.white,
        title: Text(
          _isEditing ? 'Edit Inquiry' : 'New Inquiry',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Form(
              key: _formKey,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Inquiry Details' : 'Create Inquiry',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isEditing
                                  ? 'Update qualification, follow-up and assignment details.'
                                  : 'Capture customer requirement, source and follow-up details.',
                              style: const TextStyle(
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
                            if (inquiryNumber.isNotEmpty)
                              _metaPill(
                                label: inquiryNumber,
                                icon: Icons.tag_outlined,
                                color: Colors.white,
                                textWhite: true,
                              ),
                            _metaPill(
                              label: _status,
                              icon: Icons.flag_outlined,
                              color: Colors.white,
                              textWhite: true,
                            ),
                            _metaPill(
                              label: _priority,
                              icon: Icons.local_fire_department_outlined,
                              color: Colors.white,
                              textWhite: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    title: 'Customer & Contact',
                    subtitle:
                    'Review and edit basic customer and contact details.',
                    icon: Icons.business_center_outlined,
                    child: Column(
                      children: [
                        _twoCol(
                          left: _field(
                            controller: _customerNameController,
                            label: 'Customer / Company Name *',
                            required: true,
                            hint: 'Enter company name',
                            prefixIcon: const Icon(Icons.apartment_outlined),
                          ),
                          right: _field(
                            controller: _contactNameController,
                            label: 'Contact Person',
                            hint: 'Enter contact person name',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: _field(
                            controller: _contactPhoneController,
                            label: 'Phone',
                            hint: 'Enter contact number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          right: _field(
                            controller: _contactEmailController,
                            label: 'Email',
                            hint: 'Enter email address',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    title: 'Inquiry Classification',
                    subtitle:
                    'Manage subject, source, type, priority, status and assignment.',
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        _twoCol(
                          left: _field(
                            controller: _subjectController,
                            label: 'Inquiry Subject',
                            hint:
                            'Example: Requirement for 400A inverter welding machine',
                            prefixIcon: const Icon(Icons.title_outlined),
                          ),
                          right: _buildAssignmentSection(),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: DropdownButtonFormField<String>(
                            value: _source.isEmpty ? null : _source,
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
                                  (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                                .toList(),
                            onChanged: (v) => setState(() => _source = v ?? ''),
                          ),
                          right: _field(
                            controller: _sourceRefController,
                            label: 'Source Reference',
                            hint:
                            'Example: L&T, IndiaMART lead, existing client',
                            prefixIcon: const Icon(Icons.link_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: DropdownButtonFormField<String>(
                            value: _inquiryType.isEmpty ? null : _inquiryType,
                            decoration: _dec(
                              'Inquiry Type',
                              prefixIcon: const Icon(Icons.category_outlined),
                            ),
                            items: const [
                              'Product',
                              'Service',
                              'Project',
                              'Both',
                            ]
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _inquiryType = v ?? ''),
                          ),
                          right: DropdownButtonFormField<String>(
                            value: _priority,
                            decoration: _dec(
                              'Priority',
                              prefixIcon: const Icon(
                                  Icons.local_fire_department_outlined),
                            ),
                            items: const ['Hot', 'Warm', 'Cold']
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _priority = v ?? 'Warm'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: DropdownButtonFormField<String>(
                            value: _status,
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
                                  (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _status = v ?? 'Open'),
                          ),
                          right: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (assignedToName.isNotEmpty)
                                  _metaPill(
                                    label: 'Assigned: $assignedToName',
                                    icon: Icons.badge_outlined,
                                    color: const Color(0xFF2563EB),
                                  ),
                                if (linkedQuotationId.isNotEmpty)
                                  _metaPill(
                                    label: 'Quotation Linked',
                                    icon: Icons.receipt_long_outlined,
                                    color: const Color(0xFF0F766E),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    title: 'Requirement & Commercial Details',
                    subtitle:
                    'Maintain requirement, quantity, expected value, location and delivery details.',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      children: [
                        _field(
                          controller: _requiredProductsController,
                          label: 'Required Products / Services',
                          hint:
                          'Write product, specs, application, accessories, technical requirement, etc.',
                          maxLines: 5,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 70),
                            child: Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: _field(
                            controller: _quantityScopeController,
                            label: 'Quantity / Scope',
                            hint: 'Example: 10 machines / 1 line / 200 kg wire',
                            prefixIcon: const Icon(Icons.numbers_outlined),
                          ),
                          right: _field(
                            controller: _expectedValueController,
                            label: 'Expected Deal Value',
                            hint: 'Example: 250000',
                            keyboardType: TextInputType.number,
                            prefixIcon:
                            const Icon(Icons.currency_rupee_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoCol(
                          left: _field(
                            controller: _deliveryTimelineController,
                            label: 'Delivery Timeline',
                            hint: 'Immediate / 2 weeks / 30 days',
                            prefixIcon:
                            const Icon(Icons.local_shipping_outlined),
                          ),
                          right: _field(
                            controller: _locationController,
                            label: 'Location / Site',
                            hint: 'Mumbai / Nagothane / Dubai site',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    title: 'Follow-up & Notes',
                    subtitle:
                    'Track next action date, expected closure and important notes.',
                    icon: Icons.event_note_outlined,
                    child: Column(
                      children: [
                        _twoCol(
                          left: _buildDateTile(
                            label: 'Next Follow-up Date',
                            value: _nextFollowUpDate,
                            onSelect: _pickNextFollowUpDate,
                            onClear: () {
                              setState(() => _nextFollowUpDate = null);
                            },
                          ),
                          right: _buildDateTile(
                            label: 'Expected Closure Date',
                            value: _expectedClosureDate,
                            onSelect: _pickExpectedClosureDate,
                            onClear: () {
                              setState(() => _expectedClosureDate = null);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _lastFollowUpNoteController,
                          label: 'Last Follow-up Note',
                          hint:
                          'Example: Customer asked for revised quotation by Friday.',
                          maxLines: 4,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 52),
                            child: Icon(Icons.history_toggle_off_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _notesController,
                          label: 'Customer Notes',
                          hint:
                          'Example: Needs technical catalogue and competitor comparison.',
                          maxLines: 4,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 52),
                            child: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _internalNotesController,
                          label: 'Internal Notes',
                          hint:
                          'Example: Strong lead, decision maker involved, budget positive.',
                          maxLines: 4,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 52),
                            child: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _linkedQuotationIdController,
                          label: 'Linked Quotation ID',
                          hint: 'Optional quotation reference',
                          prefixIcon:
                          const Icon(Icons.receipt_long_outlined),
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
                          _saving ? null : () => Navigator.pop(context),
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
                          onPressed: _saving ? null : _save,
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
                          icon: _saving
                              ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : 'Save Changes'),
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