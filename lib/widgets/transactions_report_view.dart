import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sales_report.dart';
import '../models/sales_transaction.dart';
import '../services/sales_service.dart';
import '../theme/app_colors.dart';
import 'info_list_card.dart';
import 'pagination_bar.dart';
import 'section_panel.dart';

/// Reports view listing every individual sale in the selected period,
/// grouped by day. Each transaction shows its time, the items sold
/// (quantity x name, with line totals) and the transaction total, e.g.
///   Oct 11  —  Transaction #1: 1x Cheese Burger, 2x Coke, Total P500.00
/// "Transaction #N" counts from the first sale of that day. Owner/Admin
/// only (it reveals prices), same as Product Sales.
class TransactionsReportView extends StatefulWidget {
  final ReportPeriod period;

  const TransactionsReportView({super.key, required this.period});

  @override
  State<TransactionsReportView> createState() => _TransactionsReportViewState();
}

class _TransactionsReportViewState extends State<TransactionsReportView> {
  final _salesService = SalesService();
  final _searchController = TextEditingController();
  final _timeFormat = DateFormat('h:mm a');
  final _dayFormat = DateFormat('EEEE, MMM d, y');
  final _money = NumberFormat('#,##0.00');

  List<SalesTransaction> _transactions = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int _pageSize = defaultPageSizeOptions.first;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TransactionsReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _periodLabel {
    switch (widget.period) {
      case ReportPeriod.daily:
        return 'Daily';
      case ReportPeriod.weekly:
        return 'Weekly';
      case ReportPeriod.monthly:
        return 'Monthly';
    }
  }

  DateTime _periodStart() {
    final now = DateTime.now();
    switch (widget.period) {
      case ReportPeriod.daily:
        return DateTime(now.year, now.month, now.day);
      case ReportPeriod.weekly:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case ReportPeriod.monthly:
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
    });
    try {
      final list = await _salesService.getTransactionsBetween(_periodStart(), DateTime.now());
      if (!mounted) return;
      setState(() {
        _transactions = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\'t load transactions. Tap refresh to try again.';
        _loading = false;
      });
    }
  }

  /// transaction id -> its number within its day (1 = first sale that day).
  Map<String, int> _numbering() {
    final ascending = [..._transactions]
      ..sort((a, b) => a.salesTransDate.compareTo(b.salesTransDate));
    final counters = <DateTime, int>{};
    final result = <String, int>{};
    for (final t in ascending) {
      final d = _day(t.salesTransDate);
      final n = (counters[d] ?? 0) + 1;
      counters[d] = n;
      result[t.id] = n;
    }
    return result;
  }

  Widget _dayHeader(DateTime day, int count, double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _dayFormat.format(day),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.brown),
            ),
          ),
          Text(
            '$count transaction${count == 1 ? "" : "s"} • ₱${_money.format(total)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brown.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }

  Widget _transactionCard(SalesTransaction t, int number) {
    return InfoListCard(
      leadingIcon: Icons.receipt_long,
      accentColor: AppColors.teal,
      title: 'Transaction #$number',
      idText: 'ID: ${t.id}',
      pills: [
        StatPill(label: _timeFormat.format(t.salesTransDate), color: AppColors.teal),
        StatPill(label: '${t.salesTransQty} item${t.salesTransQty == 1 ? "" : "s"}', color: AppColors.brown, muted: true),
        if (t.branch.isNotEmpty) StatPill(label: t.branch, color: AppColors.brown, muted: true),
      ],
      extra: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            for (final i in t.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${i.qty}×',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        i.productName.isEmpty ? 'Unknown item' : i.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.brown),
                      ),
                    ),
                    Text(
                      '₱${_money.format(i.lineTotal)}',
                      style: TextStyle(color: AppColors.brown.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            const Divider(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.brown)),
                ),
                Text(
                  '₱${_money.format(t.salesTransAmount)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.rust),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numbering = _numbering();

    // Day totals come from ALL transactions in the period, so they stay
    // correct even when a search or page hides some of that day's sales.
    final dayTotals = <DateTime, double>{};
    final dayCounts = <DateTime, int>{};
    for (final t in _transactions) {
      final d = _day(t.salesTransDate);
      dayTotals.update(d, (v) => v + t.salesTransAmount, ifAbsent: () => t.salesTransAmount);
      dayCounts.update(d, (v) => v + 1, ifAbsent: () => 1);
    }

    final q = _query.trim().toLowerCase();
    final filtered = _transactions.where((t) {
      if (q.isEmpty) return true;
      return t.id.toLowerCase().contains(q) ||
          t.items.any((i) => i.productName.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => b.salesTransDate.compareTo(a.salesTransDate));

    final grandTotal = filtered.fold<double>(0, (sum, t) => sum + t.salesTransAmount);
    final pageItems = paginate(filtered, _page, _pageSize);

    final rows = <Widget>[];
    DateTime? lastDay;
    for (final t in pageItems) {
      final d = _day(t.salesTransDate);
      if (lastDay == null || d != lastDay) {
        rows.add(_dayHeader(d, dayCounts[d] ?? 0, dayTotals[d] ?? 0));
        lastDay = d;
      }
      rows.add(_transactionCard(t, numbering[t.id] ?? 0));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SectionPanel(
        title: 'Transactions — $_periodLabel',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {
                      _query = v;
                      _page = 0;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search by item or transaction ID...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.rust),
                      isDense: true,
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _query = '';
                                _page = 0;
                              }),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.rust),
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loading && _error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!),
              ),
            if (!_loading && _error == null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${filtered.length} transaction${filtered.length == 1 ? "" : "s"} • '
                  '₱${_money.format(grandTotal)} total',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brown.withValues(alpha: 0.7)),
                ),
              ),
              if (_transactions.isEmpty)
                const Text('No transactions recorded for this period.')
              else if (filtered.isEmpty)
                Text('No transactions match "$_query".')
              else ...[
                PaginationBar(
                  pageSize: _pageSize,
                  currentPage: _page,
                  totalItems: filtered.length,
                  onPageSizeChanged: (size) => setState(() {
                    _pageSize = size;
                    _page = 0;
                  }),
                  onPageChanged: (page) => setState(() => _page = page),
                ),
                ...rows,
              ],
            ],
          ],
        ),
      ),
    );
  }
}
