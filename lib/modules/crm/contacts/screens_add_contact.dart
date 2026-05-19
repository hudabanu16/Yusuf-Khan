import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_contact/add_contact_widgets.dart';

part 'add_contact/add_contact_form_sections.dart';
part 'add_contact/add_contact_header_footer.dart';
part 'add_contact/add_contact_layout_sections.dart';

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

      final companyName = (data['companyName'] ?? data['name'] ?? '')
          .toString();

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

  void _setPrimaryContact(bool? value) {
    setState(() {
      _isPrimary = value ?? false;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Contact' : 'Add Contact')),
      body: _isLoadingCompany
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(child: _buildScrollableContent()),
                  _buildBottomSaveBar(),
                ],
              ),
            ),
    );
  }
}
