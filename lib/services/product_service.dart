import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import 'collections.dart';

/// CRUD for menu items (products) and their recipes.
class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.products);

  Future<String> addProduct(Product product) async {
    final ref = await _col.add(product.toMap());
    return ref.id;
  }

  Future<void> updateProduct(Product product) {
    return _col.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String productId) {
    return _col.doc(productId).delete();
  }

  Future<Product?> getProduct(String productId) async {
    final doc = await _col.doc(productId).get();
    if (!doc.exists) return null;
    return Product.fromMap(doc.id, doc.data()!);
  }

  Stream<List<Product>> watchProducts() {
    return _col.snapshots().map(
          (snap) => snap.docs
              .map((d) => Product.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<Product>> getAllProducts() async {
    final snap = await _col.get();
    return snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
  }
}
