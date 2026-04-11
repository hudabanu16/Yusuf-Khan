import 'package:flutter/material.dart';
import 'package:QUIK/modules/service/complaints/screen_complaint_form.dart';


class ComplaintListScreen extends StatelessWidget {
  const ComplaintListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Complaints',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ComplaintFormScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Complaint'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Column(
            children: [
              SizedBox(height: 80),
              Icon(
                Icons.report_problem_outlined,
                size: 52,
                color: Color(0xFF6B7280),
              ),
              SizedBox(height: 12),
              Text(
                'No complaints found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Create your first complaint to start service tracking.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}