import 'package:cloud_firestore/cloud_firestore.dart';

/// One line item within a sale: which product, how many units.
/// NOTE: this wasn't a separate field in the original data dictionary, but
/// it's required to know *which* products were sold in a transaction so the
/// system can look up each product's recipe and deduct ingredients. It's
/// embedded directly in the salesTransaction document (NoSQL-native).
class SalesItem {
  final String productId;
  final String productName; // denormalized for easy receipt/report display
  final int qty;
  final double unitPrice;

  SalesItem({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
  });

  double get lineTotal => qty * unitPrice;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'qty': qty,
        'unitPrice': unitPrice,
      };

  factory SalesItem.fromMap(Map<String, dynamic> map) => SalesItem(
        productId: map['productId'],
        productName: map['productName'] ?? '',
        qty: (map['qty'] ?? 0) as int,
        unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      );
}

/// Maps to the `salesTransaction` collection.
class SalesTransaction {
  final String id; // salesTransID
  final double salesTransAmount; // total for the whole transaction
  final int salesTransQty; // total item count across all products
  final DateTime salesTransDate;
  final List<SalesItem> items;
  final String recordedByUid; // employee/owner who processed the sale
  final String branch; // "Juan Luna" or "Toril" per the two branches

  SalesTransaction({
    required this.id,
    required this.salesTransAmount,
    required this.salesTransQty,
    required this.salesTransDate,
    required this.items,
    required this.recordedByUid,
    required this.branch,
  });

  Map<String, dynamic> toMap() => {
        'salesTransAmount': salesTransAmount,
        'salesTransQty': salesTransQty,
        'salesTransDate': Timestamp.fromDate(salesTransDate),
        'items': items.map((i) => i.toMap()).toList(),
        'recordedByUid': recordedByUid,
        'branch': branch,
      };

  factory SalesTransaction.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? [];
    return SalesTransaction(
      id: id,
      salesTransAmount: (map['salesTransAmount'] ?? 0).toDouble(),
      salesTransQty: (map['salesTransQty'] ?? 0) as int,
      salesTransDate: (map['salesTransDate'] as Timestamp).toDate(),
      items: rawItems
          .map((i) => SalesItem.fromMap(Map<String, dynamic>.from(i)))
          .toList(),
      recordedByUid: map['recordedByUid'] ?? '',
      branch: map['branch'] ?? '',
    );
  }
}
