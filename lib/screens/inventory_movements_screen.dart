import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_stock.dart';
import '../services/inventory_service.dart';
import '../services/ingredient_service.dart';
import '../services/finished_product_service.dart';
import '../theme/app_colors.dart';

enum _MovementSortOption { dateNewest, dateOldest, nameAsc, nameDesc, typeInFirst, typeOutFirst }

extension on _MovementSortOption {
  String get label {
    switch (this) {
      case _MovementSortOption.dateNewest:
        return 'Date (Newest First)';
      case _MovementSortOption.dateOldest:
        return 'Date (Oldest First)';
      case _MovementSortOption.nameAsc:
        return 'Name (A–Z)';
      case _MovementSortOption.nameDesc:
        return 'Name (Z–A)';
      case _MovementSortOption.typeInFirst:
        return 'Stock In First';
      case _MovementSortOption.typeOutFirst:
        return 'Stock Out First';
    }
  }
}

enum _TypeFilter { all, stockIn, stockOut }

/// Full audit trail of stock-in / stock-out movements, including the
/// automatic stock-outs created by completed sales. Each row resolves the
/// item's actual name (and shows its ID underneath) rather than the raw
/// Firestore document ID, and can be searched, sorted, and filtered by type.
class InventoryMovementsScreen extends StatefulWidget {
  const InventoryMovementsScreen({super.key});

  @override
  State<InventoryMovementsScreen> createState() => _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  final _inventoryService = InventoryService();
  final _ingredientService = IngredientService();
  final _finishedProductService = FinishedProductService();
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('MMM d, y  h:mm a');

  late Future<Map<String, String>> _nameMapFuture;
  String _searchQuery = '';
  _MovementSortOption _sortOption = _MovementSortOption.dateNewest;
  _TypeFilter _typeFilter = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    _nameMapFuture = _loadNameMap();
  }

  /// Builds a single itemId -> display name lookup spanning both
  /// ingredients and finished products, since a movement's itemId can be
  /// either.
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

  List<InventoryStockEntry> _filterSort(List<InventoryStockEntry> entries, Map<String, String> nameMap) {
    String nameOf(InventoryStockEntry e) => nameMap[e.itemId] ?? e.itemId;

    var result = entries.where((e) {
      if (_typeFilter == _TypeFilter.stockIn && e.stockType != StockType.stockIn) return false;
      if (_typeFilter == _TypeFilter.stockOut && e.stockType != StockType.stockOut) return false;
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return nameOf(e).toLowerCase().contains(q) || e.itemId.toLowerCase().contains(q);
    }).toList();

    switch (_sortOption) {
      case _MovementSortOption.dateNewest:
        result.sort((a, b) => b.stockDate.compareTo(a.stockDate));
        break;
      case _MovementSortOption.dateOldest:
        result.sort((a, b) => a.stockDate.compareTo(b.stockDate));
        break;
      case _MovementSortOption.nameAsc:
        result.sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));
        break;
      case _MovementSortOption.nameDesc:
        result.sort((a, b) => nameOf(b).toLowerCase().compareTo(nameOf(a).toLowerCase()));
        break;
      case _MovementSortOption.typeInFirst:
        result.sort((a, b) {
          final rankA = a.stockType == StockType.stockIn ? 0 : 1;
          final rankB = b.stockType == StockType.stockIn ? 0 : 1;
          if (rankA != rankB) return rankA.compareTo(rankB);
          return b.stockDate.compareTo(a.stockDate);
        });
        break;
      case _MovementSortOption.typeOutFirst:
        result.sort((a, b) {
          final rankA = a.stockType == StockType.stockOut ? 0 : 1;
          final rankB = b.stockType == StockType.stockOut ? 0 : 1;
          if (rankA != rankB) return rankA.compareTo(rankB);
          return b.stockDate.compareTo(a.stockDate);
        });
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Movement Log'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh item names', onPressed: _refreshNameMap),
        ],
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _nameMapFuture,
        builder: (context, nameSnap) {
          if (!nameSnap.hasData) return const Center(child: CircularProgressIndicator());
          final nameMap = nameSnap.data!;

          return StreamBuilder<List<InventoryStockEntry>>(
            stream: _inventoryService.watchMovements(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final allMovements = snapshot.data!;

              if (allMovements.isEmpty) {
                return const Center(child: Text('No stock movements yet.'));
              }

              final movements = _filterSort(allMovements, nameMap);

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
                        PopupMenuButton<_MovementSortOption>(
                          icon: const Icon(Icons.swap_vert, color: AppColors.rust),
                          tooltip: 'Sort movements',
                          initialValue: _sortOption,
                          onSelected: (option) => setState(() => _sortOption = option),
                          itemBuilder: (context) => _MovementSortOption.values
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _typeFilter == _TypeFilter.all,
                          onSelected: () => setState(() => _typeFilter = _TypeFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Stock In',
                          selected: _typeFilter == _TypeFilter.stockIn,
                          color: AppColors.teal,
                          onSelected: () => setState(() => _typeFilter = _TypeFilter.stockIn),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Stock Out',
                          selected: _typeFilter == _TypeFilter.stockOut,
                          color: AppColors.rust,
                          onSelected: () => setState(() => _typeFilter = _TypeFilter.stockOut),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: movements.isEmpty
                        ? const Center(child: Text('No movements match your filters.'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            itemCount: movements.length,
                            itemBuilder: (context, i) {
                              final m = movements[i];
                              final isIn = m.stockType == StockType.stockIn;
                              final name = nameMap[m.itemId] ?? m.itemId;
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: (isIn ? AppColors.teal : AppColors.rust).withValues(alpha: 0.15),
                                    child: Icon(
                                      isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: isIn ? AppColors.teal : AppColors.rust,
                                    ),
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
                                          m.isIngredient ? 'Ingredient' : 'Finished Product',
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
                                          'ID: ${m.itemId}',
                                          style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.55)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('${stockTypeToString(m.stockType)} • Qty ${m.stockQty}'),
                                        Text('${_dateFormat.format(m.stockDate)}${m.note != null ? " • ${m.note}" : ""}'),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color = AppColors.brown,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? color : AppColors.brown,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? color : AppColors.cardBorder),
    );
  }
}
