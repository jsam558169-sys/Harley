import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_report.dart';
import '../models/ingredient_usage.dart';
import 'collections.dart';
import 'sales_service.dart';
import 'product_service.dart';
import 'ingredient_service.dart';

/// Generates the daily/weekly/monthly sales and ingredient-usage reports
/// described in the system objectives. Reports are computed on demand from
/// raw transaction/usage data; optionally cache the result via
/// [cacheReport] so it doesn't need recomputing every time.
class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SalesService _salesService = SalesService();
  final ProductService _productService = ProductService();
  final IngredientService _ingredientService = IngredientService();

  CollectionReference<Map<String, dynamic>> get _reportCol =>
      _db.collection(Collections.salesReport);

  CollectionReference<Map<String, dynamic>> get _usageCol =>
      _db.collection(Collections.ingredientUsage);

  DateTime _startOfPeriod(DateTime reference, ReportPeriod period) {
    switch (period) {
      case ReportPeriod.daily:
        return DateTime(reference.year, reference.month, reference.day);
      case ReportPeriod.weekly:
        final startOfWeek =
            reference.subtract(Duration(days: reference.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case ReportPeriod.monthly:
        return DateTime(reference.year, reference.month, 1);
    }
  }

  DateTime _endOfPeriod(DateTime start, ReportPeriod period) {
    switch (period) {
      case ReportPeriod.daily:
        return start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
      case ReportPeriod.weekly:
        return start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
      case ReportPeriod.monthly:
        final nextMonth = DateTime(start.year, start.month + 1, 1);
        return nextMonth.subtract(const Duration(milliseconds: 1));
    }
  }

  /// Generates a sales report (total revenue, transaction count, items sold)
  /// for the daily/weekly/monthly period containing [reference] (defaults
  /// to now).
  Future<SalesReport> generateSalesReport({
    required ReportPeriod period,
    DateTime? reference,
  }) async {
    final ref = reference ?? DateTime.now();
    final start = _startOfPeriod(ref, period);
    final end = _endOfPeriod(start, period);

    final transactions = await _salesService.getTransactionsBetween(start, end);
    final totalSales =
        transactions.fold<double>(0, (sum, t) => sum + t.salesTransAmount);
    final totalItems =
        transactions.fold<int>(0, (sum, t) => sum + t.salesTransQty);

    return SalesReport(
      id: '',
      salesRepDate: start,
      period: period,
      totalSales: totalSales,
      totalTransactions: transactions.length,
      totalItemsSold: totalItems,
    );
  }

  /// Optionally persist a generated report so historical reports don't need
  /// recomputation from raw transactions every time they're viewed.
  Future<String> cacheReport(SalesReport report) async {
    final ref = await _reportCol.add(report.toMap());
    return ref.id;
  }

  /// Gross revenue, cost of goods sold, and net profit for the given
  /// period. Cost is computed from each sold product's recipe using
  /// CURRENT ingredient costPerUnit values — not a historical snapshot of
  /// what ingredients cost at the time of each sale. If ingredient costs
  /// have changed since a sale happened, that sale's contribution to past
  /// periods' cost/profit will shift to reflect today's costs rather than
  /// the true cost on that day. Ingredients with costPerUnit still at the
  /// default of 0 (never filled in) will understate cost.
  Future<ProfitSummary> generateProfitSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final transactions = await _salesService.getTransactionsBetween(start, end);
    final products = await _productService.getAllProducts();
    final ingredients = await _ingredientService.getAllIngredients();
    final productsById = {for (final p in products) p.id: p};
    final ingredientsById = {for (final i in ingredients) i.id: i};

    double revenue = 0;
    double cost = 0;

    for (final t in transactions) {
      for (final item in t.items) {
        revenue += item.lineTotal;
        final product = productsById[item.productId];
        if (product == null) continue;
        num unitCost = 0;
        for (final r in product.recipeIngredients) {
          final ingredient = ingredientsById[r.ingredientId];
          if (ingredient == null) continue;
          unitCost += ingredient.costPerUnit * r.qtyPerUnit;
        }
        cost += unitCost * item.qty;
      }
    }

    return ProfitSummary(totalRevenue: revenue, totalCost: cost, netProfit: revenue - cost);
  }

  /// Ingredient usage summary for a period: ingredientId -> total qty used.
  /// This backs the "ingredient usage monitoring" and "estimated
  /// consumption" objectives.
  Future<Map<String, num>> generateIngredientUsageSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _usageCol
        .where('usageDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('usageDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final entries =
        snap.docs.map((d) => IngredientUsageEntry.fromMap(d.id, d.data()));

    final summary = <String, num>{};
    for (final entry in entries) {
      summary.update(
        entry.ingredientId,
        (existing) => existing + entry.usageQty,
        ifAbsent: () => entry.usageQty,
      );
    }
    return summary;
  }

  /// Per-product breakdown: how many units of each product sold today,
  /// this week, and this month — all three at once, independent of
  /// whichever period is selected up in the aggregate report. Also tracks
  /// the most recent sale date per product, for the "Last Sold" sort.
  Future<Map<String, ProductSalesStat>> generateProductSalesBreakdown() async {
    final transactions = await _salesService.getAllTransactions();
    final now = DateTime.now();
    final startOfDay = _startOfPeriod(now, ReportPeriod.daily);
    final startOfWeek = _startOfPeriod(now, ReportPeriod.weekly);
    final startOfMonth = _startOfPeriod(now, ReportPeriod.monthly);

    final daily = <String, int>{};
    final weekly = <String, int>{};
    final monthly = <String, int>{};
    final lastSold = <String, DateTime>{};

    for (final t in transactions) {
      for (final item in t.items) {
        if (!t.salesTransDate.isBefore(startOfDay)) {
          daily.update(item.productId, (v) => v + item.qty, ifAbsent: () => item.qty);
        }
        if (!t.salesTransDate.isBefore(startOfWeek)) {
          weekly.update(item.productId, (v) => v + item.qty, ifAbsent: () => item.qty);
        }
        if (!t.salesTransDate.isBefore(startOfMonth)) {
          monthly.update(item.productId, (v) => v + item.qty, ifAbsent: () => item.qty);
        }
        final existing = lastSold[item.productId];
        if (existing == null || t.salesTransDate.isAfter(existing)) {
          lastSold[item.productId] = t.salesTransDate;
        }
      }
    }

    final allProductIds = {...daily.keys, ...weekly.keys, ...monthly.keys, ...lastSold.keys};
    return {
      for (final id in allProductIds)
        id: ProductSalesStat(
          dailySold: daily[id] ?? 0,
          weeklySold: weekly[id] ?? 0,
          monthlySold: monthly[id] ?? 0,
          lastSoldDate: lastSold[id],
        ),
    };
  }
}

/// How many units of one product sold today / this week / this month, plus
/// when it was last sold. Not a Firestore model — computed on demand by
/// [ReportService.generateProductSalesBreakdown].
class ProductSalesStat {
  final int dailySold;
  final int weeklySold;
  final int monthlySold;
  final DateTime? lastSoldDate;

  const ProductSalesStat({
    required this.dailySold,
    required this.weeklySold,
    required this.monthlySold,
    this.lastSoldDate,
  });

  static const zero = ProductSalesStat(dailySold: 0, weeklySold: 0, monthlySold: 0);
}

/// Gross revenue, total cost of goods sold, and net profit for a period.
/// Not a Firestore model — computed on demand by
/// [ReportService.generateProfitSummary]. See that method's doc comment
/// for an important caveat about cost accuracy over time.
class ProfitSummary {
  final double totalRevenue;
  final double totalCost;
  final double netProfit;

  const ProfitSummary({
    required this.totalRevenue,
    required this.totalCost,
    required this.netProfit,
  });

  static const zero = ProfitSummary(totalRevenue: 0, totalCost: 0, netProfit: 0);
}
