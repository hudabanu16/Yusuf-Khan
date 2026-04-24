import 'package:flutter/material.dart';

import 'package:QUIK/modules/inventory/fabrication/models/raw_material_purchase_bill_model.dart';
import 'package:QUIK/modules/inventory/fabrication/repositories/fabrication_inventory_repository.dart';
import 'package:QUIK/modules/inventory/fabrication/widgets/fabrication_inventory_flow_card.dart';
import 'package:QUIK/modules/production/core/production_list_scaffold.dart';
import 'package:QUIK/modules/purchase/fabrication/screens/purchase_bill_form_screen.dart';

class FabricationPurchaseBillScreen extends StatelessWidget {
  final String tenantId;

  const FabricationPurchaseBillScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final repository = FabricationInventoryRepository(tenantId: tenantId);

    return ProductionListScaffold<RawMaterialPurchaseBillModel>(
      title: 'Purchase Bills',
      subtitle:
          'Enter supplier bills after GRN so finance and stock stay linked but separate.',
      icon: Icons.receipt_long_outlined,
      stream: repository.watchPurchaseBills(),
      intro: const FabricationInventoryFlowCard(
        activeStep: FabricationInventoryFlowStep.inward,
        helperText:
            'Use GRN / Material Receipt when steel physically arrives. Use Purchase Bills when the supplier invoice is booked in accounts. Billing should not create stock twice.',
      ),
      emptyTitle: 'No purchase bills recorded yet',
      emptyMessage:
          'After the store team completes a GRN or material receipt, accounts can enter the supplier bill here and link it to the received material.',
      headerAction: FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PurchaseBillFormScreen(tenantId: tenantId),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Bill'),
      ),
      itemBuilder: (context, bill) {
        final subtitle = [
          if (bill.billDate != null) _formatDate(bill.billDate!),
          if (bill.supplierName.isNotEmpty) bill.supplierName,
          if (bill.supplierBillNo.isNotEmpty) 'Bill ${bill.supplierBillNo}',
          if (bill.linkedChallanNo.isNotEmpty) 'GRN ${bill.linkedChallanNo}',
        ].join(' • ');

        return ProductionListTile(
          icon: Icons.receipt_long_outlined,
          title: bill.supplierBillNo.isEmpty
              ? 'Supplier bill'
              : bill.supplierBillNo,
          subtitle: subtitle.isEmpty
              ? 'Add supplier bill and link it to a receipt'
              : subtitle,
          trailing: 'Rs ${bill.billAmount.toStringAsFixed(2)}',
        );
      },
    );
  }

  static String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}
