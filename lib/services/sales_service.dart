import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_transaction.dart';
import '../models/ingredient_usage.dart';
import '../models/inventory_stock.dart';
import '../models/product.dart';
import 'collections.dart';
import 'product_service.dart';

/// Thrown when a sale can't be completed because one or more ingredients
/// don't have enough quantity on hand.
class InsufficientStockException implements Exception {
  final List<String> shortIngredientNames;
  InsufficientStockException(this.shortIngredientNames);

  @override
  String toString() =>
      'Not enough stock for ingredient(s): ${shortIngredientNames.join(", ")}';
}

/// The core POS function: completing a sale.
/// This is where sales recording and inventory deduction actually connect —
/// the whole point of the proposed system per Chapter 1/2.
class SalesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductService _productService = ProductService();

  CollectionReference<Map<String, dynamic>> get _salesCol =>
      _db.collection(Collections.salesTransaction);

  /// Processes a sale end-to-end, atomically:
  ///  1. Looks up each sold product's recipe.
  ///  2. Computes total ingredient quantities required across the whole cart.
  ///  3. Verifies enough stock exists; throws InsufficientStockException if not.
  ///  4. Deducts ingredient quantities.
  ///  5. Writes the salesTransaction doc.
  ///  6. Writes an ingredientUsage entry per ingredient consumed.
  ///  7. Writes an auto stock-out entry per ingredient in inventoryStock,
  ///     so the movement log stays a complete audit trail.
  ///
  /// [cartItems] maps productId -> quantity sold.
  Future<String> completeSale({
    required Map<String, int> cartItems,
    required String recordedByUid,
    required String branch,
  }) async {
    // Step 1-2: resolve products and required ingredient totals up front,
    // since Firestore transactions require all reads before any writes.
    final products = <String, Product>{};
    for (final productId in cartItems.keys) {
      final product = await _productService.getProduct(productId);
      if (product == null) {
        throw Exception('Product $productId not found');
      }
      products[productId] = product;
    }

    final requiredIngredientQty = <String, num>{}; // ingredientId -> totalQty
    for (final entry in cartItems.entries) {
      final product = products[entry.key]!;
      final qtySold = entry.value;
      for (final recipeItem in product.recipeIngredients) {
        requiredIngredientQty.update(
          recipeItem.ingredientId,
          (existing) => existing + recipeItem.qtyPerUnit * qtySold,
          ifAbsent: () => recipeItem.qtyPerUnit * qtySold,
        );
      }
    }

    final salesItems = cartItems.entries.map((e) {
      final product = products[e.key]!;
      return SalesItem(
        productId: product.id,
        productName: product.name,
        qty: e.value,
        unitPrice: product.price,
      );
    }).toList();

    final totalAmount =
        salesItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final totalQty = salesItems.fold<int>(0, (sum, item) => sum + item.qty);
    final now = DateTime.now();

    final ingredientsCol = _db.collection(Collections.ingredients);
    final usageCol = _db.collection(Collections.ingredientUsage);
    final stockCol = _db.collection(Collections.inventoryStock);
    final saleDocRef = _salesCol.doc();

    // Pre-check sufficiency with plain (non-transactional) reads, BEFORE
    // starting the transaction. Throwing a custom Dart exception from
    // *inside* a Firestore transaction callback doesn't survive the JS
    // interop round-trip cleanly on Flutter Web — it surfaces as an opaque
    // "Dart exception thrown from converted Future" error instead of our
    // actual InsufficientStockException message. Throwing here, from normal
    // async code, propagates cleanly on every platform.
    final shortages = <String>[];
    for (final entry in requiredIngredientQty.entries) {
      final snap = await ingredientsCol.doc(entry.key).get();
      final data = snap.data();
      final onHand = (data?['freshQty'] ?? 0) as num;
      if (onHand < entry.value) {
        final name = (data?['ingredientName'] as String?);
        shortages.add(name == null || name.isEmpty ? entry.key : name);
      }
    }
    if (shortages.isNotEmpty) {
      throw InsufficientStockException(shortages);
    }

    return _db.runTransaction<String>((txn) async {
      // All reads first.
      final ingredientSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final ingredientId in requiredIngredientQty.keys) {
        ingredientSnaps[ingredientId] =
            await txn.get(ingredientsCol.doc(ingredientId));
      }

      // Writes: deduct ingredients from fresh stock. Clamped at 0 as a
      // rare-race safety net (two simultaneous checkouts racing past the
      // pre-check above) — deliberately NOT throwing here, for the same
      // web-interop reason noted above.
      for (final entry in requiredIngredientQty.entries) {
        final onHand =
            (ingredientSnaps[entry.key]?.data()?['freshQty'] ?? 0) as num;
        final updated = onHand - entry.value;
        txn.update(ingredientsCol.doc(entry.key),
            {'freshQty': updated < 0 ? 0 : updated});
      }

      // Write the sale itself.
      final sale = SalesTransaction(
        id: saleDocRef.id,
        salesTransAmount: totalAmount,
        salesTransQty: totalQty,
        salesTransDate: now,
        items: salesItems,
        recordedByUid: recordedByUid,
        branch: branch,
      );
      txn.set(saleDocRef, sale.toMap());

      // Write ingredient usage + auto stock-out log entries.
      for (final entry in requiredIngredientQty.entries) {
        final usageDocRef = usageCol.doc();
        txn.set(
          usageDocRef,
          IngredientUsageEntry(
            id: usageDocRef.id,
            ingredientId: entry.key,
            usageQty: entry.value,
            usageDate: now,
            sourceSalesTransId: saleDocRef.id,
          ).toMap(),
        );

        final stockDocRef = stockCol.doc();
        txn.set(
          stockDocRef,
          InventoryStockEntry(
            id: stockDocRef.id,
            itemId: entry.key,
            isIngredient: true, // recipe deductions are always ingredients
            stockType: StockType.stockOut,
            stockQty: entry.value,
            stockDate: now,
            note: 'Auto-deducted from sale ${saleDocRef.id}',
          ).toMap(),
        );
      }

      return saleDocRef.id;
    });
  }

  Stream<List<SalesTransaction>> watchTransactions() {
    return _salesCol
        .orderBy('salesTransDate', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SalesTransaction.fromMap(d.id, d.data())).toList());
  }

  Future<List<SalesTransaction>> getTransactionsBetween(
      DateTime start, DateTime end) async {
    final snap = await _salesCol
        .where('salesTransDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('salesTransDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => SalesTransaction.fromMap(d.id, d.data())).toList();
  }

  /// Full sales history, used to build the per-product daily/weekly/monthly
  /// breakdown on the Reports screen. Fine at this app's transaction volume;
  /// if that grows a lot, this is the first place worth adding pagination.
  Future<List<SalesTransaction>> getAllTransactions() async {
    final snap = await _salesCol.get();
    return snap.docs.map((d) => SalesTransaction.fromMap(d.id, d.data())).toList();
  }
}
