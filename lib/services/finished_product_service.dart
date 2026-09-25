import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/finished_product.dart';
import 'collections.dart';

class FinishedProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.finishedProducts);

  Future<String> add(FinishedProduct item) async {
    final ref = await _col.add(item.toMap());
    return ref.id;
  }

  Future<void> update(FinishedProduct item) {
    return _col.doc(item.id).update(item.toMap());
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }

  Stream<List<FinishedProduct>> watchAll() {
    return _col.snapshots().map(
          (snap) => snap.docs
              .map((d) => FinishedProduct.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<FinishedProduct>> getAllFinishedProducts() async {
    final snap = await _col.get();
    return snap.docs.map((d) => FinishedProduct.fromMap(d.id, d.data())).toList();
  }

  Future<void> adjustQty(String id, int delta) async {
    final ref = _col.doc(id);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final current = (snap.data()?['finishedProductQty'] ?? 0) as int;
      final updated = current + delta;
      txn.update(ref, {'finishedProductQty': updated < 0 ? 0 : updated});
    });
  }
}
