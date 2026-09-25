/// Maps to the `finishedProducts` collection.
/// e.g. pre-made batches like brewed coffee base or prepped patties,
/// tracked separately from raw ingredients.
class FinishedProduct {
  final String id; // Firestore doc id (was finishedProductId)
  final String name;
  final int qty;

  FinishedProduct({required this.id, required this.name, required this.qty});

  Map<String, dynamic> toMap() => {
        'finishedProductName': name,
        'finishedProductQty': qty,
      };

  factory FinishedProduct.fromMap(String id, Map<String, dynamic> map) {
    return FinishedProduct(
      id: id,
      name: map['finishedProductName'] ?? '',
      qty: (map['finishedProductQty'] ?? 0) as int,
    );
  }

  FinishedProduct copyWith({int? qty}) => FinishedProduct(
        id: id,
        name: name,
        qty: qty ?? this.qty,
      );
}
