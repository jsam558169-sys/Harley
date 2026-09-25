/// Maps to the `ingredients` collection.
/// Fresh and expired quantities are tracked separately (rather than one
/// total + a boolean flag) so the UI can show both at once, e.g.
/// "20 Fresh / 5 Expired" instead of just "25 Total".
class Ingredient {
  final String id; // Firestore doc id (was ingredientId)
  final String name;
  final int freshQty; // usable stock on hand
  final int expiredQty; // stock moved out of usable inventory via "mark expired"
  final String unit; // e.g. "piece", "kg", "bottle", or a custom label

  Ingredient({
    required this.id,
    required this.name,
    required this.freshQty,
    required this.expiredQty,
    this.unit = 'piece',
  });

  int get totalQty => freshQty + expiredQty;
  bool get hasExpiredStock => expiredQty > 0;

  Map<String, dynamic> toMap() => {
        'ingredientName': name,
        'freshQty': freshQty,
        'expiredQty': expiredQty,
        'unit': unit,
      };

  factory Ingredient.fromMap(String id, Map<String, dynamic> map) {
    // Falls back to the old single-quantity schema (ingredientQty) if this
    // doc predates the fresh/expired split, so existing test data doesn't
    // just disappear — it's treated as all-fresh with nothing expired yet.
    final freshQty = map.containsKey('freshQty')
        ? (map['freshQty'] ?? 0) as int
        : (map['ingredientQty'] ?? 0) as int;
    return Ingredient(
      id: id,
      name: map['ingredientName'] ?? '',
      freshQty: freshQty,
      expiredQty: (map['expiredQty'] ?? 0) as int,
      unit: map['unit'] ?? 'piece',
    );
  }

  Ingredient copyWith({int? freshQty, int? expiredQty, String? unit}) => Ingredient(
        id: id,
        name: name,
        freshQty: freshQty ?? this.freshQty,
        expiredQty: expiredQty ?? this.expiredQty,
        unit: unit ?? this.unit,
      );
}
