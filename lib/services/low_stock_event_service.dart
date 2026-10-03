import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/low_stock_event.dart';
import '../models/product.dart';
import 'collections.dart';

/// Keeps a historical log of when products became low stock.
///
/// Design note: low stock is a *derived* state (it depends on a product's
/// recipe plus the fresh stock of several ingredients), not a stored field,
/// so there's no single write that "causes" it. This service works by
/// comparing each product's current low/not-low state against the last
/// state it recorded (in `lowStockStatus`), and writing a `lowStockEvents`
/// entry only when a product newly crosses INTO low stock. It runs whenever
/// the Low Stock Alerts screen loads or is refreshed — so an event's
/// timestamp is when the transition was *detected*, which is very close to
/// when it happened as long as that screen is opened regularly, but is not
/// a real-time server-side trigger (that would need Cloud Functions).
class LowStockEventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _db.collection(Collections.lowStockEvents);
  CollectionReference<Map<String, dynamic>> get _statusCol =>
      _db.collection(Collections.lowStockStatus);

  /// [servingsByProduct] must cover every product in [allProducts];
  /// products with servings <= [threshold] are treated as currently low.
  Future<void> checkAndLogTransitions({
    required List<Product> allProducts,
    required Map<String, int> servingsByProduct,
    required int threshold,
  }) async {
    // All reads first (one small collection read), then one batched write.
    final statusSnap = await _statusCol.get();
    final previouslyLow = {
      for (final d in statusSnap.docs) d.id: (d.data()['isLow'] ?? false) as bool,
    };

    final batch = _db.batch();
    var anyWrites = false;

    for (final p in allProducts) {
      final servings = servingsByProduct[p.id] ?? 0;
      final isLowNow = servings <= threshold;
      final wasLow = previouslyLow[p.id] ?? false;

      if (isLowNow && !wasLow) {
        final eventRef = _eventsCol.doc();
        batch.set(
          eventRef,
          LowStockEvent(
            id: eventRef.id,
            productId: p.id,
            productName: p.name,
            servingsAtEvent: servings,
            threshold: threshold,
            occurredAt: DateTime.now(),
          ).toMap(),
        );
        anyWrites = true;
      }

      // Only touch the status doc when the state actually changed (or
      // there's no record yet), to avoid pointless writes on every check.
      if (!previouslyLow.containsKey(p.id) || wasLow != isLowNow) {
        batch.set(
          _statusCol.doc(p.id),
          {'isLow': isLowNow, 'updatedAt': Timestamp.now()},
          SetOptions(merge: true),
        );
        anyWrites = true;
      }
    }

    if (anyWrites) await batch.commit();
  }

  Stream<List<LowStockEvent>> watchEvents() {
    return _eventsCol.orderBy('occurredAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => LowStockEvent.fromMap(d.id, d.data())).toList(),
        );
  }
}
