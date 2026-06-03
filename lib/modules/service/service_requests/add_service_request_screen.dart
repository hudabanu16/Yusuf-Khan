import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddServiceRequestScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;

  const AddServiceRequestScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    this.existingDocId,
    this.existingData,
  });

  @override
  State<AddServiceRequestScreen> createState() => _AddServiceRequestScreenState();
}

class _AddServiceRequestScreenState extends State<AddServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // --- CUSTOMER & CONTACT STATE ---
  String? _selectedCustomerId;
  String? _selectedCustomerCode;
  String? _selectedContactId;
  String? _selectedAddressId;
  String? _salesPersonId;
  String? _salesPersonName;

  List<Map<String, dynamic>> _customerAddresses = [];
  List<Map<String, dynamic>> _customerContacts = [];
  List<Map<String, dynamic>> _suggestedCustomers = [];
  Map<String, dynamic>? _selectedCustomerData; // Cache top-level data for fallback

  Timer? _debounceTimer;

  // --- CONTROLLERS ---
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerCodeCtrl = TextEditingController();
  final TextEditingController _contactPersonCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _stateCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  final TextEditingController _salesPersonCtrl = TextEditingController();

  final TextEditingController _machineModelCtrl = TextEditingController();
  final TextEditingController _serialNumberCtrl = TextEditingController();
  final TextEditingController _complaintDescCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  String _selectedCategory = 'Machine Breakdown';
  String _selectedPriority = 'Medium';
  String _selectedSource = 'Customer Call';
  bool _isWarranty = false;
  String _status = 'New';

  final List<String> _categories = [
    'Machine Breakdown', 'Installation Support', 'Technical Support',
    'Warranty Claim', 'Spare Parts Requirement', 'AMC Support',
    'Preventive Maintenance', 'Training Request', 'Other'
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Critical'];

  final List<String> _sources = [
    'Customer Call', 'Customer Email', 'Sales Team', 'Service Team',
    'WhatsApp', 'Website', 'AMC', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _customerNameCtrl.addListener(_onCustomerFieldChanged);
    _mobileCtrl.addListener(_onContactFieldTyped);
    _emailCtrl.addListener(_onContactFieldTyped);

    if (widget.existingData != null) {
      final d = widget.existingData!;

      _selectedCustomerId = d['customerId'];
      _selectedCustomerCode = d['customerCode'];
      _selectedContactId = d['contactId'];
      _selectedAddressId = d['selectedAddressId'];
      _salesPersonId = d['salesPersonId'];
      _salesPersonName = d['salesPersonName'];

      _customerNameCtrl.text = d['customerName'] ?? '';
      _customerCodeCtrl.text = d['customerCode'] ?? '';
      _contactPersonCtrl.text = d['contactPerson'] ?? '';
      _mobileCtrl.text = d['mobileNumber'] ?? '';
      _emailCtrl.text = d['email'] ?? '';
      _addressCtrl.text = d['address'] ?? '';
      _cityCtrl.text = d['city'] ?? '';
      _stateCtrl.text = d['state'] ?? '';
      _pincodeCtrl.text = d['pincode'] ?? '';
      _salesPersonCtrl.text = d['salesPersonName'] ?? '';

      _machineModelCtrl.text = d['machineModel'] ?? '';
      _serialNumberCtrl.text = d['serialNumber'] ?? '';
      _complaintDescCtrl.text = d['complaintDescription'] ?? '';
      _remarksCtrl.text = d['remarks'] ?? '';
      _selectedCategory = d['complaintCategory'] ?? _categories.first;
      _selectedPriority = d['priority'] ?? _priorities[1];
      _selectedSource = d['source'] ?? _sources.first;
      _isWarranty = d['isWarranty'] ?? false;
      _status = d['status'] ?? 'New';

      if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
        _fetchCustomerRelatedData(_selectedCustomerId!);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _customerNameCtrl.removeListener(_onCustomerFieldChanged);
    _mobileCtrl.removeListener(_onContactFieldTyped);
    _emailCtrl.removeListener(_onContactFieldTyped);

    _customerNameCtrl.dispose();
    _customerCodeCtrl.dispose();
    _contactPersonCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _salesPersonCtrl.dispose();
    _machineModelCtrl.dispose();
    _serialNumberCtrl.dispose();
    _complaintDescCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // UNIFIED CUSTOMER LOOKUP ENGINE
  // ==========================================

  void _onCustomerFieldChanged() {
    // HARD RESET: If the customer field is completely cleared, wipe EVERYTHING.
    if (_customerNameCtrl.text.isEmpty && _selectedCustomerId != null) {
      _clearCustomerSelection();
      return;
    }

    // Do not trigger background search if a customer is already formally mapped
    if (_selectedCustomerId != null) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _unifiedCustomerLookup();
    });
  }

  void _onContactFieldTyped() {
    if (_selectedCustomerId != null) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _unifiedCustomerLookup();
    });
  }

  Future<bool> _performDeepEmailLookup(String email) async {
    debugPrint("Email entered: $email");
    final db = FirebaseFirestore.instance;

    try {
      // STEP 1: Search customer master (Sequential to bypass Filter.or index needs)
      var custSnap = await db.collection('companies').doc(widget.companyId)
          .collection('customers')
          .where('isDeleted', isEqualTo: false)
          .where('businessEmail', isEqualTo: email)
          .limit(1).get();

      if (custSnap.docs.isEmpty) {
        custSnap = await db.collection('companies').doc(widget.companyId)
            .collection('customers')
            .where('isDeleted', isEqualTo: false)
            .where('email', isEqualTo: email)
            .limit(1).get();
      }

      if (custSnap.docs.isNotEmpty) {
        debugPrint("Customer match found");
        final custDoc = custSnap.docs.first;
        debugPrint("Selected customer: ${custDoc.id}");
        _applyCustomer({'id': custDoc.id, ...custDoc.data()});
        return true;
      }

      // STEP 2: Search customer contacts subcollection
      // Using collectionGroup dynamically checks across all customers.
      final contactsSnap = await db.collectionGroup('contacts')
          .where('email', isEqualTo: email)
          .get();

      for (var doc in contactsSnap.docs) {
        final data = doc.data();
        // Client-side filtering to bypass strict missing-field rules
        if (data['isDeleted'] == true) continue;

        final pathSegments = doc.reference.path.split('/');
        // Format: companies/{companyId}/customers/{customerId}/contacts/{contactId}
        if (pathSegments.length >= 5 && pathSegments[1] == widget.companyId) {
          final matchedCustomerId = pathSegments[3];
          debugPrint("Contact match found");
          debugPrint("Selected contact: ${doc.id}");

          // STEP 3: Load parent customer & auto-select matching contact
          final parentCustDoc = await db.collection('companies')
              .doc(widget.companyId)
              .collection('customers')
              .doc(matchedCustomerId)
              .get();

          if (parentCustDoc.exists) {
            final custData = parentCustDoc.data()!;
            if (custData['isDeleted'] != true) {
              debugPrint("Selected customer: $matchedCustomerId");
              _applyCustomer({'id': matchedCustomerId, ...custData}, preselectContactId: doc.id);
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Deep email lookup error: $e");
    }
    return false;
  }

  Future<void> _unifiedCustomerLookup() async {
    final name = _customerNameCtrl.text.trim().toLowerCase();
    final mobile = _mobileCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    final email = _emailCtrl.text.trim().toLowerCase();

    // Deep Email Lookup Integration
    if (email.length >= 5 && email.contains('@') && _selectedCustomerId == null) {
      bool foundViaEmail = await _performDeepEmailLookup(email);
      if (foundViaEmail) return; // Exit if deep email lookup resolved the payload
    }

    String queryStr = '';

    // Priority Resolution: Mobile -> Email -> Name/Contact Name
    if (mobile.length >= 8) {
      queryStr = mobile;
    } else if (email.length >= 5) {
      queryStr = email;
    } else if (name.length >= 2) {
      queryStr = name;
    } else {
      if (_suggestedCustomers.isNotEmpty && mounted) {
        setState(() => _suggestedCustomers.clear());
      }
      return;
    }

    try {
      // Single powerful query resolving across your advanced searchKeywords array
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers')
          .where('isDeleted', isEqualTo: false)
          .where('searchKeywords', arrayContains: queryStr)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          _suggestedCustomers = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

          // INSTANT AUTO-LOOKUP: If exactly 1 highly-confident match is found via Phone or Email
          if (_suggestedCustomers.length == 1 && (mobile.length >= 10 || email.length >= 5) && _selectedCustomerId == null) {
            _applyCustomer(_suggestedCustomers.first);
          }
        });
      }
    } catch (_) {}
  }

  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerCode = null;
      _selectedContactId = null;
      _selectedAddressId = null;
      _salesPersonId = null;
      _salesPersonName = null;
      _selectedCustomerData = null;

      _customerCodeCtrl.clear();
      _contactPersonCtrl.clear();
      _mobileCtrl.clear();
      _emailCtrl.clear();
      _addressCtrl.clear();
      _cityCtrl.clear();
      _stateCtrl.clear();
      _pincodeCtrl.clear();
      _salesPersonCtrl.clear();

      _customerAddresses.clear();
      _customerContacts.clear();
      _suggestedCustomers.clear();
    });
  }

  void _applyCustomer(Map<String, dynamic> customer, {String? preselectContactId}) async {
    setState(() {
      _suggestedCustomers.clear();
      _selectedCustomerData = customer;
      _selectedCustomerId = customer['id'];
      _selectedCustomerCode = customer['customerCode'];

      // Map exact CRM base fields
      _customerNameCtrl.text = (customer['companyName'] ?? customer['name'] ?? '').toString();
      _customerCodeCtrl.text = _selectedCustomerCode ?? '';
      _salesPersonId = customer['assignedToUid'];
      _salesPersonName = customer['assignedToName'];
      _salesPersonCtrl.text = _salesPersonName ?? '';

      // Set fallback mobile & email from top-level customer data
      if (_mobileCtrl.text.isEmpty) _mobileCtrl.text = (customer['phone'] ?? customer['companyPhone'] ?? '').toString();
      if (_emailCtrl.text.isEmpty) _emailCtrl.text = (customer['businessEmail'] ?? customer['email'] ?? '').toString();

      // Top-level Contact Fallback (In case contacts subcollection is empty)
      final topLevelContact = (customer['contactName'] ?? '').toString();
      if (topLevelContact.isNotEmpty && _contactPersonCtrl.text.isEmpty) {
        _contactPersonCtrl.text = topLevelContact;
      }

      // Process Embedded Addresses Array safely
      final addresses = customer['addresses'] as List<dynamic>? ?? [];
      if (addresses.isNotEmpty) {
        _customerAddresses = addresses.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final primary = _customerAddresses.firstWhere((a) => a['isPrimary'] == true, orElse: () => _customerAddresses.first);
        _applyAddress(primary['id'] ?? primary['erpAddressCode']);
      } else {
        _customerAddresses.clear();
        _selectedAddressId = null;
        _addressCtrl.text = (customer['address'] ?? customer['street'] ?? '').toString();
        _cityCtrl.text = (customer['city'] ?? '').toString();
        _stateCtrl.text = (customer['state'] ?? '').toString();
        _pincodeCtrl.text = (customer['pincode'] ?? '').toString();
      }
    });

    await _fetchCustomerRelatedData(_selectedCustomerId!, preselectContactId: preselectContactId);
  }

  Future<void> _fetchCustomerRelatedData(String customerId, {String? preselectContactId}) async {
    try {
      final db = FirebaseFirestore.instance;

      final String contactsPath = 'companies/${widget.companyId}/customers/$customerId/contacts';
      debugPrint("\n=== CRM CONTACT LOOKUP START ===");
      debugPrint("Path: $contactsPath");

      // IMPORTANT: Removing the .where('isDeleted', isEqualTo: false) constraint from the query.
      // Older contact documents might NOT have an isDeleted field at all. If the field doesn't exist,
      // Firestore completely ignores the document when using a strict .where() clause.
      final contactsSnap = await db.collection(contactsPath).get();

      // Perform safe client-side filtering to avoid the missing-field trap
      final activeContacts = contactsSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((c) => c['isDeleted'] != true)
          .toList();

      debugPrint("Total Raw Contacts Fetched: ${contactsSnap.docs.length}");
      debugPrint("Total Active Contacts Extracted: ${activeContacts.length}");

      if (activeContacts.isNotEmpty) {
        debugPrint("Contact IDs found: ${activeContacts.map((c) => c['id']).join(', ')}");
      } else {
        debugPrint("WARNING: Subcollection is empty. Proceeding to Top-Level Fallback.");
      }

      if (mounted) {
        setState(() {
          _customerContacts = activeContacts;

          // Validate current selection
          bool needsSelection = _selectedContactId == null ||
              _selectedContactId!.trim().isEmpty ||
              !_customerContacts.any((c) => c['id'] == _selectedContactId);

          if (_customerContacts.isNotEmpty && (needsSelection || preselectContactId != null)) {
            if (preselectContactId != null && _customerContacts.any((c) => c['id'] == preselectContactId)) {
              debugPrint("Targeted Contact Preselection: Auto-selecting matched contact.");
              _applyContact(preselectContactId);
            } else {
              debugPrint("Auto-selecting Primary or First contact.");
              final primary = _customerContacts.firstWhere(
                      (c) => c['isPrimary'] == true || c['isPrimary'] == 'true',
                  orElse: () => _customerContacts.first
              );
              _applyContact(primary['id']);
            }
          } else if (_customerContacts.isEmpty) {
            // =====================================
            // FALLBACK TO TOP-LEVEL CUSTOMER DATA
            // =====================================
            debugPrint("Executing Fallback to Top-Level Customer Data.");
            _selectedContactId = null;

            if (_selectedCustomerData != null) {
              _contactPersonCtrl.text = (_selectedCustomerData!['contactName'] ?? _selectedCustomerData!['contactPerson'] ?? '').toString();
              _mobileCtrl.text = (_selectedCustomerData!['phone'] ?? _selectedCustomerData!['companyPhone'] ?? _selectedCustomerData!['alternatePhone'] ?? '').toString();
              _emailCtrl.text = (_selectedCustomerData!['businessEmail'] ?? _selectedCustomerData!['email'] ?? '').toString();
              debugPrint("Fallback Data populated: ${_contactPersonCtrl.text} | ${_mobileCtrl.text} | ${_emailCtrl.text}");
            }
          }
          debugPrint("=== CRM CONTACT LOOKUP END ===\n");
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Error fetching contacts: $e\n$stackTrace");
    }
  }

  void _applyAddress(String? addressId) {
    if (addressId == null || addressId.trim().isEmpty) return;
    final addr = _customerAddresses.firstWhere((a) => (a['id'] ?? a['erpAddressCode']) == addressId, orElse: () => <String, dynamic>{});
    if (addr.isEmpty) return;

    setState(() {
      _selectedAddressId = addressId;
      _addressCtrl.text = (addr['street'] ?? addr['address'] ?? '').toString();
      _cityCtrl.text = (addr['city'] ?? '').toString();
      _stateCtrl.text = (addr['state'] ?? '').toString();
      _pincodeCtrl.text = (addr['pincode'] ?? addr['zipCode'] ?? '').toString();
    });
  }

  void _applyContact(String? contactId) {
    debugPrint("Applying contact ID: $contactId");
    if (contactId == null || contactId.trim().isEmpty) return;

    final contact = _customerContacts.firstWhere((c) => c['id'] == contactId, orElse: () => <String, dynamic>{});
    if (contact.isEmpty) {
      debugPrint("Contact ID '$contactId' not found in loaded contacts.");
      return;
    }

    setState(() {
      _selectedContactId = contactId;
      // Strictly map exact schema fields from CRM Contact Subcollection
      _contactPersonCtrl.text = (contact['name'] ?? contact['contactName'] ?? '').toString();
      _mobileCtrl.text = (contact['phone'] ?? contact['mobile'] ?? '').toString();
      _emailCtrl.text = (contact['email'] ?? '').toString();
      debugPrint("Contact Successfully Applied: ${_contactPersonCtrl.text} | ${_mobileCtrl.text} | ${_emailCtrl.text}");
    });
  }

  // ==========================================
  // SAVE LOGIC
  // ==========================================

  String _getFinancialYear() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return '${startYear.toString().substring(2)}-${endYear.toString().substring(2)}';
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;

    try {
      if (widget.existingDocId == null) {
        final fy = _getFinancialYear();
        final counterRef = db.collection('companies').doc(widget.companyId).collection('counters').doc('service_request_$fy');
        final newDocRef = db.collection('companies').doc(widget.companyId).collection('service_requests').doc();

        await db.runTransaction((transaction) async {
          final counterSnap = await transaction.get(counterRef);
          int nextSeq = 1;

          if (counterSnap.exists) {
            nextSeq = (counterSnap.data()?['sequence'] ?? 0) + 1;
          }

          transaction.set(counterRef, {'sequence': nextSeq}, SetOptions(merge: true));

          final reqNo = 'SR/${nextSeq.toString().padLeft(3, '0')}/$fy';
          final data = _buildPayload(reqNo, newDocRef.id);
          data['createdAt'] = FieldValue.serverTimestamp();
          data['createdBy'] = widget.currentUserUid;
          data['createdByName'] = widget.currentUserName;

          transaction.set(newDocRef, data);
        });
      } else {
        final docRef = db.collection('companies').doc(widget.companyId).collection('service_requests').doc(widget.existingDocId);
        final reqNo = widget.existingData!['requestNumber'] ?? '';
        final data = _buildPayload(reqNo, widget.existingDocId!);

        await docRef.update(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service Request saved successfully.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildPayload(String reqNo, String docId) {
    return {
      'id': docId,
      'companyId': widget.companyId,
      'requestNumber': reqNo,
      'customerId': _selectedCustomerId ?? '',
      'customerCode': _selectedCustomerCode ?? '',
      'customerName': _customerNameCtrl.text.trim(),
      'contactId': _selectedContactId ?? '',
      'contactPerson': _contactPersonCtrl.text.trim(),
      'selectedAddressId': _selectedAddressId ?? '',
      'address': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'mobileNumber': _mobileCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'salesPersonId': _salesPersonId ?? '',
      'salesPersonName': _salesPersonName ?? '',
      'machineModel': _machineModelCtrl.text.trim(),
      'serialNumber': _serialNumberCtrl.text.trim(),
      'complaintCategory': _selectedCategory,
      'complaintDescription': _complaintDescCtrl.text.trim(),
      'priority': _selectedPriority,
      'source': _selectedSource,
      'status': _status,
      'isWarranty': _isWarranty,
      'remarks': _remarksCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': widget.currentUserUid,
      'isDeleted': false,
      'searchKeywords': _generateSearchKeywords(reqNo),
    };
  }

  List<String> _generateSearchKeywords(String requestNo) {
    final str = '$requestNo ${_customerNameCtrl.text} ${_contactPersonCtrl.text} ${_mobileCtrl.text} ${_machineModelCtrl.text} ${_selectedCustomerCode ?? ''}'.toLowerCase();
    return str.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet().toList();
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(widget.existingDocId == null ? 'New Service Request' : 'Edit Service Request', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCustomerInformationSection(),
                        const SizedBox(height: 16),
                        _SectionBlock(
                          title: 'Machine & Complaint Details',
                          subtitle: 'Provide technical details of the issue',
                          child: Column(
                            children: [
                              _buildResponsiveRow(
                                children: [
                                  _buildTextField(label: 'Machine Model *', controller: _machineModelCtrl, icon: Icons.precision_manufacturing_outlined, required: true),
                                  _buildTextField(label: 'Serial Number', controller: _serialNumberCtrl, icon: Icons.tag_outlined),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildResponsiveRow(
                                children: [
                                  _buildDropdown(label: 'Complaint Category *', icon: Icons.category_outlined, value: _selectedCategory, items: _categories, onChanged: (v) => setState(() => _selectedCategory = v!)),
                                  _buildDropdown(label: 'Priority *', icon: Icons.flag_outlined, value: _selectedPriority, items: _priorities, onChanged: (v) => setState(() => _selectedPriority = v!)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(label: 'Complaint Description *', controller: _complaintDescCtrl, icon: Icons.description_outlined, required: true, maxLines: 3),
                              const SizedBox(height: 12),
                              _buildResponsiveRow(
                                children: [
                                  _buildDropdown(label: 'Source *', icon: Icons.campaign_outlined, value: _selectedSource, items: _sources, onChanged: (v) => setState(() => _selectedSource = v!)),
                                  Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.white),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    child: SwitchListTile(
                                      title: const Text('Under Warranty?', style: TextStyle(fontSize: 14)),
                                      value: _isWarranty,
                                      onChanged: (val) => setState(() => _isWarranty = val),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionBlock(
                          title: 'Additional Information',
                          subtitle: 'Internal remarks and attachments',
                          child: _buildTextField(label: 'Internal Remarks', controller: _remarksCtrl, icon: Icons.notes_outlined, maxLines: 2),
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

  Widget _buildCustomerInformationSection() {
    return _SectionBlock(
      title: 'Customer Information',
      subtitle: 'Identify customer or enter caller details manually',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResponsiveRow(
            children: [
              _buildTextField(
                label: 'Customer Name / Search *',
                controller: _customerNameCtrl,
                icon: Icons.search,
                required: true,
                suffixIcon: _customerNameCtrl.text.isNotEmpty && _selectedCustomerId != null
                    ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _clearCustomerSelection,
                  tooltip: 'Clear Customer',
                )
                    : null,
              ),
              _buildTextField(label: 'Customer Code', controller: _customerCodeCtrl, readOnly: true, hintText: 'Auto-generated', icon: Icons.tag),
            ],
          ),

          if (_suggestedCustomers.isNotEmpty && _selectedCustomerId == null)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.person_search, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text('Matching Customers Found', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _suggestedCustomers.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final opt = _suggestedCustomers[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(opt['companyName'] ?? opt['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text([opt['customerCode'], opt['phone'] ?? opt['companyPhone'], opt['city']].where((e) => e != null && e.toString().isNotEmpty).join(' • '), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade800,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => _applyCustomer(opt),
                          child: const Text('Select'),
                        ),
                        onTap: () => _applyCustomer(opt),
                      );
                    },
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          if (_customerContacts.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: _selectedContactId,
              decoration: _inputDecoration(label: 'Select Contact Person', icon: Icons.contacts_outlined),
              items: _customerContacts.map((c) {
                final text = '${c['name'] ?? ''} - ${c['designation'] ?? ''} - ${c['phone'] ?? c['mobile'] ?? ''}';
                return DropdownMenuItem<String>(value: c['id'], child: Text(text, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: _applyContact,
            ),
            const SizedBox(height: 12),
          ],

          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'Contact Person *', controller: _contactPersonCtrl, required: true, icon: Icons.person_outline),
              _buildTextField(label: 'Mobile Number *', controller: _mobileCtrl, required: true, isPhone: true, icon: Icons.phone_outlined),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'Email', controller: _emailCtrl, isEmail: true, icon: Icons.email_outlined),
              _buildTextField(label: 'Sales Person', controller: _salesPersonCtrl, readOnly: true, hintText: 'Auto-assigned', icon: Icons.assignment_ind_outlined),
            ],
          ),

          if (_customerAddresses.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
            DropdownButtonFormField<String>(
              value: _selectedAddressId,
              decoration: _inputDecoration(label: 'Select Address', icon: Icons.location_on_outlined),
              items: _customerAddresses.map((addr) {
                final text = '${addr['type'] ?? 'Address'} - ${addr['city'] ?? ''} - ${addr['state'] ?? ''}';
                return DropdownMenuItem<String>(value: addr['id'] ?? addr['erpAddressCode'], child: Text(text, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: _applyAddress,
            ),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 12),
          ],

          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'Address', controller: _addressCtrl, icon: Icons.home_outlined),
              _buildTextField(label: 'City', controller: _cityCtrl, icon: Icons.location_city_outlined),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveRow(
            children: [
              _buildTextField(label: 'State', controller: _stateCtrl, icon: Icons.map_outlined),
              _buildTextField(label: 'Pincode', controller: _pincodeCtrl, icon: Icons.markunread_mailbox_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), offset: const Offset(0, -4), blurRadius: 10)]
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
                    widget.existingDocId != null ? 'Update the service request details.' : 'Save this new service request to CRM.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 170,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveRequest,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : Icon(widget.existingDocId != null ? Icons.save_outlined : Icons.add_circle_outline, size: 18),
                    label: Text(widget.existingDocId != null ? 'Update' : 'Save Request'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildResponsiveRow({required List<Widget> children}) {
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

  InputDecoration _inputDecoration({required String label, required IconData icon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.blue.shade600, width: 1.2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade400)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade400, width: 1.2)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    bool required = false,
    bool readOnly = false,
    bool isPhone = false,
    bool isEmail = false,
    int maxLines = 1,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : keyboardType),
      decoration: _inputDecoration(label: label, icon: icon, hintText: hintText).copyWith(
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        suffixIcon: suffixIcon,
      ),
      validator: (val) {
        if (required && !readOnly && (val == null || val.trim().isEmpty)) return 'This field is required';
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label: label, icon: icon),
      items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 0.9),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}