/// Central place for Firestore collection names so nothing gets
/// misspelled across services.
class Collections {
  static const users = 'users';
  static const products = 'products';
  static const ingredients = 'ingredients';
  static const finishedProducts = 'finishedProducts';
  static const inventoryStock = 'inventoryStock';
  static const ingredientUsage = 'ingredientUsage';
  static const losses = 'losses';
  static const salesTransaction = 'salesTransaction';
  static const salesReport = 'salesReport';
}

/// Low-stock threshold from the project's objectives: notify when available
/// ingredients are only enough for 5 or fewer servings of a dish.
const int lowStockServingThreshold = 5;
