import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Module Imports
import 'package:QUIK/modules/crm/customers/screens_add_customer.dart';
import 'package:QUIK/modules/sales/inquiries/screens_add_inquiry.dart';

import 'customer_visit_model.dart';
import 'customer_visit_service.dart';

class CustomerVisitScreen extends StatefulWidget {
  final String companyId;
  final String currentUserId;
  final CustomerVisitModel? visit;

  const CustomerVisitScreen({
    Key? key,
    required this.companyId,
    required this.currentUserId,
    this.visit,
  }) : super(key: key);

  @override
  State<CustomerVisitScreen> createState() => _CustomerVisitScreenState();
}

class _CustomerVisitScreenState extends State<CustomerVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final CustomerVisitService _service = CustomerVisitService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isLoadingCustomerDetails = false;

  // --- CRM MASTER DATA ---
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allCustomers = [];
  String? _selectedCustomerId;
  Map<String, dynamic>? _selectedCustomerData;

  List<Map<String, dynamic>> _customerAddresses = [];
  Map<String, dynamic>? _selectedAddressData;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _customerContacts = [];
  String? _selectedContactId;
  Map<String, dynamic>? _selectedContactData;

  // --- HEADER & META ---
  final _visitNumberCtrl = TextEditingController();
  final _visitOwnerCtrl = TextEditingController();
  final _visitOwnerNameCtrl = TextEditingController(text: 'Logged-in User');

  // --- TAB 1: BASIC INFO ---
  final _contactMobileCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactDesignationCtrl = TextEditingController();
  final _contactDepartmentCtrl = TextEditingController();

  DateTime? _visitDate;
  String _priority = 'Medium';
  String _purpose = 'Inquiry Generation';
  final _otherPurposeCtrl = TextEditingController();

  final List<String> _purposeOptions = [
    'Inquiry Generation',
    'Quotation Discussion',
    'Order Follow-up',
    'Payment Follow-up',
    'Technical Discussion',
    'Machine Demo',
    'Installation',
    'Service Visit',
    'Complaint Visit',
    'AMC Visit',
    'Relationship Visit',
    'Vendor Visit',
    'Other'
  ];

  // --- GPS CHECK-IN / CHECK-OUT ---
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  String _visitDuration = '';
  double? _checkInLat;
  double? _checkInLng;
  double? _checkOutLat;
  double? _checkOutLng;
  String _gpsAddress = '';
  String _checkOutAddress = '';

  // --- DISCUSSION & OUTCOME ---
  String _outcome = '';
  final _discussionNotesCtrl = TextEditingController();

  // --- DYNAMIC WORKFLOW CONTROLLERS ---
  bool _leadGenerated = false;
  String _linkedInquiryId = '';

  // Quotation fields
  String _linkedQuotationId = '';
  String _referenceQuotationNumber = '';
  final _quoteDateCtrl = TextEditingController();
  final _quoteValueCtrl = TextEditingController();
  final _quoteStatusCtrl = TextEditingController(); // Unified controller name
  final _quoteRevisionCtrl = TextEditingController();
  final _customerFeedbackCtrl = TextEditingController();
  final _priceFeedbackCtrl = TextEditingController();
  final _competitorFeedbackCtrl = TextEditingController();
  final _expectedClosureCtrl = TextEditingController();

  // Tech/Service fields
  final _technicalTopicsCtrl = TextEditingController();
  final _serviceObservationCtrl = TextEditingController();
  final _actionTakenCtrl = TextEditingController();
  final _recommendationCtrl = TextEditingController();
  final _complaintDescCtrl = TextEditingController();
  String _complaintSeverity = 'Medium';
  final _temporaryResolutionCtrl = TextEditingController();
  String _linkedServiceTicketId = '';
  final _installationNotesCtrl = TextEditingController();
  final _machineStatusCtrl = TextEditingController();
  final _customerAcceptanceCtrl = TextEditingController();
  DateTime? _nextServiceDate;

  // Finance fields
  final _outstandingAmountCtrl = TextEditingController();
  final _overdueAmountCtrl = TextEditingController();
  final _lastPaymentDateCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  DateTime? _paymentCommitmentDate;
  final _committedAmountCtrl = TextEditingController();
  final _paymentRemarksCtrl = TextEditingController();

  final _internalNotesCtrl = TextEditingController();

  // --- FOLLOW-UP ---
  bool _followupRequired = false;
  DateTime? _followupDate;
  String _followupType = 'Call';
  String _followupPriority = 'Medium';
  final _followupRemarksCtrl = TextEditingController();

  // --- ATTACHMENTS & OUTCOME ---
  String _status = 'Draft';
  List<String> _attachmentsList = [];
  String _selectedDocumentCategory = 'Site Photos';
  final List<String> _documentCategories = [
    'Site Photos', 'Machine Photos', 'Requirement Sheet', 'Technical Drawing',
    'Customer PO', 'Competitor Quotation', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _visitDate = DateTime.now();
    _resetOutcome();
    _initializeVisitDetails();
    _fetchCustomers().then((_) {
      if (widget.visit != null) {
        _loadExistingData();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _resetOutcome() {
    final opts = _getOutcomeOptions();
    if (!opts.contains(_outcome)) {
      _outcome = opts.isNotEmpty ? opts.first : '';
    }
  }

  List<String> _getOutcomeOptions() {
    switch (_purpose) {
      case 'Inquiry Generation':
        return ['Inquiry Created', 'Need Follow-up', 'Not Interested'];
      case 'Quotation Discussion':
        return ['Negotiation', 'Revision Required', 'Approved', 'Rejected'];
      case 'Payment Follow-up':
        return ['Committed', 'Partially Committed', 'Disputed', 'Received'];
      case 'Service Visit':
      case 'Complaint Visit':
      case 'AMC Visit':
        return ['Resolved', 'Pending Parts', 'Escalated'];
      default:
        return ['Open', 'Completed', 'Requires Action'];
    }
  }

  // Robust method for filtering active contacts safely
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getFilteredContacts() {
    return _customerContacts.where((c) {
      final d = c.data();
      return d['isActive'] == null || d['isActive'] == true;
    }).toList();
  }

  Future<void> _initializeVisitDetails() async {
    if (widget.visit == null) {
      await _generateSequentialVisitNumber();
    }
    try {
      final userDoc = await _firestore.collection('companies').doc(widget.companyId).collection('users').doc(widget.currentUserId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final name = data['name'] ?? data['fullName'] ?? 'Logged-in User';
        _visitOwnerNameCtrl.text = name;
        _visitOwnerCtrl.text = name;
      }
    } catch (e) {
      _visitOwnerCtrl.text = 'Logged-in User';
    }
  }

  Future<void> _generateSequentialVisitNumber() async {
    final counterRef = _firestore.collection('companies').doc(widget.companyId).collection('metadata').doc('visit_counter');
    try {
      final nextCount = await _firestore.runTransaction((tx) async {
        final snap = await tx.get(counterRef);
        int count = 1;
        if (snap.exists && snap.data()!['count'] != null) {
          count = (snap.data()!['count'] as int) + 1;
        }
        tx.set(counterRef, {'count': count}, SetOptions(merge: true));
        return count;
      });
      final year = DateTime.now().year;
      _safeSetState(() {
        _visitNumberCtrl.text = 'VIS-$year-${nextCount.toString().padLeft(6, '0')}';
      });
    } catch (e) {
      _safeSetState(() {
        _visitNumberCtrl.text = 'VIS-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      });
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final snap = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers')
          .where('isDeleted', isEqualTo: false)
          .get();
      _safeSetState(() {
        _allCustomers = snap.docs;
      });
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }
  }

  Future<void> _fetchCustomerDetails(String customerId) async {
    _safeSetState(() => _isLoadingCustomerDetails = true);
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers')
          .doc(customerId)
          .get();

      if (doc.exists && doc.data() != null) {
        _selectedCustomerData = doc.data();

        // Advanced Finance Data Pull
        final outAmt = (_selectedCustomerData?['outstandingAmount'] ?? 0.0);
        final overdueAmt = (_selectedCustomerData?['overdueAmount'] ?? 0.0);
        final credLim = (_selectedCustomerData?['creditLimit'] ?? 0.0);

        _outstandingAmountCtrl.text = outAmt.toStringAsFixed(2);
        _overdueAmountCtrl.text = overdueAmt.toStringAsFixed(2);
        _creditLimitCtrl.text = credLim > 0 ? credLim.toStringAsFixed(2) : 'No Limit Set';

        if (_selectedCustomerData?['lastPaymentDate'] != null) {
          final lpd = (_selectedCustomerData!['lastPaymentDate'] as Timestamp).toDate();
          _lastPaymentDateCtrl.text = DateFormat('dd MMM yyyy').format(lpd);
        } else {
          _lastPaymentDateCtrl.text = 'No prior payments';
        }

        final rawAddresses = _selectedCustomerData?['addresses'];
        if (rawAddresses is List) {
          _customerAddresses = List<Map<String, dynamic>>.from(rawAddresses);
        } else {
          _customerAddresses = [];
        }

        final contactsSnap = await _firestore
            .collection('companies')
            .doc(widget.companyId)
            .collection('customers')
            .doc(customerId)
            .collection('contacts')
            .where('isActive', isEqualTo: true)
            .get();

        _customerContacts = contactsSnap.docs;
      }
    } catch (e) {
      debugPrint('Error fetching customer details: $e');
    } finally {
      _safeSetState(() => _isLoadingCustomerDetails = false);
    }
  }

  void _onAddressSelected(Map<String, dynamic>? val) {
    _safeSetState(() {
      _selectedAddressData = val;
    });
  }

  void _loadExistingData() async {
    final v = widget.visit!;

    _visitNumberCtrl.text = v.visitNumber;
    _checkInTime = v.checkInTime;
    _checkOutTime = v.checkOutTime;
    _visitDuration = v.visitDuration;
    _attachmentsList = List<String>.from(v.attachments);
    _status = v.status;
    _outcome = v.outcome;

    if (v.gpsLocation.isNotEmpty) _gpsAddress = v.gpsLocation;

    if (v.customerId.isNotEmpty) {
      _selectedCustomerId = v.customerId;
      await _fetchCustomerDetails(v.customerId);

      if (_customerAddresses.isNotEmpty) {
        try {
          _selectedAddressData = _customerAddresses.firstWhere((a) {
            final fullAddr = '${a['street']} ${a['city']}';
            return fullAddr.contains(v.address) || v.address.contains(a['city'] ?? '');
          });
        } catch (_) {
          _selectedAddressData = _customerAddresses.first;
        }
      }

      if (_customerContacts.isNotEmpty) {
        try {
          final matchedContact = _customerContacts.firstWhere((c) => c['name'] == v.contactPerson);
          _selectedContactId = matchedContact.id;
          _selectedContactData = matchedContact.data();
          _applyContactAutoFill(_selectedContactData!);
        } catch (_) {
          _selectedContactId = null;
        }
      }
    }

    _purpose = _purposeOptions.contains(v.purpose) ? v.purpose : 'Other';
    if (_purpose == 'Other') _otherPurposeCtrl.text = v.purpose;
    _resetOutcome();
    _outcome = _getOutcomeOptions().contains(v.outcome) ? v.outcome : _getOutcomeOptions().first;

    _visitDate = v.visitDate;
    _priority = v.priority;
    _discussionNotesCtrl.text = v.discussionNotes;

    _leadGenerated = v.leadGenerated;
    _linkedInquiryId = v.linkedInquiryId;
    _linkedQuotationId = v.linkedQuotationId;
    if (_linkedQuotationId.isNotEmpty) _referenceQuotationNumber = 'Linked ID: $_linkedQuotationId';
    _quoteStatusCtrl.text = v.quotationStatus; // Fixed Reference
    _customerFeedbackCtrl.text = v.customerFeedback;
    _priceFeedbackCtrl.text = v.priceFeedback;
    _competitorFeedbackCtrl.text = v.competitorFeedback;
    _technicalTopicsCtrl.text = v.technicalTopics;
    _outstandingAmountCtrl.text = v.outstandingAmount.toString();
    _paymentCommitmentDate = v.paymentCommitmentDate;
    _paymentRemarksCtrl.text = v.paymentRemarks;
    _serviceObservationCtrl.text = v.serviceObservation;
    _actionTakenCtrl.text = v.actionTaken;
    _recommendationCtrl.text = v.recommendation;
    _complaintDescCtrl.text = v.complaintDescription;
    _complaintSeverity = v.complaintSeverity.isEmpty ? 'Medium' : v.complaintSeverity;
    _temporaryResolutionCtrl.text = v.temporaryResolution;
    _linkedServiceTicketId = v.linkedServiceTicketId;
    _installationNotesCtrl.text = v.installationNotes;
    _machineStatusCtrl.text = v.machineStatus;
    _customerAcceptanceCtrl.text = v.customerAcceptance;
    _nextServiceDate = v.nextServiceDate;
    _internalNotesCtrl.text = v.internalNotes;

    _followupRequired = v.followupRequired;
    _followupDate = v.followupDate;
    _followupType = v.followupType;
    _followupRemarksCtrl.text = v.followupRemarks;

    _safeSetState(() {});
  }

  Future<void> _handleCheckIn() async {
    _safeSetState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permissions are denied';
      }
      if (permission == LocationPermission.deniedForever) throw 'Location permissions are permanently denied.';

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String locAddress = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';

      // Advanced Fallback: Never stop check-in if reverse geocoding fails
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude).timeout(const Duration(seconds: 5));
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final addr = '${pm.street ?? ''}, ${pm.subLocality ?? ''}, ${pm.locality ?? ''}, ${pm.administrativeArea ?? ''} - ${pm.postalCode ?? ''}'.trim();
          locAddress = addr.replaceAll(RegExp(r'^,\s*'), '').replaceAll(RegExp(r',\s*,'), ',');
        }
      } catch (geoError) {
        debugPrint('Reverse geocoding failed, falling back to coordinates: $geoError');
      }

      _safeSetState(() {
        _checkInTime = DateTime.now();
        _status = 'In Progress';
        _checkInLat = position.latitude;
        _checkInLng = position.longitude;
        _gpsAddress = locAddress;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked In successfully.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check-In Failed: $e'), backgroundColor: Colors.red));
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckOut() async {
    if (_checkInTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please Check-In first!'), backgroundColor: Colors.orange));
      return;
    }

    _safeSetState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String outAddress = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';

      try {
        List<Placemark> pms = await placemarkFromCoordinates(position.latitude, position.longitude).timeout(const Duration(seconds: 5));
        if (pms.isNotEmpty) {
          final pm = pms.first;
          outAddress = '${pm.street ?? ''}, ${pm.subLocality ?? ''}, ${pm.locality ?? ''}, ${pm.administrativeArea ?? ''}'.trim().replaceAll(RegExp(r'^,\s*'), '');
        }
      } catch (_) {}

      _safeSetState(() {
        _checkOutTime = DateTime.now();
        _checkOutLat = position.latitude;
        _checkOutLng = position.longitude;
        _checkOutAddress = outAddress;

        final diff = _checkOutTime!.difference(_checkInTime!);
        _visitDuration = '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
        _status = 'Completed';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked Out successfully.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check-out location failed. $e'), backgroundColor: Colors.red));
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _handleFileUpload() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
        withData: true,
      );

      if (result != null) {
        _safeSetState(() => _isLoading = true);
        for (var file in result.files) {
          if (file.bytes != null) {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final ref = FirebaseStorage.instance.ref().child('companies/${widget.companyId}/visits/$fileName');
            final uploadTask = ref.putData(file.bytes!);
            final snapshot = await uploadTask;
            final url = await snapshot.ref.getDownloadURL();

            _safeSetState(() {
              _attachmentsList.add('${file.name}|||$url|||$_selectedDocumentCategory');
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  void _navigateToAddCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddCustomer(
          companyId: widget.companyId,
          currentUserUid: widget.currentUserId,
          currentUserRole: 'sales',
        ),
      ),
    );
    if (result == true) {
      await _fetchCustomers();
    }
  }

  Future<void> _createInquiry() async {
    if (_selectedCustomerId == null || _selectedContactData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select customer and contact first.'), backgroundColor: Colors.red));
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'draft_inquiry_${widget.companyId}_${widget.currentUserId}';

      final draftPayload = <String, dynamic>{
        'subject': 'Visit Reference: ${_visitNumberCtrl.text}',
        'customerId': _selectedCustomerId,
        'customerNameSnapshot': _selectedCustomerData?['name'] ?? _selectedCustomerData?['companyName'] ?? '',
        'contactName': _selectedContactData?['name'] ?? '',
        'contactPhone': _contactMobileCtrl.text.trim(),
        'contactEmail': _contactEmailCtrl.text.trim(),
        'address': _selectedAddressData != null ? '${_selectedAddressData!['street'] ?? ''}, ${_selectedAddressData!['city'] ?? ''}' : '',
        'source': 'Customer Visit',
        'sourceId': widget.visit?.id ?? '',
        'sourceReference': _visitNumberCtrl.text,
        'lastFollowUpNote': _discussionNotesCtrl.text.trim(),
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await prefs.setString(draftKey, jsonEncode(draftPayload));
    } catch (e) {
      debugPrint('Failed to generate inquiry draft: $e');
    }

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => ScreensAddInquiry(
            companyId: widget.companyId,
            currentUserUid: widget.currentUserId,
            currentUserRole: 'sales',
          )
      ));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inquiry Module Opened. Context data auto-filled.'), backgroundColor: Colors.blue));
    }
  }

  Future<void> _showQuotationSearchDialog() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer first to search their quotations.')));
      return;
    }

    _safeSetState(() => _isLoading = true);
    try {
      final snap = await _firestore.collection('companies')
          .doc(widget.companyId)
          .collection('quotations')
          .where('customerId', isEqualTo: _selectedCustomerId)
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Reference Quotation'),
              content: SizedBox(
                  width: 500,
                  height: 400,
                  child: snap.docs.isEmpty
                      ? const Center(child: Text('No quotations found for this customer.'))
                      : ListView.builder(
                    itemCount: snap.docs.length,
                    itemBuilder: (c, i) {
                      final qData = snap.docs[i].data();
                      final qNo = qData['quotationNumber'] ?? 'Draft';
                      final amt = qData['grandTotal'] ?? 0;
                      final date = qData['date'] != null ? DateFormat('dd MMM yyyy').format((qData['date'] as Timestamp).toDate()) : '-';
                      final rev = qData['version'] ?? '1';

                      return ListTile(
                        title: Text('Quote: $qNo (Rev $rev)', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Amount: ₹$amt | Date: $date | Status: ${qData['status']}'),
                        onTap: () {
                          _safeSetState(() {
                            _linkedQuotationId = snap.docs[i].id;
                            _referenceQuotationNumber = qNo;
                            _quoteDateCtrl.text = date;
                            _quoteValueCtrl.text = amt.toString();
                            _quoteStatusCtrl.text = qData['status']?.toString() ?? 'Draft';
                            _quoteRevisionCtrl.text = rev.toString();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  )
              ),
            )
        );
      }
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Index Required'),
              content: const Text('Quotation search is currently unavailable because the required database index is building. Please contact your administrator.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            )
        );
        debugPrint('Index missing: ${e.message}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: ${e.message}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load quotations: $e')));
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  void _showAddAddressDialog() {
    if (_selectedCustomerId == null) return;

    String selectedType = 'Head Office';
    final List<String> addressTypes = ['Head Office', 'Factory', 'Branch Office', 'Warehouse', 'Site Office', 'Other'];
    final streetCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Address Type', border: OutlineInputBorder(), isDense: true),
                      items: addressTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setDialogState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField('Street', streetCtrl),
                    _buildDialogTextField('City', cityCtrl),
                    _buildDialogTextField('State', stateCtrl),
                    _buildDialogTextField('Pincode', pinCtrl),
                  ],
                ),
              );
            }
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newId = DateTime.now().millisecondsSinceEpoch.toString();
              final newAddress = {
                'id': newId,
                'type': selectedType,
                'street': streetCtrl.text.trim(),
                'city': cityCtrl.text.trim(),
                'state': stateCtrl.text.trim(),
                'pincode': pinCtrl.text.trim(),
              };

              await _firestore.collection('companies').doc(widget.companyId).collection('customers').doc(_selectedCustomerId).update({
                'addresses': FieldValue.arrayUnion([newAddress])
              });

              if (mounted) Navigator.pop(ctx);
              await _fetchCustomerDetails(_selectedCustomerId!);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    if (_selectedCustomerId == null) return;

    final nameCtrl = TextEditingController();
    final desigCtrl = TextEditingController();
    final mobCtrl = TextEditingController();
    final mailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogTextField('Name *', nameCtrl),
                    _buildDialogTextField('Designation', desigCtrl),
                    _buildDialogTextField('Phone *', mobCtrl, isNumber: true),
                    _buildDialogTextField('Email', mailCtrl),
                  ],
                ),
              );
            }
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || mobCtrl.text.trim().isEmpty) return;
              final newContact = {
                'name': nameCtrl.text.trim(),
                'designation': desigCtrl.text.trim(),
                'phone': mobCtrl.text.trim(),
                'email': mailCtrl.text.trim().toLowerCase(),
                'isActive': true,
              };

              await _firestore.collection('companies').doc(widget.companyId).collection('customers').doc(_selectedCustomerId).collection('contacts').add(newContact);
              if (mounted) Navigator.pop(ctx);
              await _fetchCustomerDetails(_selectedCustomerId!);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  Widget _buildDialogTextField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      ),
    );
  }

  void _applyContactAutoFill(Map<String, dynamic> data) {
    _contactMobileCtrl.text = (data['phone'] ?? data['mobile'] ?? data['mobileNo'] ?? data['contactNo'] ?? '').toString().trim();
    _contactEmailCtrl.text = (data['email'] ?? data['primaryEmail'] ?? '').toString().trim();
    _contactDesignationCtrl.text = (data['designation'] ?? '').toString().trim();
    _contactDepartmentCtrl.text = (data['department'] ?? '').toString().trim();
  }

  Future<void> _saveData() async {
    if (_selectedCustomerId == null || _selectedAddressData == null || _selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Customer, Address, and Contact.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    _safeSetState(() => _isLoading = true);

    try {
      final customerNameStr = _selectedCustomerData?['name'] ?? _selectedCustomerData?['companyName'] ?? '';
      final addressStr = '${_selectedAddressData!['type'] ?? ''} - ${_selectedAddressData!['street'] ?? ''}, ${_selectedAddressData!['city'] ?? ''}';

      // Build internal notes string carrying rich check-out/location data if model doesn't support them natively
      String deepGpsString = 'Check-In: $_gpsAddress';
      if (_checkOutAddress.isNotEmpty) {
        deepGpsString += ' | Check-Out: $_checkOutAddress';
      }
      final comprehensiveNotes = '${_internalNotesCtrl.text.trim()}\n\n[Location Data]\n$deepGpsString'.trim();

      final model = CustomerVisitModel(
        id: widget.visit?.id ?? '',
        companyId: widget.companyId,
        createdBy: widget.visit?.createdBy ?? widget.currentUserId,
        updatedBy: widget.currentUserId,
        visitNumber: _visitNumberCtrl.text,
        checkInTime: _checkInTime,
        checkOutTime: _checkOutTime,
        visitDuration: _visitDuration,
        gpsLocation: _gpsAddress, // Keeping primary model contract
        attachments: _attachmentsList,
        customerId: _selectedCustomerId!,
        customerName: customerNameStr,
        contactPerson: _selectedContactData?['name'] ?? '',
        designation: _contactDesignationCtrl.text.trim(),
        mobile: _contactMobileCtrl.text.trim(),
        email: _contactEmailCtrl.text.trim(),
        address: addressStr,
        location: _selectedAddressData?['city'] ?? '',
        assignedEmployee: _visitOwnerCtrl.text,
        purpose: _purpose == 'Other' && _otherPurposeCtrl.text.isNotEmpty ? _otherPurposeCtrl.text.trim() : _purpose,
        visitDate: _visitDate,
        priority: _priority,
        leadGenerated: _leadGenerated,
        linkedInquiryId: _linkedInquiryId,
        linkedQuotationId: _linkedQuotationId,
        linkedServiceTicketId: _linkedServiceTicketId,
        discussionNotes: _discussionNotesCtrl.text.trim(),
        quotationStatus: _quoteStatusCtrl.text.trim(), // Fixed Reference
        customerFeedback: _customerFeedbackCtrl.text.trim(),
        priceFeedback: _priceFeedbackCtrl.text.trim(),
        competitorFeedback: _competitorFeedbackCtrl.text.trim(),
        technicalTopics: _technicalTopicsCtrl.text.trim(),
        outstandingAmount: double.tryParse(_outstandingAmountCtrl.text) ?? 0.0,
        paymentCommitmentDate: _paymentCommitmentDate,
        paymentRemarks: _paymentRemarksCtrl.text.trim(),
        serviceObservation: _serviceObservationCtrl.text.trim(),
        actionTaken: _actionTakenCtrl.text.trim(),
        recommendation: _recommendationCtrl.text.trim(),
        complaintDescription: _complaintDescCtrl.text.trim(),
        complaintSeverity: _complaintSeverity,
        temporaryResolution: _temporaryResolutionCtrl.text.trim(),
        installationNotes: _installationNotesCtrl.text.trim(),
        machineStatus: _machineStatusCtrl.text.trim(),
        customerAcceptance: _customerAcceptanceCtrl.text.trim(),
        nextServiceDate: _nextServiceDate,
        internalNotes: comprehensiveNotes,
        followupRequired: _followupRequired,
        followupDate: _followupDate,
        followupType: _followupType,
        followupRemarks: _followupRemarksCtrl.text.trim(),
        outcome: _outcome,
        status: _status,
      );

      String savedId = '';
      if (widget.visit == null) {
        savedId = await _service.createVisit(widget.companyId, model);
      } else {
        await _service.updateVisit(widget.companyId, model);
        savedId = model.id;
      }

      if (_followupRequired && _followupDate != null) {
        await _firestore.collection('companies').doc(widget.companyId).collection('tasks').add({
          'title': 'Follow-up: $customerNameStr',
          'description': _followupRemarksCtrl.text.trim(),
          'dueDate': Timestamp.fromDate(_followupDate!),
          'taskType': _followupType,
          'priority': _followupPriority,
          'status': 'Open',
          'relatedTo': 'Customer Visit',
          'relatedId': savedId,
          'customerId': _selectedCustomerId,
          'assignedToUid': widget.currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.currentUserId,
          'isActive': true,
          'isDeleted': false,
        });
      }

      // Enhanced Rich Customer 360 Timeline
      await _firestore.collection('companies').doc(widget.companyId).collection('customers').doc(_selectedCustomerId).collection('timeline').add({
        'type': 'Visit',
        'action': 'Visit Recorded',
        'title': 'Visit: $_purpose',
        'description': 'Outcome: $_outcome | Notes: ${_discussionNotesCtrl.text.isNotEmpty ? _discussionNotesCtrl.text : "Logged successfully."}',
        'visitId': savedId,
        'visitNumber': _visitNumberCtrl.text,
        'purpose': _purpose,
        'outcome': _outcome,
        'contact': _selectedContactData?['name'] ?? '',
        'quotationReference': _referenceQuotationNumber,
        'inquiryReference': _linkedInquiryId,
        'serviceReference': _linkedServiceTicketId,
        'date': _visitDate != null ? Timestamp.fromDate(_visitDate!) : FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.currentUserId,
        'createdByName': _visitOwnerNameCtrl.text,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit Activity saved.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  // ==========================================
  // UI BUILDERS (MODERN CRM STYLE)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.visit == null ? 'Record Visit' : 'Edit Visit', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: FilledButton(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                onPressed: _saveData,
                child: const Text('Save Activity'),
              ),
            )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompactHeader(),
                  const SizedBox(height: 24),
                  _buildCustomerSection(),
                  const SizedBox(height: 24),
                  _buildDynamicWorkflowSection(),
                  const SizedBox(height: 24),
                  _buildFollowUpSection(),
                  const SizedBox(height: 24),
                  _buildTrackingSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 12),
              Text(_visitNumberCtrl.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(_visitOwnerCtrl.text, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text(_status.toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return _buildCRMCard(
      title: 'Customer Context',
      icon: Icons.business,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Autocomplete<QueryDocumentSnapshot<Map<String, dynamic>>>(
                  displayStringForOption: (opt) => opt.data()['name'] ?? opt.data()['companyName'] ?? '-',
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable<QueryDocumentSnapshot<Map<String, dynamic>>>.empty();
                    final query = textEditingValue.text.toLowerCase();
                    return _allCustomers.where((doc) {
                      final d = doc.data();
                      final searchStr = [
                        d['name'], d['companyName'], d['code'], d['customerCode'],
                        d['mobile'], d['phone'], d['email'], d['gstNo'], d['gst'],
                        d['city'], d['state'], d['industry'], d['industryType'],
                        d['contactPerson']
                      ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ').toLowerCase();
                      return searchStr.contains(query);
                    });
                  },
                  onSelected: (option) async {
                    _safeSetState(() {
                      _selectedCustomerId = option.id;
                      _selectedAddressData = null;
                      _selectedContactId = null;
                      _selectedContactData = null;
                    });
                    await _fetchCustomerDetails(option.id);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    if (_selectedCustomerData != null && controller.text.isEmpty) {
                      controller.text = _selectedCustomerData!['name'] ?? _selectedCustomerData!['companyName'] ?? '';
                    }
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Search Customer (Name, Code, Phone, City, GST...) *',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _selectedCustomerId != null
                            ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              controller.clear();
                              _safeSetState(() {
                                _selectedCustomerId = null;
                                _selectedCustomerData = null;
                                _selectedAddressData = null;
                                _selectedContactId = null;
                                _selectedContactData = null;
                              });
                            })
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      validator: (v) => _selectedCustomerId == null ? 'Customer required' : null,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Customer'),
                onPressed: _navigateToAddCustomer,
              )
            ],
          ),
          if (_selectedCustomerData != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedAddressData,
                    decoration: InputDecoration(labelText: 'Location / Address *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
                    items: _customerAddresses.map((addr) => DropdownMenuItem(value: addr, child: Text('${addr['type'] ?? ''} - ${addr['city'] ?? ''}', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _onAddressSelected,
                    validator: (v) => v == null ? 'Address required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(icon: const Icon(Icons.add_location_alt_outlined), onPressed: _showAddAddressDialog, tooltip: 'Add Address'),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedContactId,
                    decoration: InputDecoration(labelText: 'Select Contact Person *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
                    items: _getFilteredContacts().map((doc) {
                      final d = doc.data();
                      final name = d['name'] ?? 'Unknown';
                      return DropdownMenuItem(value: doc.id, child: Text(name, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      _safeSetState(() {
                        _selectedContactId = val;
                        if (val != null) {
                          _selectedContactData = _getFilteredContacts().firstWhere((d) => d.id == val).data();
                          _applyContactAutoFill(_selectedContactData!);
                        }
                      });
                    },
                    validator: (v) => v == null ? 'Contact required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(icon: const Icon(Icons.person_add_alt_outlined), onPressed: _showAddContactDialog, tooltip: 'Add Contact'),
              ],
            ),

            // Contact Person UX Rework
            if (_selectedContactData != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.shade50.withOpacity(0.4), border: Border.all(color: Colors.blue.shade100), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contact_mail_outlined, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildReadOnlyField('Name', TextEditingController(text: _selectedContactData?['name'] ?? '-'), Icons.person)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildReadOnlyField('Designation', _contactDesignationCtrl, Icons.badge)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildReadOnlyField('Department', _contactDepartmentCtrl, Icons.business_center)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildReadOnlyField('Mobile', _contactMobileCtrl, Icons.phone)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildReadOnlyField('Email', _contactEmailCtrl, Icons.email)),
                      ],
                    ),
                  ],
                ),
              )
            ]
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDatePicker('Visit Date', _visitDate, (d) => _safeSetState(() => _visitDate = d))),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildDropdown('Purpose', _purpose, _purposeOptions, (v) {
                    _safeSetState(() {
                      _purpose = v!;
                      _resetOutcome();
                    });
                  })
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildDropdown('Priority', _priority, ['Low', 'Medium', 'High', 'Critical'], (v) => _safeSetState(() => _priority = v!))),
            ],
          ),
          if (_purpose == 'Other') ...[
            const SizedBox(height: 12),
            _buildTextField(_otherPurposeCtrl, 'Specify Reason', required: true)
          ]
        ],
      ),
    );
  }

  Widget _buildDynamicWorkflowSection() {
    List<Widget> children = [];

    switch (_purpose) {
      case 'Inquiry Generation':
        children.addAll([
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Inquiry Generated?', style: TextStyle(fontWeight: FontWeight.bold)),
            value: _leadGenerated,
            onChanged: (val) => _safeSetState(() => _leadGenerated = val),
            activeColor: Theme.of(context).primaryColor,
          ),
          if (_leadGenerated) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
                onPressed: _createInquiry,
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Create Inquiry (Sales Module)')
            ),
          ],
          const SizedBox(height: 16),
          _buildTextField(_discussionNotesCtrl, 'Lead Description / Notes', maxLines: 4),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            child: _buildDropdown('Outcome / Stage', _outcome, _getOutcomeOptions(), (v) => _safeSetState(() => _outcome = v!)),
          ),
        ]);
        break;

      case 'Quotation Discussion':
        children.addAll([
          Row(
            children: [
              Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showQuotationSearchDialog,
                    icon: const Icon(Icons.search),
                    label: const Text('Search & Link Existing Quotation'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  )
              ),
            ],
          ),
          if (_linkedQuotationId.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Linked Quotation Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildReadOnlyField('Quotation No.', TextEditingController(text: _referenceQuotationNumber), Icons.receipt_long)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildReadOnlyField('Date', _quoteDateCtrl, Icons.calendar_today)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildReadOnlyField('Value', _quoteValueCtrl, Icons.monetization_on)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildReadOnlyField('Status', _quoteStatusCtrl, Icons.info_outline)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildReadOnlyField('Revision', _quoteRevisionCtrl, Icons.history)),
                    ],
                  )
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildTextField(_customerFeedbackCtrl, 'Customer Feedback', maxLines: 2),
          _buildTextField(_priceFeedbackCtrl, 'Price Feedback', maxLines: 2),
          _buildTextField(_competitorFeedbackCtrl, 'Competitor Feedback', maxLines: 2),
          Row(
            children: [
              Expanded(child: _buildDatePicker('Expected Closure Date', _paymentCommitmentDate, (d) => _safeSetState(() => _paymentCommitmentDate = d))),
              const SizedBox(width: 16),
              Expanded(child: _buildDropdown('Outcome', _outcome, _getOutcomeOptions(), (val) => _safeSetState(() => _outcome = val!))),
            ],
          ),
        ]);
        break;

      case 'Payment Follow-up':
        children.addAll([
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red.shade50.withOpacity(0.5), border: Border.all(color: Colors.red.shade100), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Finance Snapshot', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildReadOnlyField('Outstanding Amount', _outstandingAmountCtrl, Icons.money_off)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildReadOnlyField('Overdue Amount', _overdueAmountCtrl, Icons.warning_amber)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildReadOnlyField('Last Payment Date', _lastPaymentDateCtrl, Icons.history)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildReadOnlyField('Credit Limit', _creditLimitCtrl, Icons.account_balance)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDatePicker('Payment Commitment Date', _paymentCommitmentDate, (d) => _safeSetState(() => _paymentCommitmentDate = d))),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_committedAmountCtrl, 'Committed Amount (₹)', isNumber: true)),
            ],
          ),
          _buildTextField(_paymentRemarksCtrl, 'Collection Remarks', maxLines: 3),
          SizedBox(
            width: 300,
            child: _buildDropdown('Outcome', _outcome, _getOutcomeOptions(), (val) => _safeSetState(() => _outcome = val!)),
          ),
        ]);
        break;

      case 'Service Visit':
      case 'Complaint Visit':
      case 'AMC Visit':
        children.addAll([
          OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service Module integration pending.'))),
              icon: const Icon(Icons.build_circle_outlined),
              label: const Text('Create Service Ticket')
          ),
          const SizedBox(height: 16),
          _buildTextField(_serviceObservationCtrl, 'Service Observation / Issue', maxLines: 3),
          _buildTextField(_actionTakenCtrl, 'Action Taken', maxLines: 3),
          _buildTextField(_recommendationCtrl, 'Recommendations', maxLines: 2),
          _buildTextField(_discussionNotesCtrl, 'Additional Notes', maxLines: 2),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            child: _buildDropdown('Outcome', _outcome, _getOutcomeOptions(), (val) => _safeSetState(() => _outcome = val!)),
          ),
        ]);
        break;

      case 'Machine Demo':
      case 'Technical Discussion':
        children.addAll([
          _buildTextField(_technicalTopicsCtrl, 'Technical Topics Discussed', maxLines: 2),
          _buildTextField(_discussionNotesCtrl, 'Detailed Notes', maxLines: 4),
          _buildDropdown('Outcome', _outcome, _getOutcomeOptions(), (val) => _safeSetState(() => _outcome = val!)),
        ]);
        break;

      case 'Installation':
        children.addAll([
          _buildTextField(_machineStatusCtrl, 'Machine Status'),
          _buildTextField(_installationNotesCtrl, 'Installation Notes', maxLines: 3),
          _buildTextField(_customerAcceptanceCtrl, 'Customer Acceptance / Sign-off Remarks', maxLines: 2),
          _buildDropdown('Outcome', _outcome, _getOutcomeOptions(), (val) => _safeSetState(() => _outcome = val!)),
        ]);
        break;

      case 'AMC Visit':
        children.addAll([
          _buildTextField(_serviceObservationCtrl, 'Service Notes', maxLines: 3),
          _buildTextField(_recommendationCtrl, 'Recommendations', maxLines: 2),
          _buildDatePicker('Next AMC Service Date', _nextServiceDate, (d) => _safeSetState(() => _nextServiceDate = d)),
        ]);
        break;

      default:
        children.addAll([
          _buildTextField(_discussionNotesCtrl, 'Discussion Notes', maxLines: 4),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            child: _buildDropdown('Outcome', _outcome, _getOutcomeOptions(), (val) => _safeSetState(() => _outcome = val!)),
          ),
        ]);
        break;
    }

    children.add(const SizedBox(height: 16));
    children.add(const Divider());
    children.add(const SizedBox(height: 16));
    children.add(_buildTextField(_internalNotesCtrl, 'Internal Notes (Hidden from customer reports)', maxLines: 2));

    return _buildCRMCard(
      title: '$_purpose Details',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildFollowUpSection() {
    return _buildCRMCard(
      title: 'Next Actions',
      icon: Icons.next_plan_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Schedule Follow-Up Task', style: TextStyle(fontWeight: FontWeight.bold)),
            value: _followupRequired,
            activeColor: Theme.of(context).primaryColor,
            onChanged: (val) => _safeSetState(() => _followupRequired = val),
          ),
          if (_followupRequired) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDatePicker('Date', _followupDate, (d) => _safeSetState(() => _followupDate = d))),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdown('Type', _followupType, ['Call', 'Email', 'Visit', 'WhatsApp', 'Meeting'], (v) => _safeSetState(() => _followupType = v!))),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdown('Priority', _followupPriority, ['High', 'Medium', 'Low'], (v) => _safeSetState(() => _followupPriority = v!))),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(_followupRemarksCtrl, 'Follow-up Details', maxLines: 2),
          ]
        ],
      ),
    );
  }

  Widget _buildTrackingSection() {
    return _buildCRMCard(
      title: 'Tracking & Documents',
      icon: Icons.satellite_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_gpsAddress.isNotEmpty) ...[
            Text('📍 In: $_gpsAddress', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 4),
          ],
          if (_checkOutAddress.isNotEmpty) ...[
            Text('📍 Out: $_checkOutAddress', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.login, size: 18, color: _checkInTime == null ? Colors.blue : Colors.green),
                  label: Text(_checkInTime == null ? 'Check-In' : 'Checked In: ${DateFormat('hh:mm a').format(_checkInTime!)}'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _checkInTime == null ? _handleCheckIn : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.logout, size: 18, color: _checkOutTime == null ? Colors.grey : Colors.orange),
                  label: Text(_checkOutTime == null ? 'Check-Out' : 'Checked Out: ${DateFormat('hh:mm a').format(_checkOutTime!)}'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: (_checkInTime != null && _checkOutTime == null) ? _handleCheckOut : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (_attachmentsList.isEmpty)
                      const Text('No files attached.', style: TextStyle(color: Colors.grey, fontSize: 13))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachmentsList.map((str) {
                          final name = str.split('|||')[0];
                          return Chip(
                            label: Text(name, style: const TextStyle(fontSize: 11)),
                            onDeleted: () => _safeSetState(() => _attachmentsList.remove(str)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(color: Colors.grey.shade300),
                          );
                        }).toList(),
                      )
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Upload'),
                onPressed: _handleFileUpload,
              )
            ],
          )
        ],
      ),
    );
  }

  // --- REUSABLE BUILDERS ---

  Widget _buildCRMCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
        ),
        validator: required ? (v) => v == null || v.isEmpty ? 'Required field' : null : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    if (!items.contains(value) && value.isNotEmpty) items.add(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? (items.isNotEmpty ? items.first : null) : value,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, void Function(DateTime) onDateSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) onDateSelected(date);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
          child: Text(selectedDate != null ? DateFormat('dd MMM yyyy').format(selectedDate) : 'Select Date'),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
    );
  }
}