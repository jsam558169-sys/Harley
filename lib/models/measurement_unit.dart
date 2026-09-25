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
