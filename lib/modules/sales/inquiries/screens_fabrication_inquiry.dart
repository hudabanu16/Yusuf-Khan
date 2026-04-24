import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ScreensFabricationInquiry extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserRole;

  const ScreensFabricationInquiry({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserRole,
  });

  @override
  State<ScreensFabricationInquiry> createState() =>
      _ScreensFabricationInquiryState();
}

class _ScreensFabricationInquiryState extends State<ScreensFabricationInquiry> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _projectNameCtrl = TextEditingController();
  final _siteLocationCtrl = TextEditingController();
  final _epcContractorCtrl = TextEditingController();
  final _moduleMakeCtrl = TextEditingController();
  final _moduleWpCtrl = TextEditingController();
  final _projectCapacityCtrl = TextEditingController();
  final _structureTypeCtrl = TextEditingController(text: 'Ground mounted solar structure');
  final _tableConfigCtrl = TextEditingController();
  final _pileDepthCtrl = TextEditingController();
  final _groundClearanceCtrl = TextEditingController();
  final _tiltAngleCtrl = TextEditingController();
  final _drawingNoCtrl = TextEditingController();
  final _boqReferenceCtrl = TextEditingController();
  final _quantityScopeCtrl = TextEditingController();
  final _deliveryTimelineCtrl = TextEditingController();
  final _expectedValueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _internalNotesCtrl = TextEditingController();

  String _source = 'Email';
  String _priority = 'Warm';
  String _status = 'BOQ Pending';
  bool _saving = false;
  bool _uploadingDocument = false;
  bool _extractingDocument = false;
  final List<Map<String, dynamic>> _uploadedDocuments = [];

  CollectionReference<Map<String, dynamic>> get _inquiriesRef {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('inquiries');
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    _projectNameCtrl.dispose();
    _siteLocationCtrl.dispose();
    _epcContractorCtrl.dispose();
    _moduleMakeCtrl.dispose();
    _moduleWpCtrl.dispose();
    _projectCapacityCtrl.dispose();
    _structureTypeCtrl.dispose();
    _tableConfigCtrl.dispose();
    _pileDepthCtrl.dispose();
    _groundClearanceCtrl.dispose();
    _tiltAngleCtrl.dispose();
    _drawingNoCtrl.dispose();
    _boqReferenceCtrl.dispose();
    _quantityScopeCtrl.dispose();
    _deliveryTimelineCtrl.dispose();
    _expectedValueCtrl.dispose();
    _notesCtrl.dispose();
    _internalNotesCtrl.dispose();
    super.dispose();
  }

  String _generateInquiryNumber() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final tick = now.millisecondsSinceEpoch.toString().substring(8);
    return 'FAB-$y$m$d-$tick';
  }

  String _subject() {
    final client = _clientNameCtrl.text.trim();
    final project = _projectNameCtrl.text.trim();
    final capacity = _projectCapacityCtrl.text.trim();
    final table = _tableConfigCtrl.text.trim();
    final parts = [
      if (client.isNotEmpty) client,
      if (project.isNotEmpty) project,
      if (capacity.isNotEmpty) '$capacity KWp',
      if (table.isNotEmpty) table,
      _uploadedDocuments.isNotEmpty ? 'Uploaded BOQ inquiry' : 'MMS inquiry',
    ];
    return parts.join(' - ');
  }

  String _safeFileName(String fileName) {
    final safe = fileName.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return safe.isEmpty ? 'inquiry_document' : safe;
  }

  String? _contentTypeFor(String extension) {
    switch (extension.trim().toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      default:
        return null;
    }
  }

  Future<void> _pickAndUploadDocuments() async {
    setState(() => _uploadingDocument = true);

    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'xlsx', 'xls'],
      );

      if (picked == null || picked.files.isEmpty) return;

      final uploaded = <Map<String, dynamic>>[];
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (final file in picked.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Could not read ${file.name}. Please try again.');
        }

        final safeName = _safeFileName(file.name);
        final storagePath =
            'tenant_inquiries/${widget.companyId}/source_documents/$timestamp-$safeName';
        final ref = FirebaseStorage.instance.ref(storagePath);
        final contentType = _contentTypeFor(file.extension ?? '');
        final metadata = SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'companyId': widget.companyId,
            'uploadedBy': widget.currentUserUid,
            'source': 'fabrication_inquiry_upload',
          },
        );

        final task = await ref.putData(bytes, metadata);
        final downloadUrl = await task.ref.getDownloadURL();

        uploaded.add({
          'fileName': file.name,
          'storagePath': storagePath,
          'downloadUrl': downloadUrl,
          'contentType': contentType ?? '',
          'sizeBytes': file.size,
          'uploadedAt': Timestamp.now(),
          'uploadedBy': widget.currentUserUid,
        });
      }

      if (!mounted) return;
      setState(() {
        _uploadedDocuments.addAll(uploaded);
        if (_boqReferenceCtrl.text.trim().isEmpty) {
          _boqReferenceCtrl.text = uploaded.first['fileName'].toString();
        }
        _status = 'BOQ Pending';
      });

      await _tryExtractDocumentFields(uploaded.first);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingDocument = false);
    }
  }

  Future<void> _tryExtractDocumentFields(Map<String, dynamic> document) async {
    final contentType = document['contentType'].toString();
    if (!contentType.startsWith('image/')) {
      _infoSnack(
        'File attached. Auto-fill currently supports image uploads; PDF/Excel will stay for manual review.',
      );
      return;
    }

    setState(() => _extractingDocument = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'extractFabricationInquiryFromDocument',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'companyId': widget.companyId,
        'storagePath': document['storagePath'].toString(),
        'contentType': contentType,
      });

      final data = result.data;
      final fields = data['fields'];
      if (fields is! Map) {
        _infoSnack('Document attached, but no fields were detected.');
        return;
      }

      void setIfEmpty(TextEditingController controller, Object? value) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty && controller.text.trim().isEmpty) {
          controller.text = text;
        }
      }

      setState(() {
        setIfEmpty(_clientNameCtrl, fields['clientName']);
        setIfEmpty(_projectCapacityCtrl, fields['projectCapacityKWp']);
        setIfEmpty(_moduleWpCtrl, fields['moduleWp']);
        setIfEmpty(_tableConfigCtrl, fields['tableConfiguration']);
        setIfEmpty(_pileDepthCtrl, fields['pileDepth']);
        setIfEmpty(_quantityScopeCtrl, fields['moduleCount']);

        final boqReference = fields['boqReference']?.toString().trim() ?? '';
        if (boqReference.isNotEmpty) {
          final currentRef = _boqReferenceCtrl.text.trim();
          _boqReferenceCtrl.text = currentRef.isEmpty
              ? boqReference
              : '$currentRef • $boqReference';
        }

        final preview = fields['sourceTextPreview']?.toString().trim() ?? '';
        if (preview.isNotEmpty && _internalNotesCtrl.text.trim().isEmpty) {
          _internalNotesCtrl.text =
              'OCR text captured for review:\n${preview.trim()}';
        }
      });

      _infoSnack('Document read. Please review the auto-filled fields.');
    } on FirebaseFunctionsException catch (e) {
      _infoSnack(
        'File attached. Auto-fill failed: ${e.message ?? e.code}',
      );
    } catch (e) {
      _infoSnack('File attached. Auto-fill failed: $e');
    } finally {
      if (mounted) setState(() => _extractingDocument = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_clientNameCtrl.text.trim().isEmpty && _uploadedDocuments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter client name or upload a BOQ/drawing file.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final inquiryNumber = _generateInquiryNumber();
      final subject = _subject();
      final clientName = _clientNameCtrl.text.trim();

      await _inquiriesRef.add({
        'companyId': widget.companyId,
        'inquiryNumber': inquiryNumber,
        'inquiryCode': inquiryNumber,
        'inquiryProfile': 'fabrication_solar',
        'subject': subject,
        'customerId': '',
        'customerName': clientName,
        'companyName': clientName,
        'contactId': '',
        'contactName': _contactNameCtrl.text.trim(),
        'contactPhone': _contactPhoneCtrl.text.trim(),
        'contactMobile': _contactPhoneCtrl.text.trim(),
        'contactEmail': _contactEmailCtrl.text.trim(),
        'contactDesignation': '',
        'source': _source,
        'sourceReference': _boqReferenceCtrl.text.trim(),
        'channelRef': _boqReferenceCtrl.text.trim(),
        'inquiryType': 'Fabrication / Solar MMS',
        'requiredProducts': 'Module mounting structure / fabrication work',
        'quantityScope': _quantityScopeCtrl.text.trim(),
        'quantityNote': _quantityScopeCtrl.text.trim(),
        'expectedValue': _expectedValueCtrl.text.trim(),
        'budgetNote': _expectedValueCtrl.text.trim(),
        'deliveryTimeline': _deliveryTimelineCtrl.text.trim(),
        'location': _siteLocationCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'internalNotes': _internalNotesCtrl.text.trim(),
        'priority': _priority,
        'status': _status,
        'nextFollowUpDate': null,
        'expectedClosureDate': null,
        'lastFollowUpNote': '',
        'linkedQuotationId': '',
        'assignedToUid': widget.currentUserUid,
        'assignedToName': '',
        'assignedToRole': widget.currentUserRole,
        'assignedByUid': widget.currentUserUid,
        'recordOwnerUid': widget.currentUserUid,
        'createdBy': widget.currentUserUid,
        'createdByUid': widget.currentUserUid,
        'updatedBy': widget.currentUserUid,
        'updatedByUid': widget.currentUserUid,
        'isActive': true,
        'hasSourceDocument': _uploadedDocuments.isNotEmpty,
        'sourceDocuments': _uploadedDocuments,
        'documentReviewStatus': _uploadedDocuments.isNotEmpty
            ? (_extractingDocument ? 'ocr_pending' : 'pending_manual_review')
            : 'not_uploaded',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'fabricationRequirement': {
          'clientName': clientName,
          'projectName': _projectNameCtrl.text.trim(),
          'siteLocation': _siteLocationCtrl.text.trim(),
          'epcContractor': _epcContractorCtrl.text.trim(),
          'moduleMake': _moduleMakeCtrl.text.trim(),
          'moduleWp': _moduleWpCtrl.text.trim(),
          'projectCapacityKWp': _projectCapacityCtrl.text.trim(),
          'structureType': _structureTypeCtrl.text.trim(),
          'tableConfiguration': _tableConfigCtrl.text.trim(),
          'pileDepth': _pileDepthCtrl.text.trim(),
          'groundClearance': _groundClearanceCtrl.text.trim(),
          'tiltAngle': _tiltAngleCtrl.text.trim(),
          'drawingNo': _drawingNoCtrl.text.trim(),
          'boqReference': _boqReferenceCtrl.text.trim(),
          'sourceDocuments': _uploadedDocuments,
        },
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save fabrication inquiry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'New Fabrication Inquiry',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save Inquiry'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            _hero(),
            _uploadCard(),
            _section(
              title: 'Client & Project',
              subtitle: 'Capture who sent the inquiry and where the structure is required.',
              icon: Icons.business_center_outlined,
              children: [
                _grid([
                  _field(_clientNameCtrl, 'Client Name'),
                  _field(_epcContractorCtrl, 'EPC Contractor'),
                  _field(_projectNameCtrl, 'Project / Site Name'),
                  _field(_siteLocationCtrl, 'Site Location'),
                  _field(_contactNameCtrl, 'Contact Person'),
                  _field(_contactPhoneCtrl, 'Phone / WhatsApp'),
                  _field(_contactEmailCtrl, 'Email'),
                ]),
              ],
            ),
            _section(
              title: 'Solar / Fabrication Requirement',
              subtitle: 'This matches the customer BOQ and drawing format.',
              icon: Icons.foundation_outlined,
              children: [
                _grid([
                  _field(_moduleMakeCtrl, 'Module Make'),
                  _field(_moduleWpCtrl, 'Module Wp'),
                  _field(_projectCapacityCtrl, 'Project Capacity KWp'),
                  _field(_structureTypeCtrl, 'Structure Type'),
                  _field(
                    _tableConfigCtrl,
                    'Table Configuration',
                    hint: 'Example: 2PX23, 2PX26, 2PX7',
                  ),
                  _field(_pileDepthCtrl, 'Pile Depth Considered'),
                  _field(_groundClearanceCtrl, 'Ground Clearance'),
                  _field(_tiltAngleCtrl, 'Tilt Angle'),
                  _field(_drawingNoCtrl, 'Drawing No.'),
                  _field(_boqReferenceCtrl, 'BOQ / Mail Reference'),
                ]),
              ],
            ),
            _section(
              title: 'Commercial & Follow-up',
              subtitle: 'Keep costing and next action information ready for quotation.',
              icon: Icons.request_quote_outlined,
              children: [
                _grid([
                  _dropdown(
                    label: 'Source',
                    value: _source,
                    values: const ['Email', 'WhatsApp', 'Phone', 'Tender', 'Visit'],
                    onChanged: (value) => setState(() => _source = value),
                  ),
                  _dropdown(
                    label: 'Priority',
                    value: _priority,
                    values: const ['Hot', 'Warm', 'Cold'],
                    onChanged: (value) => setState(() => _priority = value),
                  ),
                  _dropdown(
                    label: 'Status',
                    value: _status,
                    values: const [
                      'Open',
                      'BOQ Pending',
                      'Costing Pending',
                      'Quotation Pending',
                      'Quotation Sent',
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                  _field(_quantityScopeCtrl, 'Quantity / Scope'),
                  _field(_deliveryTimelineCtrl, 'Required Timeline'),
                  _field(_expectedValueCtrl, 'Expected Value'),
                ]),
                const SizedBox(height: 12),
                _field(
                  _notesCtrl,
                  'Customer Requirement Notes',
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                _field(
                  _internalNotesCtrl,
                  'Internal Notes',
                  maxLines: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Fabrication / Solar MMS Inquiry',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Use this for Aman-style BOQ, drawing, table configuration, project capacity, and quotation preparation.',
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFF7ED),
            child: Icon(Icons.upload_file_outlined, color: Color(0xFFEA580C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Create From BOQ / Drawing',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
          'Upload the customer BOQ, Excel sheet, PDF, or drawing. Image uploads can auto-fill key fields after OCR; all files stay attached for costing and review.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (_uploadedDocuments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _uploadedDocuments.map((doc) {
                      return Chip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(doc['fileName'].toString()),
                        onDeleted: () {
                          setState(() => _uploadedDocuments.remove(doc));
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (_extractingDocument) ...[
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Reading document and filling fields...',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          FilledButton.icon(
            onPressed: _uploadingDocument ? null : _pickAndUploadDocuments,
            icon: _uploadingDocument
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
            label: Text(_uploadingDocument ? 'Uploading...' : 'Upload'),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF1FF),
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= 840;
        if (!twoColumn) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(),
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 12,
          children: children
              .map(
                (child) => SizedBox(
                  width: (constraints.maxWidth - 14) / 2,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: required
          ? (value) => (value ?? '').trim().isEmpty ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
        ),
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  void _infoSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
