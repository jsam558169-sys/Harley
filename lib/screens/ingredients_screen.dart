import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ingredient.dart';
import '../models/inventory_stock.dart';
import '../models/measurement_unit.dart';
import '../models/product.dart';
import '../services/ingredient_service.dart';
import '../services/inventory_service.dart';
import '../services/loss_service.dart';
import '../services/product_service.dart';
import '../services/collections.dart';
import '../theme/app_colors.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/responsive.dart';
import '../widgets/info_list_card.dart';

enum _IngredientSortOption { nameAsc, nameDesc, freshQtyAsc, freshQtyDesc }

extension on _IngredientSortOption {
  String get label {
    switch (this) {
      case _IngredientSortOption.nameAsc:
        return 'Name (A–Z)';
      case _IngredientSortOption.nameDesc:
        return 'Name (Z–A)';
      case _IngredientSortOption.freshQtyAsc:
        return 'Fresh Stock (Low–High, by unit)';
      case _IngredientSortOption.freshQtyDesc:
        return 'Fresh Stock (High–Low, by unit)';
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
  final _productService = ProductService();
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
        result.sort((a, b) {
          final unitCompare = a.unit.compareTo(b.unit);
          if (unitCompare != 0) return unitCompare;
          return a.freshQty.compareTo(b.freshQty);
        });
        break;
      case _IngredientSortOption.freshQtyDesc:
        result.sort((a, b) {
          final unitCompare = a.unit.compareTo(b.unit);
          if (unitCompare != 0) return unitCompare;
          return b.freshQty.compareTo(a.freshQty);
        });
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
    final costController = TextEditingController(text: existing != null ? existing.costPerUnit.toString() : '');
    MeasurementUnit unit = MeasurementUnit.piece;
    bool isSaving = false;

    // Captured once, before `unit` starts changing via the dropdown — this
    // stays the ORIGINAL unit for the rest of the dialog's lifetime, used
    // to detect a unit change and work out whether it's auto-convertible.
    MeasurementUnit? originalUnitEnum;

    if (existing != null) {
      final match = MeasurementUnit.values.firstWhere(
        (u) => u.shortLabel == existing.unit,
        orElse: () => MeasurementUnit.custom,
      );
      unit = match;
      originalUnitEnum = match;
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                decoration: InputDecoration(
                  labelText: 'Cost per ${unit == MeasurementUnit.custom && customUnitController.text.isNotEmpty ? customUnitController.text : unit.shortLabel} (₱)',
                  helperText: 'What this costs you — used to calculate profit on Reports. Optional, defaults to ₱0.',
                  helperMaxLines: 2,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
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
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
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

                      num initialQty = 0;
                      if (!isEditing) {
                        initialQty = num.tryParse(qtyController.text.trim()) ?? 0;
                        if (initialQty < 0 || initialQty > maxInputValue) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Enter a quantity between 0 and $maxInputValue.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                      }

                      final costText = costController.text.trim();
                      final costPerUnit = costText.isEmpty ? 0 : num.tryParse(costText);
                      if (costPerUnit == null || costPerUnit < 0 || costPerUnit > maxInputValue) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Enter a cost between 0 and $maxInputValue, or leave it blank.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      // If editing and the unit is changing, work out whether
                      // it's a safely auto-convertible pair (g<->kg, ml<->L)
                      // or not, and find any product recipes that reference
                      // this ingredient.
                      num? conversionFactor;
                      List<Product> affectedProducts = [];
                      if (isEditing && unitLabel != existing.unit) {
                        conversionFactor = originalUnitEnum == null
                            ? null
                            : conversionFactorTo(originalUnitEnum, unit);
                        final products = await _productService.getAllProducts();
                        affectedProducts = products
                            .where((p) => p.recipeIngredients.any((r) => r.ingredientId == existing.id))
                            .toList();

                        if (conversionFactor != null) {
                          // Safe to auto-convert — still confirm, since this
                          // changes stored numbers (stock + recipe lines).
                          final newFresh = existing.freshQty * conversionFactor;
                          final newExpired = existing.expiredQty * conversionFactor;
                          if (ctx.mounted) {
                            final proceed = await confirmAction(
                              ctx,
                              title: 'Convert ${existing.unit} → $unitLabel',
                              message:
                                  'Stock will be converted: ${existing.freshQty} ${existing.unit} fresh → '
                                  '$newFresh $unitLabel, ${existing.expiredQty} ${existing.unit} expired → '
                                  '$newExpired $unitLabel.'
                                  '${affectedProducts.isEmpty ? '' : ' ${affectedProducts.length} recipe line(s) in '
                                      '(${affectedProducts.map((p) => p.name).join(", ")}) will also be converted '
                                      'automatically.'} Continue?',
                              confirmLabel: 'Convert',
                              confirmColor: AppColors.teal,
                            );
                            if (!proceed) return;
                          }
                        } else if (affectedProducts.isNotEmpty && ctx.mounted) {
                          // Not safely convertible (piece/bottle/custom
                          // involved) — same warning-only behavior as before.
                          final proceed = await confirmAction(
                            ctx,
                            title: 'Unit Change Affects Recipes',
                            message:
                                'This ingredient is used in ${affectedProducts.length} product recipe(s) '
                                '(${affectedProducts.map((p) => p.name).join(", ")}), which still reference the '
                                'old unit "${existing.unit}". They will NOT be automatically updated to '
                                '"$unitLabel" — you\'ll need to edit those recipes separately. Continue?',
                            confirmLabel: 'Continue',
                            confirmColor: AppColors.gold,
                          );
                          if (!proceed) return;
                        }
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        if (isEditing) {
                          final newFreshQty = conversionFactor != null
                              ? existing.freshQty * conversionFactor
                              : existing.freshQty;
                          final newExpiredQty = conversionFactor != null
                              ? existing.expiredQty * conversionFactor
                              : existing.expiredQty;

                          await _ingredientService.updateIngredient(Ingredient(
                            id: existing.id,
                            name: name,
                            freshQty: newFreshQty,
                            expiredQty: newExpiredQty,
                            unit: unitLabel,
                            costPerUnit: costPerUnit,
                          ));

                          // Auto-convert this ingredient's recipe lines in
                          // every affected product too, so Products/Recipes
                          // stays consistent with the new unit.
                          if (conversionFactor != null && affectedProducts.isNotEmpty) {
                            for (final product in affectedProducts) {
                              final updatedRecipe = product.recipeIngredients.map((r) {
                                if (r.ingredientId != existing.id) return r;
                                return RecipeItem(
                                  ingredientId: r.ingredientId,
                                  ingredientName: r.ingredientName,
                                  qtyPerUnit: r.qtyPerUnit * conversionFactor!,
                                  unit: unitLabel,
                                );
                              }).toList();
                              await _productService.updateProduct(Product(
                                id: product.id,
                                name: product.name,
                                price: product.price,
                                recipeIngredients: updatedRecipe,
                              ));
                            }
                          }
                        } else {
                          // Create with 0 stock first, then bring it up via a
                          // real Stock In movement — so the initial quantity
                          // actually shows up in the Stock Movement Log
                          // instead of silently appearing out of nowhere.
                          // Skipped entirely when initialQty is 0, so no
                          // spurious log entry gets created.
                          final newId = await _ingredientService.addIngredient(Ingredient(
                            id: '',
                            name: name,
                            freshQty: 0,
                            expiredQty: 0,
                            unit: unitLabel,
                            costPerUnit: costPerUnit,
                          ));
                          if (initialQty > 0) {
                            await _inventoryService.recordStockMovement(
                              itemId: newId,
                              isIngredient: true,
                              type: StockType.stockIn,
                              qty: initialQty,
                              note: 'Initial stock',
                            );
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } finally {
                        // If the dialog is still around (e.g. an error was
                        // thrown), let the user try again instead of being
                        // stuck with a permanently-disabled button.
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: Text(isSaving ? 'Saving...' : (isEditing ? 'Save Changes' : 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stockMovement(Ingredient ingredient, StockType type) async {
    final qtyController = TextEditingController();
    final isIn = type == StockType.stockIn;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '${isIn ? "Stock In" : "Stock Out"}: ${ingredient.name}',
            style: GoogleFonts.alfaSlabOne(fontSize: 17, color: AppColors.brown),
          ),
          content: TextField(
            controller: qtyController,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Quantity (${ingredient.unit})'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isIn ? AppColors.teal : AppColors.rust),
              onPressed: isSaving
                  ? null
                  : () async {
                      final qty = num.tryParse(qtyController.text.trim()) ?? 0;
                      if (qty <= 0 || qty > maxInputValue) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Enter a quantity between 0 and $maxInputValue.'),
                            behavior: SnackBarBehavior.floating,
                          ),
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
                      setDialogState(() => isSaving = true);
                      try {
                        await _inventoryService.recordStockMovement(
                          itemId: ingredient.id,
                          isIngredient: true,
                          type: type,
                          qty: qty,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: Text(isSaving ? 'Saving...' : (isIn ? 'Stock In' : 'Stock Out')),
            ),
          ],
        ),
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
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.stopRed),
              onPressed: isSaving
                  ? null
                  : () async {
                      final qty = num.tryParse(qtyController.text.trim()) ?? 0;
                      if (qty <= 0 || qty > ingredient.freshQty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Enter a quantity between 0 and ${ingredient.freshQty}.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await _lossService.markIngredientExpiredAndRecordLoss(
                          ingredientId: ingredient.id,
                          expiredQty: qty,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: Text(isSaving ? 'Saving...' : 'Confirm'),
            ),
          ],
        ),
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
                                  child: InfoListCard(
                                    leadingIcon: Icons.kitchen,
                                    accentColor: AppColors.rust,
                                    title: ing.name,
                                    idText: 'ID: ${ing.id}',
                                    trailingAction: widget.canManageCatalog
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, color: AppColors.teal),
                                                onPressed: () => _showEditIngredientDialog(ing),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: AppColors.stopRed),
                                                onPressed: () => _deleteIngredient(ing),
                                              ),
                                            ],
                                          )
                                        : null,
                                    pills: [
                                      StatPill(label: 'Fresh: ${ing.freshQty} ${ing.unit}', color: AppColors.teal),
                                      StatPill(
                                        label: 'Expired: ${ing.expiredQty} ${ing.unit}',
                                        color: ing.hasExpiredStock ? AppColors.stopRed : AppColors.cardBorder,
                                        muted: !ing.hasExpiredStock,
                                      ),
                                      StatPill(
                                        label: '₱${ing.costPerUnit.toStringAsFixed(2)} / ${ing.unit}',
                                        color: AppColors.gold,
                                        muted: ing.costPerUnit == 0,
                                      ),
                                    ],
                                    extra: Wrap(
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

