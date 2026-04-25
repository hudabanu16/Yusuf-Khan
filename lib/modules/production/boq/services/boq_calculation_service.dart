class BoqCalculationService {
  const BoqCalculationService._();

  static double componentWeight({
    required double length,
    required double unitWeight,
    bool lengthInMillimeters = false,
  }) {
    final lengthInMeters = lengthInMillimeters ? length / 1000 : length;
    return lengthInMeters * unitWeight;
  }

  static double lineTotalWeight({
    required double length,
    required double unitWeight,
    required num quantity,
    bool lengthInMillimeters = false,
  }) {
    return componentWeight(
          length: length,
          unitWeight: unitWeight,
          lengthInMillimeters: lengthInMillimeters,
        ) *
        quantity;
  }
}
