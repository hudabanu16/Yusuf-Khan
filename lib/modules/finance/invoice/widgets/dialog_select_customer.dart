import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DialogSelectCustomer extends StatefulWidget {
  final String companyId;

  const DialogSelectCustomer({Key? key, required this.companyId}) : super(key: key);

  @override
  State<DialogSelectCustomer> createState() => _DialogSelectCustomerState();
}

class _DialogSelectCustomerState extends State<DialogSelectCustomer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Customer Master',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A3A52)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by company name, email, or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // 🔥 FIX: Removed the strict .where() clause that was blocking legacy documents
                stream: FirebaseFirestore.instance
                    .collection('companies')
                    .doc(widget.companyId)
                    .collection('customers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No customers found in master.'));
                  }

                  // 🔥 FIX: Securely filter the documents in Dart
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // 1. Safe delete check (handles null if the field doesn't exist)
                    if (data['isDeleted'] == true) return false;

                    // 2. Search query match
                    final name = (data['companyName'] ?? data['name'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    final phone = (data['mobile'] ?? data['phone'] ?? '').toString().toLowerCase();

                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('No matching customers found.'));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final companyName = (data['companyName'] ?? data['name'] ?? 'Unknown').toString();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1A3A52).withOpacity(0.1),
                          child: Text(
                            companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C',
                            style: const TextStyle(color: Color(0xFF1A3A52), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(companyName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${data['email'] ?? 'No Email'} • ${data['mobile'] ?? data['phone'] ?? 'No Phone'}'),
                        onTap: () {
                          // Inject ID and return full map
                          data['id'] = docs[index].id;
                          Navigator.pop(context, data);
                        },
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