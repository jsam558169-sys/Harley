import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sales_report.dart';
import '../models/product.dart';
import '../services/report_service.dart';
import '../services/ingredient_service.dart';
import '../services/product_service.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive.dart';

enum _ProductSortOption { nameAsc, nameDesc, lastSoldNewest, lastSoldOldest, monthlySoldHigh, monthlySoldLow }

extension on _ProductSortOption {
  String get label {
    switch (this) {
      case _ProductSortOption.nameAsc:
        return 'Name (A–Z)';
      case _ProductSortOption.nameDesc:
        return 'Name (Z–A)';
      case _ProductSortOption.lastSoldNewest:
        return 'Last Sold (Newest First)';
      case _ProductSortOption.lastSoldOldest:
        return 'Last Sold (Oldest First)';
      case _ProductSortOption.monthlySoldHigh:
        return 'Monthly Sold (High–Low)';
      case _ProductSortOption.monthlySoldLow:
        return 'Monthly Sold (Low–High)';
    }
  }
}

/// Generates and displays daily/weekly/monthly sales reports, a searchable
/// per-product sales breakdown, and an ingredient usage summary.
class ReportsScreen extends StatefulWidget {
  /// Owner/Admin sees full sales figures + the per-product breakdown
  /// (which reveals price, and therefore revenue). Employees (per the
  /// feasibility study) only get the ingredient usage summary, so this is
  /// false on the Employee dashboard.
  final bool showSalesFigures;

  const ReportsScreen({super.key, this.showSalesFigures = true});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _reportService = ReportService();
  final _ingredientService = IngredientService();
  final _productService = ProductService();
  final _productSearchController = TextEditingController();
  final _dateFormat = DateFormat('MMM d, y');

  // Aggregate report (period-based).
  ReportPeriod _period = ReportPeriod.daily;
  SalesReport? _report;
  Map<String, int>? _usageSummary;
  Map<String, String> _ingredientNames = {};
  bool _loadingAggregate = false;

  // Per-product breakdown (always shows daily/weekly/monthly together,
  // independent of the period selector above).
  List<Product> _products = [];
  Map<String, ProductSalesStat> _productBreakdown = {};
  bool _loadingProducts = false;
  String _productSearchQuery = '';
  _ProductSortOption _productSort = _ProductSortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _generateAggregate();
    if (widget.showSalesFigures) _loadProductBreakdown();
  }

  Future<void> _generateAggregate() async {
    setState(() => _loadingAggregate = true);
    final report = await _reportService.generateSalesReport(period: _period);

    final now = DateTime.now();
    DateTime start;
    switch (_period) {
      case ReportPeriod.daily:
        start = DateTime(now.year, now.month, now.day);
        break;
      case ReportPeriod.weekly:
        start = now.subtract(Duration(days: now.weekday - 1));
        break;
      case ReportPeriod.monthly:
        start = DateTime(now.year, now.month, 1);
        break;
    }
    final usage = await _reportService.generateIngredientUsageSummary(start: start, end: now);
    final ingredients = await _ingredientService.getAllIngredients();

    if (!mounted) return;
    setState(() {
      _report = report;
      _usageSummary = usage;
      _ingredientNames = {for (final i in ingredients) i.id: i.name};
      _loadingAggregate = false;
    });
  }

  Future<void> _loadProductBreakdown() async {
    setState(() => _loadingProducts = true);
    final products = await _productService.getAllProducts();
    final breakdown = await _reportService.generateProductSalesBreakdown();
    if (!mounted) return;
    setState(() {
      _products = products;
      _productBreakdown = breakdown;
      _loadingProducts = false;
    });
  }

  List<Product> _filterSortProducts() {
    var result = _products.where((p) {
      if (_productSearchQuery.trim().isEmpty) return true;
      return p.name.toLowerCase().contains(_productSearchQuery.trim().toLowerCase());
    }).toList();

    // Products never sold have no lastSoldDate — treated as the oldest
    // possible date so they sort predictably to one end.
    DateTime lastSold(Product p) =>
        _productBreakdown[p.id]?.lastSoldDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    int monthlySold(Product p) => _productBreakdown[p.id]?.monthlySold ?? 0;

    switch (_productSort) {
      case _ProductSortOption.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _ProductSortOption.nameDesc:
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _ProductSortOption.lastSoldNewest:
        result.sort((a, b) => lastSold(b).compareTo(lastSold(a)));
        break;
      case _ProductSortOption.lastSoldOldest:
        result.sort((a, b) => lastSold(a).compareTo(lastSold(b)));
        break;
      case _ProductSortOption.monthlySoldHigh:
        result.sort((a, b) => monthlySold(b).compareTo(monthlySold(a)));
        break;
      case _ProductSortOption.monthlySoldLow:
        result.sort((a, b) => monthlySold(a).compareTo(monthlySold(b)));
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filterSortProducts();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Aggregate report ---
          DropdownButton<ReportPeriod>(
            value: _period,
            items: const [
              DropdownMenuItem(value: ReportPeriod.daily, child: Text('Daily')),
              DropdownMenuItem(value: ReportPeriod.weekly, child: Text('Weekly')),
              DropdownMenuItem(value: ReportPeriod.monthly, child: Text('Monthly')),
            ],
            onChanged: (v) {
              setState(() => _period = v!);
              _generateAggregate();
            },
          ),
          const SizedBox(height: 12),
          if (_loadingAggregate) const Center(child: CircularProgressIndicator()),
          if (!_loadingAggregate && _report != null) ...[
            if (widget.showSalesFigures) ...[
              Text('Total Sales: ₱${_report!.totalSales.toStringAsFixed(2)}'),
              Text('Total Transactions: ${_report!.totalTransactions}'),
              Text('Total Items Sold: ${_report!.totalItemsSold}'),
            ] else
              Text('Total Items Sold: ${_report!.totalItemsSold}'),
          ],

          // --- Per-product sales breakdown (Owner/Admin only) ---
          if (widget.showSalesFigures) ...[
            const SizedBox(height: 28),
            Text('Product Sales', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
            const Text(
              'Daily / weekly / monthly units sold, per product — always shown together, regardless of the period picked above.',
              style: TextStyle(fontSize: 12, color: AppColors.brown),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _productSearchController,
                    onChanged: (v) => setState(() => _productSearchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.rust),
                      isDense: true,
                      suffixIcon: _productSearchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => setState(() {
                                _productSearchController.clear();
                                _productSearchQuery = '';
                              }),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<_ProductSortOption>(
                  icon: const Icon(Icons.swap_vert, color: AppColors.rust),
                  tooltip: 'Sort products',
                  initialValue: _productSort,
                  onSelected: (option) => setState(() => _productSort = option),
                  itemBuilder: (context) => _ProductSortOption.values
                      .map((option) => PopupMenuItem(
                            value: option,
                            child: Row(
                              children: [
                                Text(option.label),
                                if (option == _productSort) ...[
                                  const Spacer(),
                                  const Icon(Icons.check, size: 18, color: AppColors.rust),
                                ],
                              ],
                            ),
                          ))
                      .toList(),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.rust),
                  tooltip: 'Refresh',
                  onPressed: _loadProductBreakdown,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingProducts) const Center(child: CircularProgressIndicator()),
            if (!_loadingProducts && _products.isEmpty) const Text('No products yet.'),
            if (!_loadingProducts && _products.isNotEmpty && filteredProducts.isEmpty)
              Text('No products match "$_productSearchQuery".'),
            if (!_loadingProducts)
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = gridColumnsForWidth(constraints.maxWidth);
                  final cardWidth = wrapCardWidth(constraints.maxWidth, columns);
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: filteredProducts.map((p) {
                      final stat = _productBreakdown[p.id] ?? ProductSalesStat.zero;
                      return SizedBox(
                        width: cardWidth,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                Text('ID: ${p.id}', style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.55))),
                                const SizedBox(height: 2),
                                Text('Price: ₱${p.price.toStringAsFixed(2)}'),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _SoldPill(label: 'Today', value: stat.dailySold),
                                    const SizedBox(width: 8),
                                    _SoldPill(label: 'This Week', value: stat.weeklySold),
                                    const SizedBox(width: 8),
                                    _SoldPill(label: 'This Month', value: stat.monthlySold),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  stat.lastSoldDate == null
                                      ? 'Not sold yet'
                                      : 'Last sold: ${_dateFormat.format(stat.lastSoldDate!)}',
                                  style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.6)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],

          // --- Ingredient usage summary ---
          const SizedBox(height: 28),
          Text('Ingredient Usage Summary', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
          const SizedBox(height: 8),
          if (_loadingAggregate) const Center(child: CircularProgressIndicator()),
          if (!_loadingAggregate && (_usageSummary == null || _usageSummary!.isEmpty))
            const Text('No ingredient usage recorded for this period.'),
          if (!_loadingAggregate && _usageSummary != null)
            ..._usageSummary!.entries.map((e) => Card(
                  child: ListTile(
                    title: Text(_ingredientNames[e.key] ?? e.key),
                    subtitle: Text('ID: ${e.key}', style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.55))),
                    trailing: Text('Used: ${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )),
        ],
      ),
    );
  }
}

/// Small rounded badge for a "Today: 5" style stat, matching the pill style
/// used elsewhere in the app (e.g. Fresh/Expired on Ingredients & Stock).
class _SoldPill extends StatelessWidget {
  final String label;
  final int value;

  const _SoldPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brown),
      ),
    );
  }
}
