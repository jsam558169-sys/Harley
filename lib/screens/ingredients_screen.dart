import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ingredient.dart';
import '../models/inventory_stock.dart';
import '../models/measurement_unit.dart';
import '../services/ingredient_service.dart';
import '../services/inventory_service.dart';
import '../services/loss_service.dart';
import '../theme/app_colors.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/responsive.dart';

enum _IngredientSortOption { nameAsc, nameDesc, freshQtyAsc, freshQtyDesc }

extension on _IngredientSortOption {
  String get label {
    switch (this) {
      case _IngredientSortOption.nameAsc:
        return 'Name (A–Z)';
      case _IngredientSortOption.nameDesc:
        return 'Name (Z–A)';
      case _IngredientSortOption.freshQtyAsc:
        return 'Fresh Stock (Low–High)';
      case _IngredientSortOption.freshQtyDesc:
        return 'Fresh Stock (High–Low)';
    }
  }
}

/// Lists ingredients with fresh vs expired quantity shown separately, plus
/// search, sort, stock-in/out buttons, mark-expired, and (if allowed)
/// catalog management.
class IngredientsScreen extends StatefulWidget {
  /// Whether this user can add new ingredients to the catalog or delete
  /// existing ones. Stock-in/stock-out and marking-expired are always
  /// available regardless of this flag — those are day-to-day operational
  /// actions, not catalog management.
  final bool canManageCatalog;

  const IngredientsScreen({super.key, this.canManageCatalog = true});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  final _ingredientService = IngredientService();
  final _inventoryService = InventoryService();
  final _lossService = LossService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _IngredientSortOption _sortOption = _IngredientSortOption.nameAsc;

  List<Ingredient> _filterAndSort(List<Ingredient> ingredients) {
    var result = ingredients.where((i) {
      if (_searchQuery.trim().isEmpty) return true;
      return i.name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    switch (_sortOption) {
      case _IngredientSortOption.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _IngredientSortOption.nameDesc:
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _IngredientSortOption.freshQtyAsc:
        result.sort((a, b) => a.freshQty.compareTo(b.freshQty));
        break;
      case _IngredientSortOption.freshQtyDesc:
        result.sort((a, b) => b.freshQty.compareTo(a.freshQty));
        break;
    }
    return result;
  }

  Future<void> _showAddIngredientDialog() async {
    await _showIngredientFormDialog();
  }

  Future<void> _showEditIngredientDialog(Ingredient ingredient) async {
    await _showIngredientFormDialog(existing: ingredient);
  }

  /// Shared form for both adding a new ingredient and editing an existing
  /// one's name/unit. Editing deliberately does NOT touch freshQty/expiredQty
  /// — those only ever change through Stock In/Out or Mark Expired, so the
  /// movement log and loss records stay an accurate audit trail.
  Future<void> _showIngredientFormDialog({Ingredient? existing}) async {
    final isEditing = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final qtyController = TextEditingController();
    final customUnitController = TextEditingController();
    MeasurementUnit unit = MeasurementUnit.piece;

    if (existing != null) {
      final match = MeasurementUnit.values.firstWhere(
        (u) => u.shortLabel == existing.unit,
        orElse: () => MeasurementUnit.custom,
      );
      unit = match;
      if (match == MeasurementUnit.custom) {
        customUnitController.text = existing.unit;
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Edit Ingredient' : 'Add Ingredient',
            style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name *')),
              if (!isEditing) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Initial Fresh Qty'),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<MeasurementUnit>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Unit of Measurement'),
                items: MeasurementUnit.values
                    .map((u) => DropdownMenuItem(value: u, child: Text(u.displayLabel)))
                    .toList(),
                onChanged: (v) => setDialogState(() => unit = v!),
              ),
              if (unit == MeasurementUnit.custom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: customUnitController,
                  decoration: const InputDecoration(labelText: 'Custom unit label (e.g. "sachet")'),
                ),
              ],
              if (isEditing) ...[
                const SizedBox(height: 12),
                Text(
                  'Fresh: ${existing.freshQty} ${existing.unit} • Expired: ${existing.expiredQty} ${existing.unit}\n'
                  'Use Stock In / Stock Out / Mark Expired to change quantities.',
                  style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.6)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name is required.'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                final unitLabel = unit == MeasurementUnit.custom
                    ? customUnitController.text.trim()
                    : unit.shortLabel;
                if (unitLabel.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter a custom unit label.'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                if (isEditing) {
                  await _ingredientService.updateIngredient(Ingredient(
                    id: existing.id,
                    name: name,
                    freshQty: existing.freshQty,
                    expiredQty: existing.expiredQty,
                    unit: unitLabel,
                  ));
                } else {
                  await _ingredientService.addIngredient(Ingredient(
                    id: '',
                    name: name,
                    freshQty: int.tryParse(qtyController.text.trim()) ?? 0,
                    expiredQty: 0,
                    unit: unitLabel,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save Changes' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stockMovement(Ingredient ingredient, StockType type) async {
    final qtyController = TextEditingController();
    final isIn = type == StockType.stockIn;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${isIn ? "Stock In" : "Stock Out"}: ${ingredient.name}',
          style: GoogleFonts.alfaSlabOne(fontSize: 17, color: AppColors.brown),
        ),
        content: TextField(
          controller: qtyController,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Quantity (${ingredient.unit})'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isIn ? AppColors.teal : AppColors.rust),
            onPressed: () async {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (qty <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a quantity greater than 0.'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              if (!isIn && qty > ingredient.freshQty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Only ${ingredient.freshQty} ${ingredient.unit} fresh stock available.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              await _inventoryService.recordStockMovement(
                itemId: ingredient.id,
                isIngredient: true,
                type: type,
                qty: qty,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isIn ? 'Stock In' : 'Stock Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _markExpired(Ingredient ingredient) async {
    if (ingredient.freshQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fresh stock available to mark as expired.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final qtyController = TextEditingController(text: ingredient.freshQty.toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark Expired: ${ingredient.name}', style: GoogleFonts.alfaSlabOne(fontSize: 17, color: AppColors.brown)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fresh on hand: ${ingredient.freshQty} ${ingredient.unit}'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              decoration: InputDecoration(labelText: 'Expired Quantity (${ingredient.unit})'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.stopRed),
            onPressed: () async {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (qty <= 0 || qty > ingredient.freshQty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Enter a quantity between 1 and ${ingredient.freshQty}.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              await _lossService.markIngredientExpiredAndRecordLoss(
                ingredientId: ingredient.id,
                expiredQty: qty,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteIngredient(Ingredient ingredient) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete Ingredient',
      message: 'Delete "${ingredient.name}"? This can\'t be undone.',
    );
    if (confirmed) {
      await _ingredientService.deleteIngredient(ingredient.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ingredient.name} deleted'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingredients & Stock')),
      floatingActionButton: widget.canManageCatalog
          ? FloatingActionButton.extended(
              onPressed: _showAddIngredientDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            )
          : null,
      body: StreamBuilder<List<Ingredient>>(
        stream: _ingredientService.watchIngredients(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final allIngredients = snapshot.data!;

          if (allIngredients.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.cardBorder),
                    const SizedBox(height: 12),
                    Text('No ingredients yet', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
                    const SizedBox(height: 6),
                    Text(
                      widget.canManageCatalog
                          ? 'Add your first ingredient to start tracking stock.'
                          : 'Ask an Owner/Admin to add ingredients to the catalog.',
                      textAlign: TextAlign.center,
                    ),
                    if (widget.canManageCatalog) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showAddIngredientDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Ingredient'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final ingredients = _filterAndSort(allIngredients);

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
                          hintText: 'Search ingredients...',
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
                    PopupMenuButton<_IngredientSortOption>(
                      icon: const Icon(Icons.swap_vert, color: AppColors.rust),
                      tooltip: 'Sort ingredients',
                      initialValue: _sortOption,
                      onSelected: (option) => setState(() => _sortOption = option),
                      itemBuilder: (context) => _IngredientSortOption.values
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
              Expanded(
                child: ingredients.isEmpty
                    ? Center(child: Text('No ingredients match "$_searchQuery".'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = gridColumnsForWidth(constraints.maxWidth);
                          final cardWidth = wrapCardWidth(constraints.maxWidth, columns);
                          return SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 80),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: ingredients.map((ing) {
                                return SizedBox(
                                  width: cardWidth,
                                  child: Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                      ),
                                      if (widget.canManageCatalog) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppColors.teal),
                                          onPressed: () => _showEditIngredientDialog(ing),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppColors.stopRed),
                                          onPressed: () => _deleteIngredient(ing),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Fresh vs Expired shown side by side, not just a single total.
                                  Row(
                                    children: [
                                      _StockPill(
                                        label: 'Fresh',
                                        value: '${ing.freshQty} ${ing.unit}',
                                        color: AppColors.teal,
                                      ),
                                      const SizedBox(width: 8),
                                      _StockPill(
                                        label: 'Expired',
                                        value: '${ing.expiredQty} ${ing.unit}',
                                        color: ing.hasExpiredStock ? AppColors.stopRed : AppColors.cardBorder,
                                        muted: !ing.hasExpiredStock,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _stockMovement(ing, StockType.stockIn),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Stock In'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.teal,
                                          side: const BorderSide(color: AppColors.teal),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _stockMovement(ing, StockType.stockOut),
                                        icon: const Icon(Icons.remove, size: 16),
                                        label: const Text('Stock Out'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.rust,
                                          side: const BorderSide(color: AppColors.rust),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _markExpired(ing),
                                        icon: const Icon(Icons.warning_amber, size: 16),
                                        label: const Text('Mark Expired'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.gold,
                                          side: const BorderSide(color: AppColors.gold),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                                  ),
                                );
                              }).toList(),
                            ),
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

/// Small rounded badge used to show "Fresh: 20 kg" / "Expired: 5 kg" side
/// by side, instead of one combined total.
class _StockPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool muted;

  const _StockPill({required this.label, required this.value, required this.color, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: muted ? 0.08 : 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: muted ? 0.3 : 1)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: muted ? AppColors.brown.withValues(alpha: 0.5) : AppColors.brown,
        ),
      ),
    );
  }
}
