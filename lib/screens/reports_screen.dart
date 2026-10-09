import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sales_report.dart';
import '../models/product.dart';
import '../models/ingredient.dart';
import '../models/finished_product.dart';
import '../models/loss.dart';
import '../services/report_service.dart';
import '../services/ingredient_service.dart';
import '../services/product_service.dart';
import '../services/finished_product_service.dart';
import '../services/loss_service.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive.dart';
import '../widgets/info_list_card.dart';
import '../widgets/bar_charts.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/section_panel.dart';

enum _ProductSortOption { nameAsc, nameDesc, lastSoldNewest, lastSoldOldest, soldHigh, soldLow }

enum _LossSortOption { dateNewest, dateOldest, nameAsc, nameDesc }

enum _ReportView { salesSummary, bestSellers, productSales, losses, ingredientUsage }

extension on _LossSortOption {
  String get label {
    switch (this) {
      case _LossSortOption.dateNewest:
        return 'Date (Newest First)';
      case _LossSortOption.dateOldest:
        return 'Date (Oldest First)';
      case _LossSortOption.nameAsc:
        return 'Name (A–Z)';
      case _LossSortOption.nameDesc:
        return 'Name (Z–A)';
    }
  }
}

// NOTE: LossReason still has expired/spoiled/replacedOrder/other, but only
// "expired" has an actual UI path that creates one (Mark Expired on the
// Ingredients & Stock screen).
Color _reasonColor(LossReason r) {
  switch (r) {
    case LossReason.expired:
      return AppColors.stopRed;
    case LossReason.spoiled:
      return AppColors.rust;
    case LossReason.replacedOrder:
      return AppColors.gold;
    case LossReason.other:
      return AppColors.teal;
  }
}

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
      case _ProductSortOption.soldHigh:
        return 'Sold (High–Low)';
      case _ProductSortOption.soldLow:
        return 'Sold (Low–High)';
    }
  }
}

String _periodLabel(ReportPeriod p) {
  switch (p) {
    case ReportPeriod.daily:
      return 'Daily';
    case ReportPeriod.weekly:
      return 'Weekly';
    case ReportPeriod.monthly:
      return 'Monthly';
  }
}

/// Reports screen: ONE period selector (Daily/Weekly/Monthly) drives every
/// graph on this screen, and a report-type picker shows a single section
/// at a time (Sales Summary / Best Sellers / Product Sales / Ingredient
/// Usage) instead of stacking everything into one long scroll.
class ReportsScreen extends StatefulWidget {
  /// Owner/Admin sees full sales figures + Best Sellers + Product Sales
  /// (which reveal price, and therefore revenue). Employees (per the
  /// feasibility study) only get Sales Summary (items only) and
  /// Ingredient Usage.
  final bool showSalesFigures;

  const ReportsScreen({super.key, this.showSalesFigures = true});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _reportService = ReportService();
  final _ingredientService = IngredientService();
  final _productService = ProductService();
  final _finishedProductService = FinishedProductService();
  final _lossService = LossService();
  final _productSearchController = TextEditingController();
  final _lossSearchController = TextEditingController();
  final _dateFormat = DateFormat('MMM d, y');
  final _lossDateFormat = DateFormat('MMM d, y  h:mm a');

  ReportPeriod _period = ReportPeriod.daily;
  late _ReportView _view;

  // Aggregate report (period-based).
  SalesReport? _report;
  ProfitSummary? _profitSummary;
  Map<String, num>? _usageSummary;
  bool _loadingAggregate = false;
  int _usagePageSize = defaultPageSizeOptions.first;
  int _usagePage = 0;
  String _usageSearchQuery = '';
  final _usageSearchController = TextEditingController();

  // Per-product breakdown — loaded once with daily/weekly/monthly all
  // together; which one is actually shown is picked at render time based
  // on the global period selector above.
  List<Product> _products = [];
  Map<String, ProductSalesStat> _productBreakdown = {};
  bool _loadingProducts = false;
  String _productSearchQuery = '';
  _ProductSortOption _productSort = _ProductSortOption.soldHigh;
  int _productPageSize = defaultPageSizeOptions.first;
  int _productPage = 0;

  // Losses — moved in from its own former screen, now scoped to the same
  // global period as everything else here.
  String _lossSearchQuery = '';
  _LossSortOption _lossSort = _LossSortOption.dateNewest;
  int _lossPageSize = defaultPageSizeOptions.first;
  int _lossPage = 0;

  @override
  void initState() {
    super.initState();
    _view = _ReportView.salesSummary;
    _generateAggregate();
    if (widget.showSalesFigures) _loadProductBreakdown();
  }

  DateTime _periodStart(ReportPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.daily:
        return DateTime(now.year, now.month, now.day);
      case ReportPeriod.weekly:
        return now.subtract(Duration(days: now.weekday - 1));
      case ReportPeriod.monthly:
        return DateTime(now.year, now.month, 1);
    }
  }

  Future<void> _generateAggregate() async {
    setState(() {
      _loadingAggregate = true;
      _usagePage = 0;
      _lossPage = 0;
    });
    final report = await _reportService.generateSalesReport(period: _period);

    final now = DateTime.now();
    final start = _periodStart(_period);
    final usage = await _reportService.generateIngredientUsageSummary(start: start, end: now);
    final profit = widget.showSalesFigures
        ? await _reportService.generateProfitSummary(start: start, end: now)
        : ProfitSummary.zero;

    if (!mounted) return;
    setState(() {
      _report = report;
      _usageSummary = usage;
      _profitSummary = profit;
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

  int _soldForPeriod(Product p, ReportPeriod period) {
    final stat = _productBreakdown[p.id];
    if (stat == null) return 0;
    switch (period) {
      case ReportPeriod.daily:
        return stat.dailySold;
      case ReportPeriod.weekly:
        return stat.weeklySold;
      case ReportPeriod.monthly:
        return stat.monthlySold;
    }
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
      case _ProductSortOption.soldHigh:
        result.sort((a, b) => _soldForPeriod(b, _period).compareTo(_soldForPeriod(a, _period)));
        break;
      case _ProductSortOption.soldLow:
        result.sort((a, b) => _soldForPeriod(a, _period).compareTo(_soldForPeriod(b, _period)));
        break;
    }
    return result;
  }

  Map<_ReportView, String> get _availableViews => {
        _ReportView.salesSummary: 'Sales Summary',
        if (widget.showSalesFigures) _ReportView.bestSellers: 'Best Sellers',
        if (widget.showSalesFigures) _ReportView.productSales: 'Product Sales',
        if (widget.showSalesFigures) _ReportView.losses: 'Losses',
        _ReportView.ingredientUsage: 'Ingredient Usage',
      };

  List<LossEntry> _filterSortLosses(List<LossEntry> entries, Map<String, String> nameMap) {
    String nameOf(LossEntry e) => nameMap[e.itemId] ?? e.itemId;
    final start = _periodStart(_period);

    var result = entries.where((e) {
      if (e.lossDate.isBefore(start)) return false;
      if (_lossSearchQuery.trim().isEmpty) return true;
      final q = _lossSearchQuery.trim().toLowerCase();
      return nameOf(e).toLowerCase().contains(q) || e.itemId.toLowerCase().contains(q);
    }).toList();

    switch (_lossSort) {
      case _LossSortOption.dateNewest:
        result.sort((a, b) => b.lossDate.compareTo(a.lossDate));
        break;
      case _LossSortOption.dateOldest:
        result.sort((a, b) => a.lossDate.compareTo(b.lossDate));
        break;
      case _LossSortOption.nameAsc:
        result.sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));
        break;
      case _LossSortOption.nameDesc:
        result.sort((a, b) => nameOf(b).toLowerCase().compareTo(nameOf(a).toLowerCase()));
        break;
    }
    return result;
  }

  static const Map<_ReportView, IconData> _viewIcons = {
    _ReportView.salesSummary: Icons.summarize,
    _ReportView.bestSellers: Icons.emoji_events,
    _ReportView.productSales: Icons.shopping_bag,
    _ReportView.losses: Icons.remove_shopping_cart,
    _ReportView.ingredientUsage: Icons.kitchen,
  };

  /// Pill-style segmented control for Daily/Weekly/Monthly — every graph
  /// on this screen reacts to this one control.
  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: ReportPeriod.values.map((p) {
          final selected = _period == p;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _period = p);
                _generateAggregate();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.rust : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _periodLabel(p),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: selected ? AppColors.white : AppColors.brown,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Horizontally-scrollable row of larger, icon-labeled tabs for choosing
  /// which single report view is shown below — roomier than a wrapped row
  /// of small chips, and scrolls instead of cramming/wrapping awkwardly.
  Widget _buildViewTabs() {
    return SizedBox(
      height: 68,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _availableViews.entries.map((e) {
          final selected = _view == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => setState(() => _view = e.key),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.teal.withValues(alpha: 0.15) : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? AppColors.teal : AppColors.cardBorder, width: selected ? 1.5 : 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_viewIcons[e.key], size: 19, color: selected ? AppColors.teal : AppColors.brown.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Text(
                      e.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected ? AppColors.teal : AppColors.brown,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          _buildPeriodSelector(),
          _buildViewTabs(),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(child: _buildSelectedView()),
        ],
      ),
    );
  }

  Widget _buildSelectedView() {
    switch (_view) {
      case _ReportView.salesSummary:
        return _buildSalesSummaryView();
      case _ReportView.bestSellers:
        return _buildBestSellersView();
      case _ReportView.productSales:
        return _buildProductSalesView();
      case _ReportView.losses:
        return _buildLossesView();
      case _ReportView.ingredientUsage:
        return _buildIngredientUsageView();
    }
  }

  Widget _buildSalesSummaryView() {
    final profit = _profitSummary ?? ProfitSummary.zero;
    final profitColor = profit.netProfit >= 0 ? AppColors.teal : AppColors.stopRed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SectionPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_periodLabel(_period)} Sales Summary', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
            const SizedBox(height: 12),
            if (_loadingAggregate) const Center(child: CircularProgressIndicator()),
            if (!_loadingAggregate && _report != null) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (widget.showSalesFigures) ...[
                    _StatHighlight(
                      label: 'Gross Sales',
                      value: '₱${_report!.totalSales.toStringAsFixed(2)}',
                      color: AppColors.rust,
                    ),
                    _StatHighlight(
                      label: 'Total Cost',
                      value: '₱${profit.totalCost.toStringAsFixed(2)}',
                      color: AppColors.gold,
                    ),
                    _StatHighlight(
                      label: 'Net Profit',
                      value: '₱${profit.netProfit.toStringAsFixed(2)}',
                      color: profitColor,
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
                    color: AppColors.brown,
                  ),
                ],
              ),
              if (widget.showSalesFigures) ...[
                const SizedBox(height: 20),
                Text(
                  'Gross vs. Cost vs. Profit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.brown.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 8),
                ComparisonBarChart(
                  entries: [
                    MapEntry('Gross', _report!.totalSales),
                    MapEntry('Cost', profit.totalCost),
                    MapEntry('Net Profit', profit.netProfit),
                  ],
                  colors: [AppColors.rust, AppColors.gold, profitColor],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cost uses each ingredient\'s current cost-per-unit (set on Ingredients & Stock) applied to what was sold — '
                  'it isn\'t a snapshot of what ingredients cost on the day of each sale. Ingredients with no cost entered count as ₱0.',
                  style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.6)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBestSellersView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SectionPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Best Sellers — ${_periodLabel(_period)}', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
            const SizedBox(height: 8),
            if (_loadingProducts)
              const Center(child: CircularProgressIndicator())
            else
              Builder(builder: (context) {
                final ranked = _products.where((p) => _soldForPeriod(p, _period) > 0).toList()
                  ..sort((a, b) => _soldForPeriod(b, _period).compareTo(_soldForPeriod(a, _period)));
                final top = ranked.take(5).toList();
                if (top.isEmpty) {
                  return Text('No sales recorded for this ${_periodLabel(_period).toLowerCase()} period yet.');
                }
                return RankedBarChart(
                  entries: top.map((p) => MapEntry(p.name, _soldForPeriod(p, _period))).toList(),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSalesView() {
    final filteredProducts = _filterSortProducts();
    final productPageItems = paginate(filteredProducts, _productPage, _productPageSize);
    final maxOnPage = productPageItems.isEmpty
        ? 0
        : productPageItems.map((p) => _soldForPeriod(p, _period)).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SectionPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Sales — ${_periodLabel(_period)}', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
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
                      final sold = _soldForPeriod(p, _period);
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
                          extra: Row(
                            children: [
                              SingleValueBarChart(value: sold, maxValue: maxOnPage),
                              const SizedBox(width: 8),
                              Text('$sold sold', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal)),
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
    );
  }

  Widget _buildLossesView() {
    return StreamBuilder<List<Ingredient>>(
      stream: _ingredientService.watchIngredients(),
      builder: (context, ingredientSnap) {
        if (!ingredientSnap.hasData) return const Center(child: CircularProgressIndicator());

        return StreamBuilder<List<FinishedProduct>>(
          stream: _finishedProductService.watchAll(),
          builder: (context, finishedSnap) {
            if (!finishedSnap.hasData) return const Center(child: CircularProgressIndicator());

            final nameMap = {
              for (final i in ingredientSnap.data!) i.id: i.name,
              for (final f in finishedSnap.data!) f.id: f.name,
            };

            return StreamBuilder<List<LossEntry>>(
              stream: _lossService.watchLosses(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final losses = _filterSortLosses(snapshot.data!, nameMap);
                final totalQty = losses.fold<num>(0, (sum, e) => sum + e.lossQty);
                final lossPageItems = paginate(losses, _lossPage, _lossPageSize);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SectionPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Losses — ${_periodLabel(_period)}', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _lossSearchController,
                                onChanged: (v) => setState(() {
                                  _lossSearchQuery = v;
                                  _lossPage = 0;
                                }),
                                decoration: InputDecoration(
                                  hintText: 'Search by item name or ID...',
                                  prefixIcon: const Icon(Icons.search, color: AppColors.rust),
                                  isDense: true,
                                  suffixIcon: _lossSearchQuery.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.clear, size: 20),
                                          onPressed: () => setState(() {
                                            _lossSearchController.clear();
                                            _lossSearchQuery = '';
                                            _lossPage = 0;
                                          }),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<_LossSortOption>(
                              icon: const Icon(Icons.swap_vert, color: AppColors.rust),
                              tooltip: 'Sort losses',
                              initialValue: _lossSort,
                              onSelected: (option) => setState(() {
                                _lossSort = option;
                                _lossPage = 0;
                              }),
                              itemBuilder: (context) => _LossSortOption.values
                                  .map((option) => PopupMenuItem(
                                        value: option,
                                        child: Row(
                                          children: [
                                            Text(option.label),
                                            if (option == _lossSort) ...[
                                              const Spacer(),
                                              const Icon(Icons.check, size: 18, color: AppColors.rust),
                                            ],
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                        if (losses.isNotEmpty)
                          PaginationBar(
                            pageSize: _lossPageSize,
                            currentPage: _lossPage,
                            totalItems: losses.length,
                            onPageSizeChanged: (size) => setState(() {
                              _lossPageSize = size;
                              _lossPage = 0;
                            }),
                            onPageChanged: (page) => setState(() => _lossPage = page),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${losses.length} loss entr${losses.length == 1 ? "y" : "ies"} • $totalQty total unit${totalQty == 1 ? "" : "s"} lost this ${_periodLabel(_period).toLowerCase()} period',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brown.withValues(alpha: 0.7)),
                          ),
                        ),
                        if (losses.isEmpty)
                          const Text('No losses recorded for this period.')
                        else
                          Column(
                            children: lossPageItems.map((loss) {
                              final name = nameMap[loss.itemId] ?? loss.itemId;
                              final color = _reasonColor(loss.lossReason);
                              return InfoListCard(
                                leadingIcon: Icons.remove_shopping_cart,
                                accentColor: color,
                                title: name,
                                idText: 'ID: ${loss.itemId}',
                                badgeText: loss.isIngredient ? 'Ingredient' : 'Finished Product',
                                pills: [
                                  StatPill(label: lossReasonToString(loss.lossReason), color: color),
                                  StatPill(label: 'Qty: ${loss.lossQty}', color: AppColors.brown, muted: true),
                                ],
                                footerText: _lossDateFormat.format(loss.lossDate),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildIngredientUsageView() {
    final allUsageEntries = _usageSummary?.entries.toList() ?? [];

    // Resolving ingredient names via a live stream (rather than a one-off
    // fetch) so a newly-added ingredient's name shows up immediately
    // instead of needing a manual refresh — and so search can match on the
    // real name, not just the raw ID.
    return StreamBuilder<List<Ingredient>>(
      stream: _ingredientService.watchIngredients(),
      builder: (context, snapshot) {
        final ingredientNames = {
          for (final i in snapshot.data ?? const <Ingredient>[]) i.id: i.name,
        };

        final q = _usageSearchQuery.trim().toLowerCase();
        final usageEntries = allUsageEntries.where((e) {
          if (q.isEmpty) return true;
          final name = (ingredientNames[e.key] ?? e.key).toLowerCase();
          return name.contains(q) || e.key.toLowerCase().contains(q);
        }).toList();
        final usagePageItems = paginate(usageEntries, _usagePage, _usagePageSize);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SectionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingredient Usage — ${_periodLabel(_period)}', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
                const SizedBox(height: 8),
                TextField(
                  controller: _usageSearchController,
                  onChanged: (v) => setState(() {
                    _usageSearchQuery = v;
                    _usagePage = 0;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search by ingredient name or ID...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.rust),
                    isDense: true,
                    suffixIcon: _usageSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() {
                              _usageSearchController.clear();
                              _usageSearchQuery = '';
                              _usagePage = 0;
                            }),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingAggregate) const Center(child: CircularProgressIndicator()),
                if (!_loadingAggregate && allUsageEntries.isEmpty)
                  const Text('No ingredient usage recorded for this period.'),
                if (!_loadingAggregate && allUsageEntries.isNotEmpty && usageEntries.isEmpty)
                  Text('No ingredients match "$_usageSearchQuery".'),
                if (!_loadingAggregate && usageEntries.isNotEmpty) ...[
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
                  Column(
                    children: usagePageItems.map((e) => InfoListCard(
                          leadingIcon: Icons.kitchen,
                          accentColor: AppColors.teal,
                          title: ingredientNames[e.key] ?? e.key,
                          idText: 'ID: ${e.key}',
                          pills: [
                            StatPill(label: 'Used: ${e.value}', color: AppColors.rust),
                          ],
                        )).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A visually prominent stat tile for the aggregate totals — bigger and
/// color-coded, instead of plain text rows.
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
