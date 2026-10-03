import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/low_stock_event.dart';
import '../services/low_stock_event_service.dart';
import '../theme/app_colors.dart';
import '../widgets/info_list_card.dart';

enum _HistorySort { newest, oldest, nameAsc, nameDesc }

extension on _HistorySort {
  String get label {
    switch (this) {
      case _HistorySort.newest:
        return 'Date (Newest First)';
      case _HistorySort.oldest:
        return 'Date (Oldest First)';
      case _HistorySort.nameAsc:
        return 'Name (A–Z)';
      case _HistorySort.nameDesc:
        return 'Name (Z–A)';
    }
  }
}

/// A log of every time a product newly became low stock, with the date and
/// time it was detected, how many servings were left, and the threshold in
/// effect at the time.
class LowStockHistoryScreen extends StatefulWidget {
  const LowStockHistoryScreen({super.key});

  @override
  State<LowStockHistoryScreen> createState() => _LowStockHistoryScreenState();
}

class _LowStockHistoryScreenState extends State<LowStockHistoryScreen> {
  final _eventService = LowStockEventService();
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('MMM d, y  h:mm a');

  String _searchQuery = '';
  _HistorySort _sort = _HistorySort.newest;

  List<LowStockEvent> _filterSort(List<LowStockEvent> events) {
    final q = _searchQuery.trim().toLowerCase();
    final result = events.where((e) {
      if (q.isEmpty) return true;
      return e.productName.toLowerCase().contains(q) || e.productId.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case _HistorySort.newest:
        result.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        break;
      case _HistorySort.oldest:
        result.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
        break;
      case _HistorySort.nameAsc:
        result.sort((a, b) => a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));
        break;
      case _HistorySort.nameDesc:
        result.sort((a, b) => b.productName.toLowerCase().compareTo(a.productName.toLowerCase()));
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Low Stock History')),
      body: StreamBuilder<List<LowStockEvent>>(
        stream: _eventService.watchEvents(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;

          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No low-stock events logged yet. An entry is added whenever a product newly drops to the low-stock threshold.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final events = _filterSort(all);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search by product name or ID...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.rust),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<_HistorySort>(
                      icon: const Icon(Icons.swap_vert, color: AppColors.rust),
                      tooltip: 'Sort history',
                      initialValue: _sort,
                      onSelected: (option) => setState(() => _sort = option),
                      itemBuilder: (context) => _HistorySort.values
                          .map((option) => PopupMenuItem(
                                value: option,
                                child: Row(
                                  children: [
                                    Text(option.label),
                                    if (option == _sort) ...[
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${events.length} event${events.length == 1 ? "" : "s"}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brown.withValues(alpha: 0.7)),
                  ),
                ),
              ),
              Expanded(
                child: events.isEmpty
                    ? const Center(child: Text('No events match your search.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: events.length,
                        itemBuilder: (context, i) {
                          final e = events[i];
                          return InfoListCard(
                            leadingIcon: Icons.warning_amber,
                            accentColor: AppColors.stopRed,
                            title: e.productName,
                            idText: 'ID: ${e.productId}',
                            pills: [
                              StatPill(
                                label: e.servingsAtEvent <= 0 ? 'Sold out' : '${e.servingsAtEvent} serving(s) left',
                                color: AppColors.stopRed,
                              ),
                              StatPill(label: 'Threshold: ${e.threshold}', color: AppColors.brown, muted: true),
                            ],
                            footerText: _dateFormat.format(e.occurredAt),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
