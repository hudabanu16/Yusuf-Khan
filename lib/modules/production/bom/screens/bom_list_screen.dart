import 'package:flutter/material.dart';

import 'package:QUIK/modules/production/bom/models/bom_header_model.dart';
import 'package:QUIK/modules/production/bom/repositories/bom_repository.dart';
import 'package:QUIK/modules/production/bom/screens/bom_editor_screen.dart';
import 'package:QUIK/modules/production/core/production_list_scaffold.dart';

class BomListScreen extends StatelessWidget {
  final String tenantId;

  const BomListScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final repository = BomRepository(tenantId: tenantId);

    return ProductionListScaffold<BomHeaderModel>(
      title: 'BOM',
      subtitle:
          'Manufacturing recipes, revisions, drawings, and process routing',
      icon: Icons.schema_outlined,
      stream: repository.watchBomHeaders(),
      emptyTitle: 'No BOMs yet',
      emptyMessage:
          'Create BOM headers and lines for rafters, columns, purlins, plates, and assemblies.',
      headerAction: FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BomEditorScreen(tenantId: tenantId),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New BOM'),
      ),
      itemBuilder: (context, bom) {
        return ProductionListTile(
          icon: Icons.schema_outlined,
          title: '${bom.bomCode}  ${bom.bomName}',
          subtitle: 'Rev ${bom.revisionNo} • Drawing ${bom.drawingNo}',
          trailing: bom.status,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BomEditorScreen(tenantId: tenantId, bom: bom),
            ),
          ),
        );
      },
    );
  }
}
