import 'package:cloud_firestore/cloud_firestore.dart';
import 'collections.dart';

/// App-wide settings stored in a single Firestore document
/// (`settings/app`), editable by the Owner/Admin. Currently just the
/// low-stock serving threshold, but built to hold more settings later.
class SettingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(Collections.settings).doc('app');

  Stream<int> watchLowStockThreshold() {
    return _doc.snapshots().map(
          (snap) => (snap.data()?['lowStockThreshold'] ?? defaultLowStockServingThreshold) as int,
        );
  }

  Future<int> getLowStockThreshold() async {
    final snap = await _doc.get();
    return (snap.data()?['lowStockThreshold'] ?? defaultLowStockServingThreshold) as int;
  }

  Future<void> setLowStockThreshold(int value) {
    return _doc.set({'lowStockThreshold': value}, SetOptions(merge: true));
  }
}
