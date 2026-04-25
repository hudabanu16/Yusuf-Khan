import 'package:flutter/material.dart';

import 'package:QUIK/modules/production/core/production_list_scaffold.dart';
import 'package:QUIK/modules/production/masters/models/fabrication_item_model.dart';
import 'package:QUIK/modules/production/masters/repositories/item_repository.dart';
import 'package:QUIK/modules/production/masters/screens/item_form_screen.dart';

class ProductionItemListScreen extends StatelessWidget {
  final String tenantId;

  const ProductionItemListScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final repository = ItemRepository(tenantId: tenantId);

    return ProductionListScaffold<FabricationItemModel>(
      title: 'Items',
      subtitle: 'Tenant-specific fabrication item master',
      icon: Icons.widgets_outlined,
      stream: repository.watchItems(),
      emptyTitle: 'No production items yet',
      emptyMessage:
          'Create columns, rafters, purlins, plates, channels, assemblies, and raw material items.',
      headerAction: FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemFormScreen(tenantId: tenantId)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Item'),
      ),
      itemBuilder: (context, item) {
        return ProductionListTile(
          icon: Icons.widgets_outlined,
          title: '${item.itemCode}  ${item.itemName}',
          subtitle: '${item.section} • ${item.uom} • ${item.makeOrBuy}',
          trailing: '${item.unitWeight.toStringAsFixed(2)} kg/m',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemFormScreen(tenantId: tenantId, item: item),
            ),
          ),
        );
      },
    );
  }
}
