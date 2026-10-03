import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to the `lowStockEvents` collection. One entry is written each time
/// a product transitions from "fine" INTO low stock (not every time it's
/// merely still low), so this reads as a history of "when did this become
/// a problem."
class LowStockEvent {
  final String id;
  final String productId;
  final String productName; // denormalized so history survives a product being deleted/renamed
  final int servingsAtEvent;
  final int threshold; // the threshold in effect when this was logged
  final DateTime occurredAt;

  LowStockEvent({
    required this.id,
    required this.productId,
    required this.productName,
    required this.servingsAtEvent,
    required this.threshold,
    required this.occurredAt,
  });

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'servingsAtEvent': servingsAtEvent,
        'threshold': threshold,
        'occurredAt': Timestamp.fromDate(occurredAt),
      };

  factory LowStockEvent.fromMap(String id, Map<String, dynamic> map) {
    return LowStockEvent(
      id: id,
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      servingsAtEvent: (map['servingsAtEvent'] ?? 0) as int,
      threshold: (map['threshold'] ?? 0) as int,
      occurredAt: (map['occurredAt'] as Timestamp).toDate(),
    );
  }
}
