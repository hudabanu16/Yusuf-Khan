import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScreensCustomerFollowUpList extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String customerName;

  const ScreensCustomerFollowUpList({
    super.key,
    required this.customerRef,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.customerName,
  });

  @override
  State<ScreensCustomerFollowUpList> createState() =>
      _ScreensCustomerFollowUpListState();
}

class _ScreensCustomerFollowUpListState
    extends State<ScreensCustomerFollowUpList> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _modeFilter = '';
  String _outcomeFilter = '';
  String _dueFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _modeFilter.isNotEmpty || _outcomeFilter.isNotEmpty || _dueFilter.isNotEmpty;

  void _resetFilters() {
    setState(() {
      _modeFilter = '';
      _outcomeFilter = '';
      _dueFilter = '';
    });
  }

  Future<void> _openFilterSheet() async {
    String tempMode = _modeFilter;
    String tempOutcome = _outcomeFilter;
    String tempDue = _dueFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: tempMode.isEmpty ? null : tempMode,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Mode',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _followUpModeOptions
                      .map(
                        (e) => DropdownMenuItem<String>(
                      value: e.toLowerCase(),
                      child: Text(e),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    tempMode = value ?? '';
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempOutcome.isEmpty ? null : tempOutcome,
                  decoration: const InputDecoration(
                    labelText: 'Outcome',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _followUpOutcomeOptions
                      .map(
                        (e) => DropdownMenuItem<String>(
                      value: e.toLowerCase(),
                      child: Text(e),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    tempOutcome = value ?? '';
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempDue.isEmpty ? null : tempDue,
                  decoration: const InputDecoration(
                    labelText: 'Next Follow-up Due',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'overdue',
                      child: Text('Overdue'),
                    ),
                    DropdownMenuItem(
                      value: 'today',
                      child: Text('Today'),
                    ),
                    DropdownMenuItem(
                      value: 'upcoming',
                      child: Text('Upcoming'),
                    ),
                    DropdownMenuItem(
                      value: 'no_next_date',
                      child: Text('No Next Date'),
                    ),
                  ],
                  onChanged: (value) {
                    tempDue = value ?? '';
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _modeFilter = '';
                            _outcomeFilter = '';
                            _dueFilter = '';
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _modeFilter = tempMode;
                            _outcomeFilter = tempOutcome;
                            _dueFilter = tempDue;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddFollowUpDialog() async {
    final discussionController = TextEditingController();
    final nextActionController = TextEditingController();

    String selectedMode = 'Phone Call';
    String selectedOutcome = 'Follow-up Done';
    DateTime followUpDateTime = DateTime.now();
    DateTime? nextFollowUpDate;

    String? selectedContactId = '';
    String selectedContactName = '';
    String selectedContactPhone = '';
    String selectedContactEmail = '';
    String selectedContactDesignation = '';

    Future<void> pickFollowUpDateTime(StateSetter setModalState) async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: followUpDateTime,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

      if (pickedDate == null) return;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(followUpDateTime),
      );

      if (pickedTime == null) return;

      setModalState(() {
        followUpDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }

    Future<void> pickNextFollowUpDate(StateSetter setModalState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: nextFollowUpDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

      if (picked == null) return;

      setModalState(() {
        nextFollowUpDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          10,
          0,
        );
      });
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Follow-up'),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: widget.customerRef
                            .collection('contacts')
                            .where('isActive', isEqualTo: true)
                            .snapshots(),
                        builder: (context, contactSnap) {
                          final contactDocs = contactSnap.data?.docs ?? [];

                          return DropdownButtonFormField<String>(
                            initialValue: selectedContactId,
                            decoration: const InputDecoration(
                              labelText: 'Contact Person',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No specific contact'),
                              ),
                              ...contactDocs.map((doc) {
                                final data = doc.data();
                                final name =
                                (data['name'] ?? '').toString().trim();
                                final designation =
                                (data['designation'] ?? '').toString().trim();
                                final phone =
                                (data['phone'] ?? '').toString().trim();

                                final title = [
                                  name,
                                  if (designation.isNotEmpty) designation,
                                  if (phone.isNotEmpty) phone,
                                ].join(' • ');

                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(
                                    title.isEmpty ? doc.id : title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setModalState(() {
                                selectedContactId = value;

                                if (value == null || value.isEmpty) {
                                  selectedContactName = '';
                                  selectedContactPhone = '';
                                  selectedContactEmail = '';
                                  selectedContactDesignation = '';
                                  return;
                                }

                                final selectedDoc = contactDocs.firstWhere(
                                      (e) => e.id == value,
                                );

                                final data = selectedDoc.data();
                                selectedContactName =
                                    (data['name'] ?? '').toString().trim();
                                selectedContactPhone =
                                    (data['phone'] ?? '').toString().trim();
                                selectedContactEmail =
                                    (data['email'] ?? '').toString().trim();
                                selectedContactDesignation =
                                    (data['designation'] ?? '').toString().trim();
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMode,
                        decoration: const InputDecoration(
                          labelText: 'Follow-up Mode',
                          prefixIcon: Icon(Icons.call_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: _followUpModeOptions
                            .map(
                              (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ),
                        )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedMode = value ?? 'Phone Call';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedOutcome,
                        decoration: const InputDecoration(
                          labelText: 'Outcome',
                          prefixIcon: Icon(Icons.track_changes_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: _followUpOutcomeOptions
                            .map(
                              (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ),
                        )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedOutcome = value ?? 'Follow-up Done';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => pickFollowUpDateTime(setModalState),
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Follow-up Date & Time',
                            prefixIcon: Icon(Icons.schedule_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_formatDateTime(followUpDateTime)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: discussionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Discussion / What was discussed *',
                          prefixIcon: Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nextActionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Next Action',
                          prefixIcon: Icon(Icons.playlist_add_check_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => pickNextFollowUpDate(setModalState),
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Next Follow-up Date',
                            prefixIcon: Icon(Icons.event_repeat_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            nextFollowUpDate == null
                                ? 'Select next follow-up date'
                                : _formatDateOnly(nextFollowUpDate!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    final discussion = discussionController.text.trim();
                    final nextAction = nextActionController.text.trim();

                    if (discussion.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter discussion details'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setModalState(() => isSubmitting = true);

                    try {
                      final followUpsRef =
                      widget.customerRef.collection('followUps');

                      await followUpsRef.add({
                        'companyId': widget.companyId,
                        'customerId': widget.customerRef.id,
                        'customerName': widget.customerName,
                        'contactId': selectedContactId ?? '',
                        'contactName': selectedContactName,
                        'contactPhone': selectedContactPhone,
                        'contactEmail': selectedContactEmail,
                        'contactDesignation': selectedContactDesignation,
                        'followUpDate':
                        Timestamp.fromDate(followUpDateTime),
                        'followUpMode': selectedMode,
                        'discussion': discussion,
                        'outcome': selectedOutcome,
                        'nextAction': nextAction,
                        'nextFollowUpDate': nextFollowUpDate != null
                            ? Timestamp.fromDate(nextFollowUpDate!)
                            : null,
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdByUid': widget.currentUserUid,
                        'createdByName': widget.currentUserName,
                        'updatedAt': FieldValue.serverTimestamp(),
                        'updatedByUid': widget.currentUserUid,
                        'updatedByName': widget.currentUserName,
                      });

                      final latestSnap = await followUpsRef
                          .orderBy('followUpDate', descending: true)
                          .limit(1)
                          .get();

                      final totalSnap = await followUpsRef.get();

                      if (latestSnap.docs.isNotEmpty) {
                        final latestData = latestSnap.docs.first.data();

                        await widget.customerRef.update({
                          'lastFollowUpAt': latestData['followUpDate'],
                          'lastFollowUpByUid':
                          latestData['createdByUid'] ?? '',
                          'lastFollowUpByName':
                          latestData['createdByName'] ?? '',
                          'lastFollowUpMode':
                          latestData['followUpMode'] ?? '',
                          'lastFollowUpSummary':
                          latestData['discussion'] ?? '',
                          'lastFollowUpOutcome':
                          latestData['outcome'] ?? '',
                          'nextFollowUpDate':
                          latestData['nextFollowUpDate'],
                          'followUpCount': totalSnap.docs.length,
                          'updatedAt': FieldValue.serverTimestamp(),
                          'updatedBy': widget.currentUserUid,
                          'updatedByUid': widget.currentUserUid,
                          'updatedByName': widget.currentUserName,
                        });
                      }

                      if (!mounted) return;
                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Follow-up added successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to add follow-up: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setModalState(() => isSubmitting = false);
                      }
                    }
                  },
                  icon: isSubmitting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save Follow-up'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteFollowUp(String followUpId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete follow-up?'),
        content: const Text('This follow-up entry will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.customerRef.collection('followUps').doc(followUpId).delete();

      final latestSnap = await widget.customerRef
          .collection('followUps')
          .orderBy('followUpDate', descending: true)
          .limit(1)
          .get();

      final totalSnap = await widget.customerRef.collection('followUps').get();

      if (latestSnap.docs.isEmpty) {
        await widget.customerRef.update({
          'lastFollowUpAt': null,
          'lastFollowUpByUid': '',
          'lastFollowUpByName': '',
          'lastFollowUpMode': '',
          'lastFollowUpSummary': '',
          'lastFollowUpOutcome': '',
          'nextFollowUpDate': null,
          'followUpCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final latestData = latestSnap.docs.first.data();
        await widget.customerRef.update({
          'lastFollowUpAt': latestData['followUpDate'],
          'lastFollowUpByUid': latestData['createdByUid'] ?? '',
          'lastFollowUpByName': latestData['createdByName'] ?? '',
          'lastFollowUpMode': latestData['followUpMode'] ?? '',
          'lastFollowUpSummary': latestData['discussion'] ?? '',
          'lastFollowUpOutcome': latestData['outcome'] ?? '',
          'nextFollowUpDate': latestData['nextFollowUpDate'],
          'followUpCount': totalSnap.docs.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete follow-up: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final query = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    return docs.where((doc) {
      final data = doc.data();

      final mode = (data['followUpMode'] ?? '').toString().toLowerCase();
      final outcome = (data['outcome'] ?? '').toString().toLowerCase();
      final discussion = (data['discussion'] ?? '').toString().toLowerCase();
      final nextAction = (data['nextAction'] ?? '').toString().toLowerCase();
      final contactName = (data['contactName'] ?? '').toString().toLowerCase();
      final contactPhone = (data['contactPhone'] ?? '').toString().toLowerCase();
      final contactEmail = (data['contactEmail'] ?? '').toString().toLowerCase();
      final createdByName =
      (data['createdByName'] ?? '').toString().toLowerCase();

      final nextFollowUpDate = _readDate(data['nextFollowUpDate']);
      final nextOnly = nextFollowUpDate == null
          ? null
          : DateTime(
        nextFollowUpDate.year,
        nextFollowUpDate.month,
        nextFollowUpDate.day,
      );

      final matchesSearch = query.isEmpty ||
          mode.contains(query) ||
          outcome.contains(query) ||
          discussion.contains(query) ||
          nextAction.contains(query) ||
          contactName.contains(query) ||
          contactPhone.contains(query) ||
          contactEmail.contains(query) ||
          createdByName.contains(query);

      final matchesMode =
          _modeFilter.isEmpty || mode == _modeFilter.trim().toLowerCase();

      final matchesOutcome = _outcomeFilter.isEmpty ||
          outcome == _outcomeFilter.trim().toLowerCase();

      bool matchesDue = true;
      if (_dueFilter == 'overdue') {
        matchesDue = nextOnly != null && nextOnly.isBefore(todayOnly);
      } else if (_dueFilter == 'today') {
        matchesDue = nextOnly != null && nextOnly == todayOnly;
      } else if (_dueFilter == 'upcoming') {
        matchesDue = nextOnly != null && nextOnly.isAfter(todayOnly);
      } else if (_dueFilter == 'no_next_date') {
        matchesDue = nextOnly == null;
      }

      return matchesSearch && matchesMode && matchesOutcome && matchesDue;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final followUpsRef = widget.customerRef.collection('followUps');

    return Scaffold(
      appBar: AppBar(
        title: Text('Follow-ups • ${widget.customerName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddFollowUpDialog,
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('Add Follow-up'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: followUpsRef.orderBy('followUpDate', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load follow-ups:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = _applyFilters(docs);

          final overdueCount = docs.where((doc) {
            final next = _readDate(doc.data()['nextFollowUpDate']);
            if (next == null) return false;
            final now = DateTime.now();
            final todayOnly = DateTime(now.year, now.month, now.day);
            final nextOnly = DateTime(next.year, next.month, next.day);
            return nextOnly.isBefore(todayOnly);
          }).length;

          final dueTodayCount = docs.where((doc) {
            final next = _readDate(doc.data()['nextFollowUpDate']);
            if (next == null) return false;
            final now = DateTime.now();
            final todayOnly = DateTime(now.year, now.month, now.day);
            final nextOnly = DateTime(next.year, next.month, next.day);
            return nextOnly == todayOnly;
          }).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search follow-up, contact, outcome',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.trim().isEmpty
                                ? null
                                : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      width: 38,
                      child: Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _openFilterSheet,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: Colors.grey.shade800,
                              ),
                              if (_hasActiveFilters)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _MiniStatText(
                      label: 'Total',
                      value: docs.length.toString(),
                    ),
                    const SizedBox(width: 12),
                    _MiniStatText(
                      label: 'Overdue',
                      value: overdueCount.toString(),
                    ),
                    const SizedBox(width: 12),
                    _MiniStatText(
                      label: 'Today',
                      value: dueTodayCount.toString(),
                    ),
                  ],
                ),
              ),
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filters applied',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _resetFilters,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filteredDocs.isEmpty
                    ? _EmptyFollowUpState(
                  hasSearch:
                  _searchQuery.trim().isNotEmpty || _hasActiveFilters,
                  onReset: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _resetFilters();
                  },
                )
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();

                    final followUpDate = _readDate(data['followUpDate']);
                    final nextFollowUpDate =
                    _readDate(data['nextFollowUpDate']);
                    final createdByName =
                    (data['createdByName'] ?? '').toString();
                    final followUpMode =
                    (data['followUpMode'] ?? '').toString();
                    final discussion =
                    (data['discussion'] ?? '').toString();
                    final outcome = (data['outcome'] ?? '').toString();
                    final nextAction =
                    (data['nextAction'] ?? '').toString();
                    final contactName =
                    (data['contactName'] ?? '').toString();
                    final contactPhone =
                    (data['contactPhone'] ?? '').toString();
                    final contactEmail =
                    (data['contactEmail'] ?? '').toString();
                    final contactDesignation =
                    (data['contactDesignation'] ?? '').toString();

                    final dueMeta =
                    _buildDueMeta(nextFollowUpDate: nextFollowUpDate);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _MiniChip(
                                        label: followUpMode.isEmpty
                                            ? 'Follow-up'
                                            : followUpMode,
                                        background: Colors.blue.shade50,
                                        foreground:
                                        Colors.blue.shade800,
                                      ),
                                      if (outcome.isNotEmpty)
                                        _MiniChip(
                                          label: outcome,
                                          background:
                                          Colors.green.shade50,
                                          foreground:
                                          Colors.green.shade800,
                                        ),
                                      if (followUpDate != null)
                                        _MiniChip(
                                          label:
                                          _formatDateTime(followUpDate),
                                          background:
                                          Colors.grey.shade100,
                                          foreground:
                                          Colors.grey.shade800,
                                        ),
                                      if (dueMeta != null)
                                        _MiniChip(
                                          label: dueMeta.label,
                                          background: dueMeta.background,
                                          foreground: dueMeta.foreground,
                                        ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteFollowUp(doc.id);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete',
                                        style:
                                        TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (contactName.isNotEmpty ||
                                contactPhone.isNotEmpty ||
                                contactEmail.isNotEmpty ||
                                contactDesignation.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Contact',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  if (contactName.isNotEmpty)
                                    _MetaText(
                                      icon: Icons.person_outline,
                                      text: contactName,
                                    ),
                                  if (contactDesignation.isNotEmpty)
                                    _MetaText(
                                      icon: Icons.badge_outlined,
                                      text: contactDesignation,
                                    ),
                                  if (contactPhone.isNotEmpty)
                                    _MetaText(
                                      icon: Icons.phone_outlined,
                                      text: contactPhone,
                                    ),
                                  if (contactEmail.isNotEmpty)
                                    _MetaText(
                                      icon: Icons.email_outlined,
                                      text: contactEmail,
                                    ),
                                ],
                              ),
                            ],
                            if (discussion.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Discussion',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                discussion,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (nextAction.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Next Action',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nextAction,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 14,
                              runSpacing: 8,
                              children: [
                                if (createdByName.isNotEmpty)
                                  _MetaText(
                                    icon: Icons.badge_outlined,
                                    text: 'By: $createdByName',
                                  ),
                                if (nextFollowUpDate != null)
                                  _MetaText(
                                    icon: Icons.event_repeat_outlined,
                                    text:
                                    'Next: ${_formatDateOnly(nextFollowUpDate)}',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  _DueMeta? _buildDueMeta({required DateTime? nextFollowUpDate}) {
    if (nextFollowUpDate == null) return null;

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final nextOnly = DateTime(
      nextFollowUpDate.year,
      nextFollowUpDate.month,
      nextFollowUpDate.day,
    );

    if (nextOnly.isBefore(todayOnly)) {
      return _DueMeta(
        label: 'Overdue',
        background: Colors.red.shade50,
        foreground: Colors.red.shade800,
      );
    }

    if (nextOnly == todayOnly) {
      return _DueMeta(
        label: 'Due Today',
        background: Colors.orange.shade50,
        foreground: Colors.orange.shade800,
      );
    }

    return _DueMeta(
      label: 'Upcoming',
      background: Colors.teal.shade50,
      foreground: Colors.teal.shade800,
    );
  }
}

class _DueMeta {
  final String label;
  final Color background;
  final Color foreground;

  _DueMeta({
    required this.label,
    required this.background,
    required this.foreground,
  });
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaText({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade700),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _MiniChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatText({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyFollowUpState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyFollowUpState({
    required this.hasSearch,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.timeline_outlined,
              size: 46,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch ? 'No matching follow-ups found' : 'No follow-up history yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? 'Try changing the search text or filters.'
                  : 'Add calls, meetings, visits and discussions for this customer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            if (hasSearch)
              OutlinedButton(
                onPressed: onReset,
                child: const Text('Reset Filters'),
              ),
          ],
        ),
      ),
    );
  }
}

DateTime? _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();

  final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final amPm = value.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/$year $hour12:$minute $amPm';
}

String _formatDateOnly(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

const List<String> _followUpModeOptions = [
  'Phone Call',
  'WhatsApp',
  'Email',
  'Visit',
  'Meeting',
  'Video Call',
  'Demo',
  'Service Visit',
  'Other',
];

const List<String> _followUpOutcomeOptions = [
  'Follow-up Done',
  'Interested',
  'Very Interested',
  'Quotation Required',
  'Demo Required',
  'Negotiation Ongoing',
  'No Response',
  'Call Back Later',
  'Not Interested',
  'Order Expected',
  'Closed Won',
  'Closed Lost',
];