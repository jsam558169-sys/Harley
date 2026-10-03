/// Units of measurement selectable when adding an ingredient to a
/// product's recipe (e.g. "200 g of cheese" or "1 piece of bun").
enum MeasurementUnit { piece, gram, kilogram, milliliter, liter, bottle, custom }

extension MeasurementUnitX on MeasurementUnit {
  /// Label shown in the picker dropdown.
  String get displayLabel {
    switch (this) {
      case MeasurementUnit.piece:
        return 'Piece';
      case MeasurementUnit.gram:
        return 'Gram (g)';
      case MeasurementUnit.kilogram:
        return 'Kilogram (kg)';
      case MeasurementUnit.milliliter:
        return 'Milliliter (ml)';
      case MeasurementUnit.liter:
        return 'Liter (L)';
      case MeasurementUnit.bottle:
        return 'Bottle';
      case MeasurementUnit.custom:
        return 'Custom...';
    }
  }

  /// Short form stored/displayed alongside quantities (e.g. "200 g").
  /// Not used for MeasurementUnit.custom — the user's own text is stored instead.
  String get shortLabel {
    switch (this) {
      case MeasurementUnit.piece:
        return 'piece';
      case MeasurementUnit.gram:
        return 'g';
      case MeasurementUnit.kilogram:
        return 'kg';
      case MeasurementUnit.milliliter:
        return 'ml';
      case MeasurementUnit.liter:
        return 'L';
      case MeasurementUnit.bottle:
        return 'bottle';
      case MeasurementUnit.custom:
        return '';
    }
  }
}

/// Returns the multiplier to convert a quantity from [from] to [to], or
/// null if the pair isn't safely convertible without extra information.
///
/// Only metric weight (g ↔ kg) and volume (ml ↔ L) pairs have a fixed,
/// universal ratio. "Piece" and "Bottle" sizes are ingredient-specific —
/// a bottle of soy sauce isn't the same volume as a bottle of oil, and a
/// "piece" could be any size — so those are never auto-converted; the
/// admin has to adjust those manually.
num? conversionFactorTo(MeasurementUnit from, MeasurementUnit to) {
  if (from == to) return 1;

  const weightInGrams = {
    MeasurementUnit.gram: 1.0,
    MeasurementUnit.kilogram: 1000.0,
  };
  const volumeInMl = {
    MeasurementUnit.milliliter: 1.0,
    MeasurementUnit.liter: 1000.0,
  };

  if (weightInGrams.containsKey(from) && weightInGrams.containsKey(to)) {
    return weightInGrams[from]! / weightInGrams[to]!;
  }
  if (volumeInMl.containsKey(from) && volumeInMl.containsKey(to)) {
    return volumeInMl[from]! / volumeInMl[to]!;
  }
  return null;
}
