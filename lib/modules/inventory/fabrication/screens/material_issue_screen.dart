import 'package:flutter/material.dart';

import 'package:QUIK/modules/inventory/fabrication/models/raw_material_issue_model.dart';
import 'package:QUIK/modules/inventory/fabrication/repositories/fabrication_inventory_repository.dart';
import 'package:QUIK/modules/inventory/fabrication/screens/material_issue_form_screen.dart';
import 'package:QUIK/modules/inventory/fabrication/widgets/fabrication_inventory_flow_card.dart';
import 'package:QUIK/modules/production/core/production_list_scaffold.dart';

class FabricationMaterialIssueScreen extends StatelessWidget {
  final String tenantId;

  const FabricationMaterialIssueScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final repository = FabricationInventoryRepository(tenantId: tenantId);

    return ProductionListScaffold<RawMaterialIssueModel>(
      title: 'Material Issue',
      subtitle:
          'Record material sent from store to cutting, punching, welding, or a work order.',
      icon: Icons.outbox_outlined,
      stream: repository.watchIssueEntries(),
      intro: const FabricationInventoryFlowCard(
        activeStep: FabricationInventoryFlowStep.issue,
        helperText:
            'Use this screen after store approval, when raw material leaves stock for production. Issues can be against a work order, a fabrication stage, or a team such as cutting, drilling, or welding.',
      ),
      emptyTitle: 'No material issues recorded yet',
      emptyMessage:
          'Record an issue whenever steel is given to the shop floor. This keeps stock accurate and helps track how much material has been consumed against jobs or production stages.',
      headerAction: FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MaterialIssueFormScreen(tenantId: tenantId),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Issue'),
      ),
      itemBuilder: (context, item) {
        final subtitle = [
          if (item.issueDate != null) _formatDate(item.issueDate!),
          if (item.issuedTo.isNotEmpty) item.issuedTo,
          if (item.workOrderId.isNotEmpty) 'WO ${item.workOrderId}',
          if (item.grade.isNotEmpty) item.grade,
          if (item.lengthMm > 0) '${item.lengthMm.toStringAsFixed(0)} mm',
          if (item.unitWeightKgPerM > 0)
            '${item.unitWeightKgPerM.toStringAsFixed(2)} kg/m',
        ].join(' • ');

        return ProductionListTile(
          icon: Icons.outbox_outlined,
          title: item.materialDescription.isEmpty
              ? 'Issued material'
              : item.materialDescription,
          subtitle: subtitle.isEmpty
              ? 'Add the receiving team, work order, and issued section details'
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
