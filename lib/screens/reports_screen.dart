import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sales_report.dart';
import '../models/product.dart';
import '../models/ingredient.dart';
import '../services/report_service.dart';
import '../services/ingredient_service.dart';
import '../services/product_service.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive.dart';
import '../widgets/info_list_card.dart';
import '../widgets/bar_charts.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/section_panel.dart';

enum _ProductSortOption { nameAsc, nameDesc, lastSoldNewest, lastSoldOldest, monthlySoldHigh, monthlySoldLow }

enum _BestSellerPeriod { daily, weekly, monthly }

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
/// per-product sales breakdown (with charts), a Best Sellers chart, and an
/// ingredient usage summary — each laid out as its own section panel.
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
  Map<String, num>? _usageSummary;
  bool _loadingAggregate = false;
  int _usagePageSize = defaultPageSizeOptions.first;
  int _usagePage = 0;

  // Per-product breakdown (always shows daily/weekly/monthly together,
  // independent of the period selector above).
  List<Product> _products = [];
  Map<String, ProductSalesStat> _productBreakdown = {};
  bool _loadingProducts = false;
  String _productSearchQuery = '';
  _ProductSortOption _productSort = _ProductSortOption.nameAsc;
  int _productPageSize = defaultPageSizeOptions.first;
  int _productPage = 0;

  _BestSellerPeriod _bestSellerPeriod = _BestSellerPeriod.daily;

  @override
  void initState() {
    super.initState();
    _generateAggregate();
    if (widget.showSalesFigures) _loadProductBreakdown();
  }

  Future<void> _generateAggregate() async {
    setState(() {
      _loadingAggregate = true;
      _usagePage = 0;
    });
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

    if (!mounted) return;
    setState(() {
      _report = report;
      _usageSummary = usage;
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

  int _soldForBestSeller(Product p) {
    final stat = _productBreakdown[p.id];
    if (stat == null) return 0;
    switch (_bestSellerPeriod) {
      case _BestSellerPeriod.daily:
        return stat.dailySold;
      case _BestSellerPeriod.weekly:
        return stat.weeklySold;
      case _BestSellerPeriod.monthly:
        return stat.monthlySold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filterSortProducts();
    final productPageItems = paginate(filteredProducts, _productPage, _productPageSize);
    final usageEntries = _usageSummary?.entries.toList() ?? [];
    final usagePageItems = paginate(usageEntries, _usagePage, _usagePageSize);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Aggregate report ---
          SectionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sales Summary', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
                const SizedBox(height: 10),
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
                if (!_loadingAggregate && _report != null)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (widget.showSalesFigures) ...[
                        _StatHighlight(
                          label: 'Total Sales',
                          value: '₱${_report!.totalSales.toStringAsFixed(2)}',
                          color: AppColors.rust,
                        ),
                        _StatHighlight(
                          label: 'Total Transactions',
                          value: '${_report!.totalTransactions}',
                          color: AppColors.teal,
                        ),
                      ],
                      _StatHighlight(
                        label: 'Total Items Sold',
                        value: '${_report!.totalItemsSold}',
                        color: AppColors.gold,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // --- Best Sellers (Owner/Admin only) ---
          if (widget.showSalesFigures)
            SectionPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Best Sellers', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
                      DropdownButton<_BestSellerPeriod>(
                        value: _bestSellerPeriod,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: _BestSellerPeriod.daily, child: Text('Today')),
                          DropdownMenuItem(value: _BestSellerPeriod.weekly, child: Text('This Week')),
                          DropdownMenuItem(value: _BestSellerPeriod.monthly, child: Text('This Month')),
                        ],
                        onChanged: (v) => setState(() => _bestSellerPeriod = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loadingProducts)
                    const Center(child: CircularProgressIndicator())
                  else
                    Builder(builder: (context) {
                      final ranked = _products.where((p) => _soldForBestSeller(p) > 0).toList()
                        ..sort((a, b) => _soldForBestSeller(b).compareTo(_soldForBestSeller(a)));
                      final top = ranked.take(5).toList();
                      if (top.isEmpty) {
                        return const Text('No sales recorded for this period yet.');
                      }
                      return RankedBarChart(
                        entries: top.map((p) => MapEntry(p.name, _soldForBestSeller(p))).toList(),
                      );
                    }),
                ],
              ),
            ),

          // --- Per-product sales breakdown (Owner/Admin only) ---
          if (widget.showSalesFigures)
            SectionPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          onChanged: (v) => setState(() {
                            _productSearchQuery = v;
                            _productPage = 0;
                          }),
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
                                      _productPage = 0;
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
                        onSelected: (option) => setState(() {
                          _productSort = option;
                          _productPage = 0;
                        }),
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
                  if (!_loadingProducts && filteredProducts.isNotEmpty)
                    PaginationBar(
                      pageSize: _productPageSize,
                      currentPage: _productPage,
                      totalItems: filteredProducts.length,
                      onPageSizeChanged: (size) => setState(() {
                        _productPageSize = size;
                        _productPage = 0;
                      }),
                      onPageChanged: (page) => setState(() => _productPage = page),
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
                          children: productPageItems.map((p) {
                            final stat = _productBreakdown[p.id] ?? ProductSalesStat.zero;
                            return SizedBox(
                              width: cardWidth,
                              child: InfoListCard(
                                leadingIcon: Icons.shopping_bag_outlined,
                                accentColor: AppColors.rust,
                                title: p.name,
                                idText: 'ID: ${p.id}',
                                pills: [
                                  StatPill(label: '₱${p.price.toStringAsFixed(2)}', color: AppColors.rust),
                                ],
                                extra: MultiPeriodBarChart(
                                  values: [
                                    MapEntry('Today', stat.dailySold),
                                    MapEntry('Week', stat.weeklySold),
                                    MapEntry('Month', stat.monthlySold),
                                  ],
                                ),
                                footerText: stat.lastSoldDate == null
                                    ? 'Not sold yet'
                                    : 'Last sold: ${_dateFormat.format(stat.lastSoldDate!)}',
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
              ),
            ),

          // --- Ingredient usage summary ---
          SectionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingredient Usage Summary', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
                const SizedBox(height: 8),
                if (_loadingAggregate) const Center(child: CircularProgressIndicator()),
                if (!_loadingAggregate && (_usageSummary == null || _usageSummary!.isEmpty))
                  const Text('No ingredient usage recorded for this period.'),
                if (!_loadingAggregate && _usageSummary != null && _usageSummary!.isNotEmpty) ...[
                  PaginationBar(
                    pageSize: _usagePageSize,
                    currentPage: _usagePage,
                    totalItems: usageEntries.length,
                    onPageSizeChanged: (size) => setState(() {
                      _usagePageSize = size;
                      _usagePage = 0;
                    }),
                    onPageChanged: (page) => setState(() => _usagePage = page),
                  ),
                  const SizedBox(height: 4),
                  // Resolving ingredient names via a live stream (rather than
                  // a one-off fetch) so a newly-added ingredient's name
                  // shows up immediately instead of needing a manual refresh.
                  StreamBuilder<List<Ingredient>>(
                    stream: _ingredientService.watchIngredients(),
                    builder: (context, snapshot) {
                      final ingredientNames = {
                        for (final i in snapshot.data ?? const <Ingredient>[]) i.id: i.name,
                      };
                      return Column(
                        children: usagePageItems.map((e) => InfoListCard(
                              leadingIcon: Icons.kitchen,
                              accentColor: AppColors.teal,
                              title: ingredientNames[e.key] ?? e.key,
                              idText: 'ID: ${e.key}',
                              pills: [
                                StatPill(label: 'Used: ${e.value}', color: AppColors.rust),
                              ],
                            )).toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A visually prominent stat tile for the aggregate totals — bigger and
/// color-coded, instead of plain text rows, per testing feedback that the
/// totals should stand out more.
class _StatHighlight extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatHighlight({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brown.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
