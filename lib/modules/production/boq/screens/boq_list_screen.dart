import 'package:flutter/material.dart';

import 'package:QUIK/modules/production/boq/models/boq_model.dart';
import 'package:QUIK/modules/production/boq/repositories/boq_repository.dart';
import 'package:QUIK/modules/production/boq/screens/boq_editor_screen.dart';
import 'package:QUIK/modules/production/core/production_list_scaffold.dart';

class BoqListScreen extends StatelessWidget {
  final String tenantId;

  const BoqListScreen({super.key, required this.tenantId});

  Future<void> _openEditor(BuildContext context, {BoqModel? boq}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BoqEditorScreen(tenantId: tenantId, boq: boq),
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('BOQ saved successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = BoqRepository(tenantId: tenantId);

    return ProductionListScaffold<BoqModel>(
      title: 'BOQ',
      subtitle: 'Project quantity and weight sheets for fabrication jobs',
      icon: Icons.calculate_outlined,
      stream: repository.watchBoqs(),
      emptyTitle: 'No BOQs yet',
      emptyMessage:
          'Create project BOQs with section, length, quantity, unit weight, and calculated total weight.',
      headerAction: FilledButton.icon(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New BOQ'),
      ),
      itemBuilder: (context, boq) {
        return ProductionListTile(
          icon: Icons.calculate_outlined,
          title: '${boq.boqNo}  ${boq.projectName}',
          subtitle:
              '${boq.clientName} • ${boq.moduleType} • ${boq.capacityKW.toStringAsFixed(0)} kW',
          trailing: '${boq.totalWeight.toStringAsFixed(2)} kg',
          onTap: () => _openEditor(context, boq: boq),
        );
      },
    );
  }
}
