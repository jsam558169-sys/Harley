import 'package:cloud_firestore/cloud_firestore.dart';

enum LossReason { expired, spoiled, replacedOrder, other }

String lossReasonToString(LossReason r) {
  switch (r) {
    case LossReason.expired:
      return 'expired';
    case LossReason.spoiled:
      return 'Spoiled';
    case LossReason.replacedOrder:
      return 'replaced order';
    case LossReason.other:
      return 'other';
  }
}

LossReason lossReasonFromString(String s) {
  switch (s) {
    case 'expired':
      return LossReason.expired;
    case 'Spoiled':
      return LossReason.spoiled;
    case 'replaced order':
      return LossReason.replacedOrder;
    default:
      return LossReason.other;
  }
}

/// Maps to the `losses` collection.
class LossEntry {
  final String id; // lossId
  final String itemId; // references ingredientId or finishedProductId
  final bool isIngredient; // which collection itemId belongs to — needed to resolve its name
  final num lossQty;
  final LossReason lossReason;
  final DateTime lossDate;

  LossEntry({
    required this.id,
    required this.itemId,
    required this.isIngredient,
    required this.lossQty,
    required this.lossReason,
    required this.lossDate,
  });

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'isIngredient': isIngredient,
        'lossQty': lossQty,
        'lossReason': lossReasonToString(lossReason),
        'lossDate': Timestamp.fromDate(lossDate),
      };

  factory LossEntry.fromMap(String id, Map<String, dynamic> map) {
    return LossEntry(
      id: id,
      itemId: map['itemId'] ?? '',
      // Older entries predate this field — everything recorded so far has
      // been an ingredient loss, so that's the safe fallback.
      isIngredient: map['isIngredient'] ?? true,
      lossQty: (map['lossQty'] ?? 0) as num,
      lossReason: lossReasonFromString(map['lossReason'] ?? 'other'),
      lossDate: (map['lossDate'] as Timestamp).toDate(),
    );
  }
}
