/// Maps to the `ingredients` collection.
/// Fresh and expired quantities are tracked separately (rather than one
/// total + a boolean flag) so the UI can show both at once, e.g.
/// "20 Fresh / 5 Expired" instead of just "25 Total".
class Ingredient {
  final String id; // Firestore doc id (was ingredientId)
  final String name;
  final num freshQty; // usable stock on hand — num, not int, so kg/L/g can be decimal
  final num expiredQty; // stock moved out of usable inventory via "mark expired"
  final String unit; // e.g. "piece", "kg", "bottle", or a custom label

  /// What this ingredient costs the business per 1 unit of [unit] (e.g.
  /// ₱50 per kg). Used to compute recipe cost and therefore profit on
  /// Reports — not a selling price, that's on Product. Defaults to 0 for
  /// ingredients added before this field existed, which means profit
  /// figures will understate cost until an Owner/Admin fills these in.
  final num costPerUnit;

  Ingredient({
    required this.id,
    required this.name,
    required this.freshQty,
    required this.expiredQty,
    this.unit = 'piece',
    this.costPerUnit = 0,
  });

  num get totalQty => freshQty + expiredQty;
  bool get hasExpiredStock => expiredQty > 0;

  Map<String, dynamic> toMap() => {
        'ingredientName': name,
        'freshQty': freshQty,
        'expiredQty': expiredQty,
        'unit': unit,
        'costPerUnit': costPerUnit,
      };

  factory Ingredient.fromMap(String id, Map<String, dynamic> map) {
    // Falls back to the old single-quantity schema (ingredientQty) if this
    // doc predates the fresh/expired split, so existing test data doesn't
    // just disappear — it's treated as all-fresh with nothing expired yet.
    final freshQty = map.containsKey('freshQty')
        ? (map['freshQty'] ?? 0) as num
        : (map['ingredientQty'] ?? 0) as num;
    return Ingredient(
      id: id,
      name: map['ingredientName'] ?? '',
      freshQty: freshQty,
      expiredQty: (map['expiredQty'] ?? 0) as num,
      unit: map['unit'] ?? 'piece',
      costPerUnit: (map['costPerUnit'] ?? 0) as num,
    );
  }

  Ingredient copyWith({num? freshQty, num? expiredQty, String? unit, num? costPerUnit}) => Ingredient(
        id: id,
        name: name,
        freshQty: freshQty ?? this.freshQty,
        expiredQty: expiredQty ?? this.expiredQty,
        unit: unit ?? this.unit,
        costPerUnit: costPerUnit ?? this.costPerUnit,
      );
}
