/// One line of a product's recipe: how much of a given ingredient
/// is consumed every time one unit of the product is sold.
/// This is the embedded map inside `products.recipeIngredients`.
class RecipeItem {
  final String ingredientId; // references ingredients doc id
  final String ingredientName; // denormalized so the recipe list doesn't need a lookup
  final num qtyPerUnit; // amount of that ingredient used per 1 product sold
  final String unit; // e.g. "piece", "g", "kg", "ml", "l", "bottle", or a custom label

  RecipeItem({
    required this.ingredientId,
    required this.ingredientName,
    required this.qtyPerUnit,
    required this.unit,
  });

  Map<String, dynamic> toMap() => {
        'ingredientId': ingredientId,
        'ingredientName': ingredientName,
        'qtyPerUnit': qtyPerUnit,
        'unit': unit,
      };

  factory RecipeItem.fromMap(Map<String, dynamic> map) => RecipeItem(
        ingredientId: map['ingredientId'],
        ingredientName: map['ingredientName'] ?? '',
        qtyPerUnit: map['qtyPerUnit'] ?? 0,
        unit: map['unit'] ?? 'piece',
      );
}

/// Maps to the `products` collection.
class Product {
  final String id; // Firestore doc id (was productId)
  final String name;
  final double price;
  final List<RecipeItem> recipeIngredients;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.recipeIngredients,
  });

  Map<String, dynamic> toMap() => {
        'productName': name,
        'productPrice': price,
        'recipeIngredients': recipeIngredients.map((r) => r.toMap()).toList(),
      };

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final rawList = (map['recipeIngredients'] as List?) ?? [];
    return Product(
      id: id,
      name: map['productName'] ?? '',
      price: (map['productPrice'] ?? 0).toDouble(),
      recipeIngredients: rawList
          .map((r) => RecipeItem.fromMap(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }
}
