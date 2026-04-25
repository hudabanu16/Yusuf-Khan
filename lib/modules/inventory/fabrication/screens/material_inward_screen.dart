import 'package:flutter/material.dart';

import 'package:QUIK/modules/inventory/fabrication/models/raw_material_inward_model.dart';
import 'package:QUIK/modules/inventory/fabrication/repositories/fabrication_inventory_repository.dart';
import 'package:QUIK/modules/inventory/fabrication/screens/material_inward_form_screen.dart';
import 'package:QUIK/modules/inventory/fabrication/widgets/fabrication_inventory_flow_card.dart';
import 'package:QUIK/modules/production/core/production_list_scaffold.dart';

class FabricationMaterialInwardScreen extends StatelessWidget {
  final String tenantId;
  final bool purchaseView;

  const FabricationMaterialInwardScreen({
    super.key,
    required this.tenantId,
    this.purchaseView = false,
  });

  @override
  Widget build(BuildContext context) {
    final repository = FabricationInventoryRepository(tenantId: tenantId);

    return ProductionListScaffold<RawMaterialInwardModel>(
      title: purchaseView ? 'GRN / Material Receipt' : 'Material Inward',
      subtitle: purchaseView
          ? 'Receive supplier material in ERP. Saving the GRN increases raw material stock immediately.'
          : 'Record steel received from supplier challans before it becomes available in fabrication stock.',
      icon: Icons.move_to_inbox_outlined,
      stream: repository.watchInwardEntries(),
      intro: FabricationInventoryFlowCard(
        activeStep: FabricationInventoryFlowStep.inward,
        helperText: purchaseView
            ? 'This is the stock receipt step. When a GRN is saved here, the material becomes available in the raw material stock register. Purchase billing should be entered separately after or along with receipt verification.'
            : 'Use this screen when pipes, sheets, angles, channels, or plates physically arrive at the factory. The store team should enter supplier name, challan number, received section, grade, length, and quantity.',
      ),
      emptyTitle: purchaseView
          ? 'No GRN or material receipts recorded yet'
          : 'No material receipts recorded yet',
      emptyMessage: purchaseView
          ? 'Create a GRN whenever raw material reaches the factory gate or store. This should be the transaction that increases available stock.'
          : 'Start here when raw material is unloaded at the factory. Each inward entry should represent a supplier receipt so stock can later be matched with the live raw material register.',
      headerAction: FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MaterialInwardFormScreen(
              tenantId: tenantId,
              purchaseView: purchaseView,
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(purchaseView ? 'New GRN' : 'New Receipt'),
      ),
      itemBuilder: (context, item) {
        final subtitle = [
          if (item.inwardDate != null) _formatDate(item.inwardDate!),
          if (item.supplierName.isNotEmpty) item.supplierName,
          if (item.challanNo.isNotEmpty) 'Challan ${item.challanNo}',
          if (item.grade.isNotEmpty) item.grade,
          if (item.lengthMm > 0) '${item.lengthMm.toStringAsFixed(0)} mm',
          if (item.unitWeightKgPerM > 0)
            '${item.unitWeightKgPerM.toStringAsFixed(2)} kg/m',
        ].join(' • ');

        return ProductionListTile(
          icon: Icons.move_to_inbox_outlined,
          title: item.materialDescription.isEmpty
              ? 'Received material'
              : item.materialDescription,
          subtitle: subtitle.isEmpty
              ? 'Add supplier, challan, grade, and received length details'
              : subtitle,
          trailing: '${item.quantityKg.toStringAsFixed(2)} kg',
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
