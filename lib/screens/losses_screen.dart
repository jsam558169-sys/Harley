import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/loss.dart';
import '../services/loss_service.dart';
import '../services/ingredient_service.dart';
import '../services/finished_product_service.dart';
import '../theme/app_colors.dart';

enum _LossSortOption { dateNewest, dateOldest, nameAsc, nameDesc }

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
// Ingredients & Stock screen). A reason filter here would be pointless
// until there's a second reachable reason — add one back once that exists.
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

/// Lists recorded losses with the item's real name + ID resolved, plus
/// search and sort.
class LossesScreen extends StatefulWidget {
  const LossesScreen({super.key});

  @override
  State<LossesScreen> createState() => _LossesScreenState();
}

class _LossesScreenState extends State<LossesScreen> {
  final _lossService = LossService();
  final _ingredientService = IngredientService();
  final _finishedProductService = FinishedProductService();
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('MMM d, y  h:mm a');

  late Future<Map<String, String>> _nameMapFuture;
  String _searchQuery = '';
  _LossSortOption _sortOption = _LossSortOption.dateNewest;

  @override
  void initState() {
    super.initState();
    _nameMapFuture = _loadNameMap();
  }

  Future<Map<String, String>> _loadNameMap() async {
    final ingredients = await _ingredientService.getAllIngredients();
    final finishedProducts = await _finishedProductService.getAllFinishedProducts();
    return {
      for (final i in ingredients) i.id: i.name,
      for (final f in finishedProducts) f.id: f.name,
    };
  }

  void _refreshNameMap() {
    setState(() {
      _nameMapFuture = _loadNameMap();
    });
  }

  List<LossEntry> _filterSort(List<LossEntry> entries, Map<String, String> nameMap) {
    String nameOf(LossEntry e) => nameMap[e.itemId] ?? e.itemId;

    var result = entries.where((e) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return nameOf(e).toLowerCase().contains(q) || e.itemId.toLowerCase().contains(q);
    }).toList();

    switch (_sortOption) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Losses'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh item names', onPressed: _refreshNameMap),
        ],
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _nameMapFuture,
        builder: (context, nameSnap) {
          if (!nameSnap.hasData) return const Center(child: CircularProgressIndicator());
          final nameMap = nameSnap.data!;

          return StreamBuilder<List<LossEntry>>(
            stream: _lossService.watchLosses(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final allLosses = snapshot.data!;

              if (allLosses.isEmpty) {
                return const Center(child: Text('No losses recorded.'));
              }

              final losses = _filterSort(allLosses, nameMap);
              final totalQty = losses.fold<int>(0, (sum, e) => sum + e.lossQty);

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
                              hintText: 'Search by item name or ID...',
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
                        PopupMenuButton<_LossSortOption>(
                          icon: const Icon(Icons.swap_vert, color: AppColors.rust),
                          tooltip: 'Sort losses',
                          initialValue: _sortOption,
                          onSelected: (option) => setState(() => _sortOption = option),
                          itemBuilder: (context) => _LossSortOption.values
                              .map((option) => PopupMenuItem(
                                    value: option,
                                    child: Row(
                                      children: [
                                        Text(option.label),
                                        if (option == _sortOption) ...[
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
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${losses.length} loss entr${losses.length == 1 ? "y" : "ies"} • $totalQty total unit${totalQty == 1 ? "" : "s"} lost',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brown.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: losses.isEmpty
                        ? const Center(child: Text('No losses match your search.'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 4, bottom: 16),
                            itemCount: losses.length,
                            itemBuilder: (context, i) {
                              final loss = losses[i];
                              final name = nameMap[loss.itemId] ?? loss.itemId;
                              final color = _reasonColor(loss.lossReason);
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.15),
                                    child: Icon(Icons.remove_shopping_cart, color: color, size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.cream,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: AppColors.cardBorder),
                                        ),
                                        child: Text(
                                          loss.isIngredient ? 'Ingredient' : 'Finished Product',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brown),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ID: ${loss.itemId}',
                                          style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.55)),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                lossReasonToString(loss.lossReason),
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('Qty: ${loss.lossQty}'),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(_dateFormat.format(loss.lossDate)),
                                      ],
                                    ),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
