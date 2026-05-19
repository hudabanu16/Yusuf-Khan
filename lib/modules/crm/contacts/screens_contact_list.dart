import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/crm/contacts/screens_add_contact.dart';

class ScreensContactList extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String companyName;

  const ScreensContactList({
    super.key,
    required this.companyRef,
    required this.companyName,
  });

  @override
  State<ScreensContactList> createState() => _ScreensContactListState();
}

class _ScreensContactListState extends State<ScreensContactList> {
  final TextEditingController _search = TextEditingController();

  bool _onlyPrimary = false;
  bool _onlyWithEmail = false;
  bool _onlyWithPhone = false;

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  bool _tableView = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadCurrentUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data();
  }

  bool _isAdminOrManager(String role) {
    return role == 'admin' || role == 'manager';
  }

  void _sortRows(List<_ContactRow> rows) {
    rows.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 1:
          cmp = a.email.toLowerCase().compareTo(b.email.toLowerCase());
          break;
        case 2:
          cmp = a.phone.toLowerCase().compareTo(b.phone.toLowerCase());
          break;
        case 3:
          cmp = a.designation.toLowerCase().compareTo(
            b.designation.toLowerCase(),
          );
          break;
        case 4:
          cmp = a.department.toLowerCase().compareTo(
            b.department.toLowerCase(),
          );
          break;
        case 5:
          cmp = (a.isPrimary ? 1 : 0).compareTo(b.isPrimary ? 1 : 0);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please login again.')));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadCurrentUserProfile(currentUser.uid),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('Contacts - ${widget.companyName}')),
            body: Center(
              child: Text('Error loading user profile: ${userSnap.error}'),
            ),
          );
        }

        final userData = userSnap.data ?? {};
        final role = (userData['role'] ?? '').toString();

        return LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 980;
            final allowTableView = c.maxWidth >= 1100;

            if (!allowTableView && _tableView) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _tableView = false);
                }
              });
            }

            return Scaffold(
              backgroundColor: const Color(0xFFEEF2F7),
              appBar: AppBar(
                title: Text('Contacts - ${widget.companyName}'),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: c.maxWidth < 700
                        ? IconButton(
                            tooltip: 'Add Contact',
                            onPressed: _goAddContact,
                            icon: const Icon(Icons.add),
                          )
                        : FilledButton.icon(
                            onPressed: _goAddContact,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Contact'),
                          ),
                  ),
                ],
              ),
              body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: widget.companyRef.get(),
                builder: (context, customerSnap) {
                  if (customerSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (customerSnap.hasError) {
                    return Center(
                      child: Text(
                        'Error loading company: ${customerSnap.error}',
                      ),
                    );
                  }

                  if (!customerSnap.hasData || !customerSnap.data!.exists) {
                    return const Center(child: Text('Company not found.'));
                  }

                  final customerData = customerSnap.data!.data() ?? {};
                  final createdBy = (customerData['createdBy'] ?? '')
                      .toString();
                  final assignedToUid = (customerData['assignedToUid'] ?? '')
                      .toString();

                  final hasAccess =
                      _isAdminOrManager(role) ||
                      createdBy == currentUser.uid ||
                      assignedToUid == currentUser.uid;

                  if (!hasAccess) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        constraints: const BoxConstraints(maxWidth: 520),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE4E8F0)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_outline, size: 44),
                            SizedBox(height: 10),
                            Text(
                              'Access Denied',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'You do not have permission to view contacts of this customer.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final contactsRef = widget.companyRef.collection('contacts');

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: contactsRef.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading contacts: ${snapshot.error}',
                          ),
                        );
                      }

                      final docs = (snapshot.data?.docs ?? []).toList();

                      final rows = docs.map((d) {
                        final m = d.data();
                        return _ContactRow(
                          doc: d,
                          name: (m['name'] ?? '').toString(),
                          email: (m['email'] ?? '').toString(),
                          phone: (m['phone'] ?? '').toString(),
                          designation: (m['designation'] ?? '').toString(),
                          department: (m['department'] ?? '').toString(),
                          isPrimary: m['isPrimary'] == true,
                        );
                      }).toList();

                      final q = _search.text.trim().toLowerCase();
                      var filtered = rows.where((r) {
                        if (q.isEmpty) return true;
                        return r.name.toLowerCase().contains(q) ||
                            r.email.toLowerCase().contains(q) ||
                            r.phone.toLowerCase().contains(q) ||
                            r.designation.toLowerCase().contains(q) ||
                            r.department.toLowerCase().contains(q);
                      }).toList();

                      if (_onlyPrimary) {
                        filtered = filtered.where((r) => r.isPrimary).toList();
                      }
                      if (_onlyWithEmail) {
                        filtered = filtered
                            .where((r) => r.email.trim().isNotEmpty)
                            .toList();
                      }
                      if (_onlyWithPhone) {
                        filtered = filtered
                            .where((r) => r.phone.trim().isNotEmpty)
                            .toList();
                      }

                      _sortRows(filtered);

                      final primaryCount = rows
                          .where((e) => e.isPrimary)
                          .length;
                      final withEmailCount = rows
                          .where((e) => e.email.trim().isNotEmpty)
                          .length;
                      final withPhoneCount = rows
                          .where((e) => e.phone.trim().isNotEmpty)
                          .length;

                      if (isWide) {
                        return Row(
                          children: [
                            SizedBox(
                              width: 320,
                              child: _filterPanel(
                                total: rows.length,
                                primaryCount: primaryCount,
                                withEmailCount: withEmailCount,
                                withPhoneCount: withPhoneCount,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  children: [
                                    _companySummaryHeader(
                                      total: filtered.length,
                                      primaryCount: primaryCount,
                                      withEmailCount: withEmailCount,
                                      withPhoneCount: withPhoneCount,
                                      onToggleView: allowTableView
                                          ? () => setState(
                                              () => _tableView = !_tableView,
                                            )
                                          : null,
                                      showToggle: allowTableView,
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: filtered.isEmpty
                                          ? _emptyState()
                                          : (_tableView && allowTableView)
                                          ? _contactsTable(filtered)
                                          : _contactsList(filtered),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            _companySummaryHeader(
                              total: filtered.length,
                              primaryCount: primaryCount,
                              withEmailCount: withEmailCount,
                              withPhoneCount: withPhoneCount,
                              onToggleView: null,
                              showToggle: false,
                              compact: true,
                            ),
                            const SizedBox(height: 10),
                            _mobileFilterBar(),
                            const SizedBox(height: 10),
                            Expanded(
                              child: filtered.isEmpty
                                  ? _emptyState()
                                  : _contactsList(filtered),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _companySummaryHeader({
    required int total,
    required int primaryCount,
    required int withEmailCount,
    required int withPhoneCount,
    required VoidCallback? onToggleView,
    required bool showToggle,
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.people_alt_outlined,
                        color: Color(0xFF2457C5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage contact persons linked to this customer',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showToggle && !compact && onToggleView != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onToggleView,
                  icon: Icon(_tableView ? Icons.view_list : Icons.table_rows),
                  label: Text(_tableView ? 'List View' : 'Table View'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _SummaryPill(label: 'Visible Contacts', value: '$total'),
                _SummaryPill(label: 'Primary', value: '$primaryCount'),
                _SummaryPill(label: 'With Email', value: '$withEmailCount'),
                _SummaryPill(label: 'With Phone', value: '$withPhoneCount'),
              ];

              if (constraints.maxWidth < 640) {
                return Wrap(spacing: 8, runSpacing: 8, children: cards);
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[2]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[3]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mobileFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search contacts',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF7F8FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Primary'),
                  selected: _onlyPrimary,
                  onSelected: (v) => setState(() => _onlyPrimary = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Has Email'),
                  selected: _onlyWithEmail,
                  onSelected: (v) => setState(() => _onlyWithEmail = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Has Phone'),
                  selected: _onlyWithPhone,
                  onSelected: (v) => setState(() => _onlyWithPhone = v),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _onlyPrimary = false;
                      _onlyWithEmail = false;
                      _onlyWithPhone = false;
                      _search.clear();
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final hasFilters =
        _search.text.trim().isNotEmpty ||
        _onlyPrimary ||
        _onlyWithEmail ||
        _onlyWithPhone;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFFE8F0FF),
              child: Icon(
                hasFilters ? Icons.search_off : Icons.people_outline,
                size: 32,
                color: const Color(0xFF2457C5),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters ? 'No matching contacts found' : 'No contacts found',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try changing search or filters.'
                  : 'Add contacts to this customer to manage communication and decision makers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            if (hasFilters)
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _onlyPrimary = false;
                    _onlyWithEmail = false;
                    _onlyWithPhone = false;
                    _search.clear();
                  });
                },
                child: const Text('Reset Filters'),
              )
            else
              FilledButton.icon(
                onPressed: _goAddContact,
                icon: const Icon(Icons.add),
                label: const Text('Add Contact'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterPanel({
    required int total,
    required int primaryCount,
    required int withEmailCount,
    required int withPhoneCount,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E8F0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: const [
                  Icon(Icons.filter_alt_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF7F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SideMetricTile(
                label: 'Total Contacts',
                value: '$total',
                icon: Icons.people_outline,
              ),
              const SizedBox(height: 8),
              _SideMetricTile(
                label: 'Primary Contacts',
                value: '$primaryCount',
                icon: Icons.star_border,
              ),
              const SizedBox(height: 8),
              _SideMetricTile(
                label: 'With Email',
                value: '$withEmailCount',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 8),
              _SideMetricTile(
                label: 'With Phone',
                value: '$withPhoneCount',
                icon: Icons.phone_outlined,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick Filters',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _onlyPrimary,
                onChanged: (v) => setState(() => _onlyPrimary = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Primary Contacts'),
              ),
              CheckboxListTile(
                value: _onlyWithEmail,
                onChanged: (v) => setState(() => _onlyWithEmail = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Has Email'),
              ),
              CheckboxListTile(
                value: _onlyWithPhone,
                onChanged: (v) => setState(() => _onlyWithPhone = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Has Phone'),
              ),
              const Spacer(),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _onlyPrimary = false;
                        _onlyWithEmail = false;
                        _onlyWithPhone = false;
                        _search.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactsList(List<_ContactRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = rows[i];
          return _ContactCard(
            row: r,
            onEdit: () => _editContact(r),
            onDelete: () => _deleteContact(r),
          );
        },
      ),
    );
  }

  Widget _contactsTable(List<_ContactRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 380,
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  columnSpacing: 24,
                  headingRowHeight: 46,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  columns: [
                    DataColumn(
                      label: const Text('Contact Name'),
                      onSort: (i, asc) => setState(() {
                        _sortColumnIndex = i;
                        _sortAscending = asc;
                      }),
                    ),
                    DataColumn(
                      label: const Text('Email'),
                      onSort: (i, asc) => setState(() {
                        _sortColumnIndex = i;
                        _sortAscending = asc;
                      }),
                    ),
                    DataColumn(
                      label: const Text('Phone'),
                      onSort: (i, asc) => setState(() {
                        _sortColumnIndex = i;
                        _sortAscending = asc;
                      }),
                    ),
                    DataColumn(
                      label: const Text('Designation'),
                      onSort: (i, asc) => setState(() {
                        _sortColumnIndex = i;
                        _sortAscending = asc;
                      }),
                    ),
                    DataColumn(
                      label: const Text('Department'),
                      onSort: (i, asc) => setState(() {
                        _sortColumnIndex = i;
                        _sortAscending = asc;
                      }),
                    ),
                    DataColumn(
                      label: const Text('Primary'),
                      onSort: (i, asc) => setState(() {
                        _sortColumnIndex = i;
                        _sortAscending = asc;
                      }),
                    ),
                    const DataColumn(label: Text('Actions')),
                  ],
                  rows: rows.map((r) {
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Text(
                              r.name.isEmpty ? '-' : r.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onTap: () => _editContact(r),
                        ),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              r.email.isEmpty ? '-' : r.email,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 140,
                            child: Text(
                              r.phone.isEmpty ? '-' : r.phone,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 160,
                            child: Text(
                              r.designation.isEmpty ? '-' : r.designation,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 160,
                            child: Text(
                              r.department.isEmpty ? '-' : r.department,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Icon(
                            r.isPrimary
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: r.isPrimary ? Colors.green : Colors.grey,
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueGrey,
                                ),
                                onPressed: () => _editContact(r),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteContact(r),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goAddContact() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddContact(companyRef: widget.companyRef),
      ),
    );
  }

  void _editContact(_ContactRow r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScreensAddContact(companyRef: widget.companyRef, contactDoc: r.doc),
      ),
    );
  }

  Future<void> _deleteContact(_ContactRow r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Delete "${r.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await r.doc.reference.delete();

        final companySnap = await widget.companyRef.get();
        final companyData = companySnap.data() ?? {};
        final oldCount = (companyData['contactsCount'] ?? 0) as num;

        await widget.companyRef.update({
          'contactsCount': oldCount > 0 ? oldCount - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SideMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final _ContactRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (row.designation.isNotEmpty) row.designation,
      if (row.department.isNotEmpty) row.department,
    ];

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE8F0FF),
                  child: Text(
                    row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF2457C5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text(
                            row.name.isEmpty ? '(No Name)' : row.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if (row.isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                'Primary',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitleParts.join(' • '),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (row.email.isNotEmpty)
                            _MiniBadge(
                              icon: Icons.email_outlined,
                              text: row.email,
                            ),
                          if (row.phone.isNotEmpty)
                            _MiniBadge(
                              icon: Icons.phone_outlined,
                              text: row.phone,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit Contact')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Contact'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.blueGrey.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final String name;
  final String email;
  final String phone;
  final String designation;
  final String department;
  final bool isPrimary;

  _ContactRow({
    required this.doc,
    required this.name,
    required this.email,
    required this.phone,
    required this.designation,
    required this.department,
    required this.isPrimary,
  });
}
