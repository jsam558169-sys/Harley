import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportPeriod { daily, weekly, monthly }

/// Maps to the `salesReport` collection.
/// These are computed by ReportService from salesTransaction data and can
/// optionally be cached back into Firestore so they don't need to be
/// recalculated every time (useful once transaction volume grows).
class SalesReport {
  final String id; // salesRepId
  final DateTime salesRepDate; // date the report covers / was generated
  final ReportPeriod period;
  final double totalSales;
  final int totalTransactions;
  final int totalItemsSold;

  SalesReport({
    required this.id,
    required this.salesRepDate,
    required this.period,
    required this.totalSales,
    required this.totalTransactions,
    required this.totalItemsSold,
  });

  Map<String, dynamic> toMap() => {
        'salesRepDate': Timestamp.fromDate(salesRepDate),
        'period': period.name,
        'totalSales': totalSales,
        'totalTransactions': totalTransactions,
        'totalItemsSold': totalItemsSold,
      };

  factory SalesReport.fromMap(String id, Map<String, dynamic> map) {
    return SalesReport(
      id: id,
      salesRepDate: (map['salesRepDate'] as Timestamp).toDate(),
      period: ReportPeriod.values.firstWhere(
        (p) => p.name == map['period'],
        orElse: () => ReportPeriod.daily,
      ),
      totalSales: (map['totalSales'] ?? 0).toDouble(),
      totalTransactions: (map['totalTransactions'] ?? 0) as int,
      totalItemsSold: (map['totalItemsSold'] ?? 0) as int,
    );
  }
}
