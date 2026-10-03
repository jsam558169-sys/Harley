import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to the `ingredientUsage` collection.
/// One entry per ingredient consumed by a completed sale (recipe-driven
/// deduction). Rolling this up by date range gives daily/weekly/monthly
/// consumption reports.
class IngredientUsageEntry {
  final String id; // usageId
  final String ingredientId;
  final num usageQty;
  final DateTime usageDate;
  final String? sourceSalesTransId; // which sale caused this usage

  IngredientUsageEntry({
    required this.id,
    required this.ingredientId,
    required this.usageQty,
    required this.usageDate,
    this.sourceSalesTransId,
  });

  Map<String, dynamic> toMap() => {
        'ingredientId': ingredientId,
        'usageQty': usageQty,
        'usageDate': Timestamp.fromDate(usageDate),
        'sourceSalesTransId': sourceSalesTransId,
      };

  factory IngredientUsageEntry.fromMap(String id, Map<String, dynamic> map) {
    return IngredientUsageEntry(
      id: id,
      ingredientId: map['ingredientId'] ?? '',
      usageQty: (map['usageQty'] ?? 0) as num,
      usageDate: (map['usageDate'] as Timestamp).toDate(),
      sourceSalesTransId: map['sourceSalesTransId'],
    );
  }
}
