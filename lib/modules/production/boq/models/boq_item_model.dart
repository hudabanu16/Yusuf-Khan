import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/boq/services/boq_calculation_service.dart';
import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class BoqItemModel {
  final String itemId;
  final int lineNo;
  final String description;
  final String section;
  final String gradeOfSteel;
  final String finish;
  final String coatingThickness;
  final double length;
  final double quantity;
  final String quantityMode;
  final double piecesPerUnit;
  final double numberOfUnits;
  final double extraQuantity;
  final double calculatedQuantity;
  final double unitWeight;
  final double componentWeight;
  final double totalWeight;
  final double totalWeightWithFinish;
  final String? linkedItemId;
  final String? linkedBomId;

  const BoqItemModel({
    required this.itemId,
    required this.lineNo,
    required this.description,
    required this.section,
    this.gradeOfSteel = '',
    this.finish = '',
    this.coatingThickness = '',
    required this.length,
    required this.quantity,
    this.quantityMode = 'manual',
    this.piecesPerUnit = 0,
    this.numberOfUnits = 0,
    this.extraQuantity = 0,
    this.calculatedQuantity = 0,
    required this.unitWeight,
    required this.componentWeight,
    required this.totalWeight,
    this.totalWeightWithFinish = 0,
    this.linkedItemId,
    this.linkedBomId,
  });

  double get calculatedComponentWeight {
    return BoqCalculationService.componentWeight(
      length: length,
      unitWeight: unitWeight,
    );
  }

  double get calculatedTotalWeight {
    return BoqCalculationService.lineTotalWeight(
      length: length,
      unitWeight: unitWeight,
      quantity: quantity,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lineNo': lineNo,
      'description': description,
      'section': section,
      'gradeOfSteel': gradeOfSteel,
      'finish': finish,
      'coatingThickness': coatingThickness,
      'length': length,
      'quantity': quantity,
      'quantityMode': quantityMode,
      'piecesPerUnit': piecesPerUnit,
      'numberOfUnits': numberOfUnits,
      'extraQuantity': extraQuantity,
      'calculatedQuantity': calculatedQuantity,
      'unitWeight': unitWeight,
      'componentWeight': calculatedComponentWeight,
      'totalWeight': calculatedTotalWeight,
      'totalWeightWithFinish': totalWeightWithFinish == 0
          ? calculatedTotalWeight
          : totalWeightWithFinish,
      'linkedItemId': linkedItemId,
      'linkedBomId': linkedBomId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory BoqItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final length = doubleFromValue(data['length']);
    final quantity = doubleFromValue(data['quantity']);
    final unitWeight = doubleFromValue(data['unitWeight']);
    final calculatedComponentWeight = BoqCalculationService.componentWeight(
      length: length,
      unitWeight: unitWeight,
    );
    final calculatedTotalWeight = BoqCalculationService.lineTotalWeight(
      length: length,
      unitWeight: unitWeight,
      quantity: quantity,
    );

    return BoqItemModel(
      itemId: snapshot.id,
      lineNo: intFromValue(data['lineNo']),
      description: (data['description'] ?? '').toString(),
      section: (data['section'] ?? '').toString(),
      gradeOfSteel: (data['gradeOfSteel'] ?? '').toString(),
      finish: (data['finish'] ?? '').toString(),
      coatingThickness: (data['coatingThickness'] ?? '').toString(),
      length: length,
      quantity: quantity,
      quantityMode: (data['quantityMode'] ?? 'manual').toString(),
      piecesPerUnit: doubleFromValue(data['piecesPerUnit']),
      numberOfUnits: doubleFromValue(data['numberOfUnits']),
      extraQuantity: doubleFromValue(data['extraQuantity']),
      calculatedQuantity: doubleFromValue(data['calculatedQuantity']),
      unitWeight: unitWeight,
      componentWeight: doubleFromValue(data['componentWeight']) == 0
          ? calculatedComponentWeight
          : doubleFromValue(data['componentWeight']),
      totalWeight: doubleFromValue(data['totalWeight']) == 0
          ? calculatedTotalWeight
          : doubleFromValue(data['totalWeight']),
      totalWeightWithFinish: doubleFromValue(data['totalWeightWithFinish']) == 0
          ? calculatedTotalWeight
          : doubleFromValue(data['totalWeightWithFinish']),
      linkedItemId: data['linkedItemId']?.toString(),
      linkedBomId: data['linkedBomId']?.toString(),
    );
  }
}
