import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loss.dart';
import 'collections.dart';
import 'ingredient_service.dart';

class LossService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final IngredientService _ingredientService = IngredientService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.losses);

  Future<String> recordLoss(LossEntry loss) async {
    final ref = await _col.add(loss.toMap());
    return ref.id;
  }

  Stream<List<LossEntry>> watchLosses() {
    return _col.snapshots().map(
          (snap) => snap.docs.map((d) => LossEntry.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<List<LossEntry>> getLossesBetween(DateTime start, DateTime end) async {
    final snap = await _col
        .where('lossDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('lossDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => LossEntry.fromMap(d.id, d.data())).toList();
  }

  /// System objective: "identify expired ingredients, remove them from
  /// usable inventory, and automatically record them as losses."
  /// This does three things (best-effort — not a single Firestore
  /// transaction, since it spans two collections + a service call):
  ///   1. Moves the expired quantity from fresh into expired stock
  ///      (IngredientService.markQuantityExpired), so both stay visible.
  ///   2. Writes a loss entry with reason "expired".
  Future<void> markIngredientExpiredAndRecordLoss({
    required String ingredientId,
    required int expiredQty,
  }) async {
    await _ingredientService.markQuantityExpired(ingredientId, expiredQty);
    await recordLoss(LossEntry(
      id: '',
      itemId: ingredientId,
      isIngredient: true,
      lossQty: expiredQty,
      lossReason: LossReason.expired,
      lossDate: DateTime.now(),
    ));
  }

  /// For the "customer unsatisfied, dish replaced" case described in
  /// Chapter 1: the replaced dish's ingredient cost is a loss even though
  /// no money changes hands and the employee isn't charged for it.
  Future<void> recordReplacedOrderLoss({
    required String itemId,
    required bool isIngredient,
    required int qty,
  }) {
    return recordLoss(LossEntry(
      id: '',
      itemId: itemId,
      isIngredient: isIngredient,
      lossQty: qty,
      lossReason: LossReason.replacedOrder,
      lossDate: DateTime.now(),
    ));
  }
}
