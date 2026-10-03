import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_stock.dart';
import '../models/product.dart';
import 'collections.dart';
import 'ingredient_service.dart';
import 'finished_product_service.dart';
import 'product_service.dart';

/// Handles manual stock-in / stock-out recording for ingredients and
/// finished products, and keeps the inventoryStock movement log up to date.
/// Also surfaces which menu items are currently low-stock.
class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final IngredientService _ingredientService = IngredientService();
  final FinishedProductService _finishedProductService = FinishedProductService();
  final ProductService _productService = ProductService();

  CollectionReference<Map<String, dynamic>> get _stockCol =>
      _db.collection(Collections.inventoryStock);

  /// Records a stock movement for either an ingredient or a finished
  /// product, and updates the on-hand quantity accordingly.
  /// [isIngredient] tells us which collection [itemId] belongs to.
  Future<void> recordStockMovement({
    required String itemId,
    required bool isIngredient,
    required StockType type,
    required num qty,
    String? note,
  }) async {
    final delta = type == StockType.stockIn ? qty : -qty;

    if (isIngredient) {
      await _ingredientService.adjustFreshQty(itemId, delta);
    } else {
      await _finishedProductService.adjustQty(itemId, delta.toInt());
    }

    await _stockCol.add(InventoryStockEntry(
      id: '',
      itemId: itemId,
      isIngredient: isIngredient,
      stockType: type,
      stockQty: qty,
      stockDate: DateTime.now(),
      note: note,
    ).toMap());
  }

  Stream<List<InventoryStockEntry>> watchMovements() {
    return _stockCol.orderBy('stockDate', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => InventoryStockEntry.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<InventoryStockEntry>> getMovementsForItem(String itemId) async {
    final snap = await _stockCol.where('itemId', isEqualTo: itemId).get();
    return snap.docs
        .map((d) => InventoryStockEntry.fromMap(d.id, d.data()))
        .toList();
  }

  /// Returns the list of products currently at or below the low-stock
  /// serving threshold, for the notification/dashboard feature. Pass the
  /// Owner-configured threshold in — this service doesn't reach into
  /// SettingsService itself, to keep the two decoupled.
  Future<List<Product>> getLowStockProducts({int threshold = defaultLowStockServingThreshold}) async {
    final products = await _productService.getAllProducts();
    final lowStock = <Product>[];
    for (final product in products) {
      if (await _ingredientService.isLowStock(product, threshold: threshold)) {
        lowStock.add(product);
      }
    }
    return lowStock;
  }
}
