import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class BoqModel {
  final String boqId;
  final String boqNo;
  final String clientName;
  final String epcContractor;
  final String projectName;
  final String moduleType;
  final double moduleWattPeak;
  final double pileDepthConsidered;
  final double groundClearance;
  final double dcCapacity;
  final List<BoqModuleQuantityModel> moduleQuantities;
  final double capacityKW;
  final double tiltAngle;
  final double totalWeight;
  final double totalWeightInclFinish;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BoqModel({
    required this.boqId,
    required this.boqNo,
    required this.clientName,
    this.epcContractor = '',
    required this.projectName,
    required this.moduleType,
    this.moduleWattPeak = 0,
    this.pileDepthConsidered = 0,
    this.groundClearance = 0,
    this.dcCapacity = 0,
    this.moduleQuantities = const [],
    required this.capacityKW,
    required this.tiltAngle,
    required this.totalWeight,
    this.totalWeightInclFinish = 0,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'boqId': boqId,
      'boqNo': boqNo,
      'clientName': clientName,
      'epcContractor': epcContractor,
      'projectName': projectName,
      'moduleType': moduleType,
      'moduleWattPeak': moduleWattPeak,
      'pileDepthConsidered': pileDepthConsidered,
      'groundClearance': groundClearance,
      'dcCapacity': dcCapacity,
      'moduleQuantities': moduleQuantities
          .map((moduleQuantity) => moduleQuantity.toMap())
          .toList(growable: false),
      'capacityKW': capacityKW,
      'tiltAngle': tiltAngle,
      'totalWeight': totalWeight,
      'totalWeightInclFinish': totalWeightInclFinish == 0
          ? totalWeight
          : totalWeightInclFinish,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory BoqModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return BoqModel(
      boqId: (data['boqId'] ?? snapshot.id).toString(),
      boqNo: (data['boqNo'] ?? '').toString(),
      clientName: (data['clientName'] ?? '').toString(),
      epcContractor: (data['epcContractor'] ?? '').toString(),
      projectName: (data['projectName'] ?? '').toString(),
      moduleType: (data['moduleType'] ?? '').toString(),
      moduleWattPeak: doubleFromValue(data['moduleWattPeak']),
      pileDepthConsidered: doubleFromValue(data['pileDepthConsidered']),
      groundClearance: doubleFromValue(data['groundClearance']),
      dcCapacity: doubleFromValue(data['dcCapacity']),
      moduleQuantities: BoqModuleQuantityModel.listFromValue(
        data['moduleQuantities'],
      ),
      capacityKW: doubleFromValue(data['capacityKW']),
      tiltAngle: doubleFromValue(data['tiltAngle']),
      totalWeight: doubleFromValue(data['totalWeight']),
      totalWeightInclFinish: doubleFromValue(data['totalWeightInclFinish']),
      status: (data['status'] ?? 'draft').toString(),
      createdAt: dateTimeFromValue(data['createdAt']),
      updatedAt: dateTimeFromValue(data['updatedAt']),
    );
  }
}

class BoqModuleQuantityModel {
  final String label;
  final double quantity;
  final String uom;

  const BoqModuleQuantityModel({
    required this.label,
    required this.quantity,
    this.uom = 'Nos',
  });

  Map<String, dynamic> toMap() {
    return {'label': label, 'quantity': quantity, 'uom': uom};
  }

  factory BoqModuleQuantityModel.fromMap(Map<String, dynamic> data) {
    return BoqModuleQuantityModel(
      label: (data['label'] ?? '').toString(),
      quantity: doubleFromValue(data['quantity']),
      uom: (data['uom'] ?? 'Nos').toString(),
    );
  }

  static List<BoqModuleQuantityModel> listFromValue(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => BoqModuleQuantityModel.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((item) => item.label.trim().isNotEmpty)
        .toList(growable: false);
  }
}
