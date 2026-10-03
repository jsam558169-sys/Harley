import 'package:cloud_firestore/cloud_firestore.dart';

enum StockType { stockIn, stockOut }

String stockTypeToString(StockType t) => t == StockType.stockIn ? 'Stock-in' : 'Stock-out';

StockType stockTypeFromString(String s) =>
    s == 'Stock-in' ? StockType.stockIn : StockType.stockOut;

/// Maps to the `inventoryStock` collection.
/// A movement log entry — every manual stock-in or stock-out is recorded here,
/// as well as automatic stock-out entries created by a sale (so the log stays
/// a complete audit trail of why quantities changed).
class InventoryStockEntry {
  final String id; // stockId
  final String itemId; // references ingredientId or finishedProductId
  final bool isIngredient; // which collection itemId belongs to — needed to resolve its name
  final StockType stockType;
  final num stockQty;
  final DateTime stockDate;
  final String? note; // e.g. "auto-deducted from sale #123"

  InventoryStockEntry({
    required this.id,
    required this.itemId,
    required this.isIngredient,
    required this.stockType,
    required this.stockQty,
    required this.stockDate,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'isIngredient': isIngredient,
        'stockType': stockTypeToString(stockType),
        'stockQty': stockQty,
        'stockDate': Timestamp.fromDate(stockDate),
        'note': note,
      };

  factory InventoryStockEntry.fromMap(String id, Map<String, dynamic> map) {
    return InventoryStockEntry(
      id: id,
      itemId: map['itemId'] ?? '',
      // Older entries predate this field — everything recorded before was
      // an ingredient movement, so that's the safe fallback.
      isIngredient: map['isIngredient'] ?? true,
      stockType: stockTypeFromString(map['stockType'] ?? 'Stock-in'),
      stockQty: (map['stockQty'] ?? 0) as num,
      stockDate: (map['stockDate'] as Timestamp).toDate(),
      note: map['note'],
    );
  }
}
