import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DialogSelectCustomer extends StatefulWidget {
  final String companyId;

  const DialogSelectCustomer({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  @override
  State<DialogSelectCustomer> createState() =>
      _DialogSelectCustomerState();
}

class _DialogSelectCustomerState
    extends State<DialogSelectCustomer> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _safe(String? val) => (val ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        height: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Customer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3A52),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),

            const SizedBox(height: 12),

            // SEARCH
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, email, phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
            ),

            const SizedBox(height: 12),

            // LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('companies')
                    .doc(widget.companyId)
                    .collection('customers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No customers found.'));
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data =
                    doc.data() as Map<String, dynamic>;

                    // SAFE DELETE CHECK
                    if (data['isDeleted'] == true) return false;

                    final name = _safe(data['companyName'] ??
                        data['name'])
                        .toLowerCase();
                    final email =
                    _safe(data['email']).toLowerCase();
                    final phone = _safe(
                        data['mobile'] ?? data['phone'])
                        .toLowerCase();

                    return _searchQuery.isEmpty ||
                        name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('No matching customers.'));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data =
                      doc.data() as Map<String, dynamic>;

                      final name = _safe(
                          data['companyName'] ?? data['name']);
                      final email = _safe(data['email']);
                      final phone =
                      _safe(data['mobile'] ?? data['phone']);

                      return InkWell(
                        onTap: () {
                          data['id'] = doc.id;
                          Navigator.pop(context, data);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                const Color(0xFF1A3A52)
                                    .withOpacity(0.1),
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                      color: Color(0xFF1A3A52),
                                      fontWeight:
                                      FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // DETAILS
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.isEmpty
                                          ? 'Unknown Customer'
                                          : name,
                                      style: const TextStyle(
                                          fontWeight:
                                          FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      email.isNotEmpty
                                          ? email
                                          : phone.isNotEmpty
                                          ? phone
                                          : 'No contact info',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),

                              // SELECT ICON
                              const Icon(Icons.arrow_forward_ios,
                                  size: 14, color: Colors.grey)
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}