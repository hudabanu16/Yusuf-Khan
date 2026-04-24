import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';

enum FabricationInventoryFlowStep { inward, stock, issue }

class FabricationInventoryFlowCard extends StatelessWidget {
  final FabricationInventoryFlowStep activeStep;
  final String helperText;

  const FabricationInventoryFlowCard({
    super.key,
    required this.activeStep,
    required this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How fabrication inventory works',
            style: TextStyle(
              color: zText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'In a fabrication company, raw material usually moves in three steps: receive from supplier, keep section-wise stock balance, then issue to cutting or production.',
            style: TextStyle(
              color: zMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FlowStepTile(
                stepNumber: '1',
                title: 'Material Inward',
                description:
                    'Enter supplier challan, section, grade, length, and received qty.',
                active: activeStep == FabricationInventoryFlowStep.inward,
                icon: Icons.move_to_inbox_outlined,
              ),
              _FlowStepTile(
                stepNumber: '2',
                title: 'Raw Material Stock',
                description:
                    'Track opening, received, issued, and closing balance for each section.',
                active: activeStep == FabricationInventoryFlowStep.stock,
                icon: Icons.inventory_2_outlined,
              ),
              _FlowStepTile(
                stepNumber: '3',
                title: 'Material Issue',
                description:
                    'Send stock to cutting, punching, welding, or a work order.',
                active: activeStep == FabricationInventoryFlowStep.issue,
                icon: Icons.outbox_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: zSurfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: zBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: zBlue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    helperText,
                    style: const TextStyle(
                      color: zText,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStepTile extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String description;
  final bool active;
  final IconData icon;

  const _FlowStepTile({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.active,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = active ? zBlue : zBorder;
    final backgroundColor = active ? zBlueSoft : zSurfaceSoft;

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: active ? zBlue : Colors.white,
                child: active
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        stepNumber,
                        style: const TextStyle(
                          color: zText,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: active ? zBlue : zMuted, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: zText,
              fontSize: 13.8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: zMuted,
              fontSize: 12.4,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
