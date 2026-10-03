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
  static const settings = 'settings';
  static const lowStockEvents = 'lowStockEvents';
  static const lowStockStatus = 'lowStockStatus';
}

/// Default low-stock threshold from the project's objectives: notify when
/// available ingredients are only enough for 5 or fewer servings of a dish.
/// Owner/Admin can override this via SettingsService — this constant is
/// just the fallback used until a custom value is saved.
const int defaultLowStockServingThreshold = 5;

/// Sanity ceiling applied to quantity and price inputs across the app
/// (product price, ingredient stock, recipe quantities). Six digits is
/// already far beyond anything a small café would realistically enter in
/// one go — this exists to catch fat-fingered typos, not to be a real
/// business constraint.
const int maxInputValue = 999999;
