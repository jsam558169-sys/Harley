import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ingredient.dart';
import '../models/product.dart';
import 'collections.dart';

class IngredientService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.ingredients);

  Future<String> addIngredient(Ingredient ingredient) async {
    final ref = await _col.add(ingredient.toMap());
    return ref.id;
  }

  Future<void> updateIngredient(Ingredient ingredient) {
    return _col.doc(ingredient.id).update(ingredient.toMap());
  }

  Future<void> deleteIngredient(String ingredientId) {
    return _col.doc(ingredientId).delete();
  }

  Future<Ingredient?> getIngredient(String ingredientId) async {
    final doc = await _col.doc(ingredientId).get();
    if (!doc.exists) return null;
    return Ingredient.fromMap(doc.id, doc.data()!);
  }

  Stream<List<Ingredient>> watchIngredients() {
    return _col.snapshots().map(
          (snap) =>
              snap.docs.map((d) => Ingredient.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<List<Ingredient>> getAllIngredients() async {
    final snap = await _col.get();
    return snap.docs.map((d) => Ingredient.fromMap(d.id, d.data())).toList();
  }

  /// Directly adjust an ingredient's FRESH (usable) on-hand quantity.
  /// Prefer going through InventoryService.recordStockMovement() instead of
  /// calling this directly so a movement log entry always exists for the
  /// audit trail — this raw setter exists for internal use by other
  /// services (e.g. sales deduction).
  Future<void> adjustFreshQty(String ingredientId, num delta) async {
    final ref = _col.doc(ingredientId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final current = Ingredient.fromMap(snap.id, snap.data() ?? {}).freshQty;
      final updated = current + delta;
      txn.update(ref, {'freshQty': updated < 0 ? 0 : updated});
    });
  }

  /// Moves [qtyToExpire] units from fresh into expired stock (clamped to
  /// however much fresh stock actually exists). This is what "Mark Expired"
  /// calls — expired stock stays tracked and visible rather than just being
  /// subtracted away, so the UI can show "Fresh / Expired" side by side.
  Future<void> markQuantityExpired(String ingredientId, num qtyToExpire) async {
    final ref = _col.doc(ingredientId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final current = Ingredient.fromMap(snap.id, snap.data() ?? {});
      final movable = qtyToExpire.clamp(0, current.freshQty);
      txn.update(ref, {
        'freshQty': current.freshQty - movable,
        'expiredQty': current.expiredQty + movable,
      });
    });
  }

  /// For a given product's recipe, how many servings can currently be made
  /// given the FRESH ingredients on hand (expired stock isn't sellable).
  /// This is the number used for the low-stock notification (system
  /// objective: notify when <= 5 servings).
  Future<int> servingsAvailable(Product product) async {
    if (product.recipeIngredients.isEmpty) return 0;
    int? minServings;
    for (final item in product.recipeIngredients) {
      final ingredient = await getIngredient(item.ingredientId);
      if (ingredient == null || item.qtyPerUnit <= 0) {
        return 0;
      }
      final possible = (ingredient.freshQty / item.qtyPerUnit).floor();
      if (minServings == null || possible < minServings) {
        minServings = possible;
      }
    }
    return minServings ?? 0;
  }

  /// Returns true if the product is at or below the given low-stock
  /// threshold (falls back to the default if none is passed in).
  Future<bool> isLowStock(Product product, {int threshold = defaultLowStockServingThreshold}) async {
    final servings = await servingsAvailable(product);
    return servings <= threshold;
  }
}
