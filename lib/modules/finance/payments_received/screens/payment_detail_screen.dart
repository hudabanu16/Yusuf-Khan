import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import 'payments_list_screen.dart'; // To reuse the UserNameWidget

class PaymentDetailScreen extends StatelessWidget {
  final String companyId;
  final PaymentModel payment;

  const PaymentDetailScreen({
    super.key,
    required this.companyId,
    required this.payment,
  });

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'INR': return '₹';
      case 'AED': return 'د.إ';
      case 'SGD': return 'S\$';
      default: return currency;
    }
  }

  String _getPaymentStatus() {
    if (payment.advanceAmount > 0 && payment.allocatedAmount == 0) return 'ADVANCE';
    if (payment.allocatedAmount >= payment.totalAmount) return 'ALLOCATED';
    if (payment.allocatedAmount > 0) return 'PARTIAL';
    return 'UNALLOCATED';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ADVANCE': return Colors.purple.shade600;
      case 'ALLOCATED': return Colors.green.shade600;
      case 'PARTIAL': return Colors.orange.shade600;
      case 'UNALLOCATED': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getPaymentStatus();
    final statusColor = _getStatusColor(status);
    final sym = _getCurrencySymbol(payment.currency);
    final fmt = NumberFormat('#,##0.00', 'en_IN');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(payment.customerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(payment.receiptNumber, style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  const Text('•', style: TextStyle(color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  Text(DateFormat('dd MMM yyyy').format(payment.paymentDate), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 24),

                    // Amount Breakdown
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Received', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('$sym ${fmt.format(payment.totalAmount)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                              if (payment.currency != 'INR')
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('≈ ₹ ${fmt.format(payment.amountInr)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 50, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 24)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Allocated', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('$sym ${fmt.format(payment.allocatedAmount)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Advance', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('$sym ${fmt.format(payment.advanceAmount)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Transaction Details
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Transaction Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildDetailField('Payment Mode', payment.paymentMode.isNotEmpty ? payment.paymentMode : 'N/A')),
                        Expanded(child: _buildDetailField('Reference No.', payment.referenceNo.isNotEmpty ? payment.referenceNo : 'N/A')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildDetailField('Currency', payment.currency)),
                        Expanded(child: _buildDetailField('Exchange Rate', payment.currency == 'INR' ? '1.0' : payment.exchangeRate.toString())),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Audit Trail
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), // Slate 100
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history, size: 18, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text('Audit Trail', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserNameWidget(companyId: companyId, uid: payment.createdBy, prefix: 'Created by: ', fallbackName: payment.createdByName),
                            const SizedBox(height: 4),
                            Text(DateFormat('dd MMM yyyy, hh:mm a').format(payment.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        if (payment.updatedBy != null && payment.updatedBy!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              UserNameWidget(companyId: companyId, uid: payment.updatedBy!, prefix: 'Updated by: ', fallbackName: payment.updatedByName),
                              const SizedBox(height: 4),
                              Text(payment.updatedAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(payment.updatedAt!) : 'N/A', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }
}