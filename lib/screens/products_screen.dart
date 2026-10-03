import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../models/ingredient.dart';
import '../models/measurement_unit.dart';
import '../services/product_service.dart';
import '../services/ingredient_service.dart';
import '../services/collections.dart';
import '../theme/app_colors.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/responsive.dart';
import '../widgets/info_list_card.dart';

enum ProductSortOption { nameAsc, nameDesc, priceAsc, priceDesc }

extension on ProductSortOption {
  String get label {
    switch (this) {
      case ProductSortOption.nameAsc:
        return 'Name (A–Z)';
      case ProductSortOption.nameDesc:
        return 'Name (Z–A)';
      case ProductSortOption.priceAsc:
        return 'Price (Low–High)';
      case ProductSortOption.priceDesc:
        return 'Price (High–Low)';
    }
  }
}

/// Lists products, with search + sort, and lets you add a new one with its
/// recipe (which ingredients + how much of each are used per unit sold).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _productService = ProductService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ProductSortOption _sortOption = ProductSortOption.nameAsc;

  List<Product> _filterAndSort(List<Product> products) {
    var result = products.where((p) {
      if (_searchQuery.trim().isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    switch (_sortOption) {
      case ProductSortOption.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ProductSortOption.nameDesc:
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case ProductSortOption.priceAsc:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortOption.priceDesc:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
    }
    return result;
  }

  Future<void> _goToAddProduct() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
  }

  Future<void> _goToEditProduct(Product p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddProductScreen(existing: p)),
    );
  }

  Future<void> _deleteProduct(Product p) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete Product',
      message: 'Delete "${p.name}"? This can\'t be undone.',
    );
    if (confirmed) {
      await _productService.deleteProduct(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${p.name} deleted'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products / Recipes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _productService.watchProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final allProducts = snapshot.data!;

          if (allProducts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_menu, size: 56, color: AppColors.cardBorder),
                    const SizedBox(height: 12),
                    Text(
                      'No products yet',
                      style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add your first menu item and its recipe to get started.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _goToAddProduct,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Product'),
                    ),
                  ],
                ),
              ),
            );
          }

          final products = _filterAndSort(allProducts);

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
                          hintText: 'Search products...',
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
                    PopupMenuButton<ProductSortOption>(
                      icon: const Icon(Icons.swap_vert, color: AppColors.rust),
                      tooltip: 'Sort products',
                      initialValue: _sortOption,
                      onSelected: (option) => setState(() => _sortOption = option),
                      itemBuilder: (context) => ProductSortOption.values
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
                child: products.isEmpty
                    ? Center(child: Text('No products match "$_searchQuery".'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = gridColumnsForWidth(constraints.maxWidth);
                          final cardWidth = wrapCardWidth(constraints.maxWidth, columns);
                          return SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 80),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: products.map((p) {
                                return SizedBox(
                                  width: cardWidth,
                                  child: InfoListCard(
                                    leadingIcon: Icons.restaurant_menu,
                                    accentColor: AppColors.rust,
                                    title: p.name,
                                    idText: 'ID: ${p.id}',
                                    onTap: () => _goToEditProduct(p),
                                    trailingAction: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppColors.teal),
                                          onPressed: () => _goToEditProduct(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppColors.stopRed),
                                          onPressed: () => _deleteProduct(p),
                                        ),
                                      ],
                                    ),
                                    pills: [
                                      StatPill(label: '₱${p.price.toStringAsFixed(2)}', color: AppColors.rust),
                                      StatPill(label: '${p.recipeIngredients.length} ingredient(s)', color: AppColors.teal),
                                    ],
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

class AddProductScreen extends StatefulWidget {
  /// When set, the screen edits this product instead of creating a new one.
  final Product? existing;

  const AddProductScreen({super.key, this.existing});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _productService = ProductService();
  final _ingredientService = IngredientService();
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _priceController =
      TextEditingController(text: widget.existing != null ? widget.existing!.price.toString() : '');
  late final List<RecipeItem> _recipe = List.of(widget.existing?.recipeIngredients ?? []);
  List<Ingredient> _availableIngredients = [];
  bool _loadingIngredients = true;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _ingredientService.getAllIngredients().then((list) {
      if (!mounted) return;
      setState(() {
        _availableIngredients = list;
        _loadingIngredients = false;
      });
    });
  }

  Future<void> _openAddIngredientDialog() async {
    final usedIds = _recipe.map((r) => r.ingredientId).toSet();
    final unused = _availableIngredients.where((ing) => !usedIds.contains(ing.id)).toList();

    if (unused.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_availableIngredients.isEmpty
              ? 'No ingredients in your catalog yet — add some from Ingredients & Stock first.'
              : 'All available ingredients are already in this recipe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showDialog<RecipeItem>(
      context: context,
      builder: (_) => _AddRecipeIngredientDialog(ingredients: unused),
    );
    if (result != null) {
      setState(() => _recipe.add(result));
    }
  }

  Future<void> _removeRecipeLine(RecipeItem line) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Remove Ingredient',
      message: 'Remove "${line.ingredientName}" from this recipe?',
    );
    if (confirmed) {
      setState(() => _recipe.remove(line));
    }
  }

  Future<void> _save() async {
    if (_saving) return; // guards against double-submit crashes from rapid taps
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());

    if (name.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(name.isEmpty
              ? 'Product name is required.'
              : 'Enter a valid price greater than 0.'),
          backgroundColor: AppColors.stopRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (price > maxInputValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Price can\'t exceed $maxInputValue.'),
          backgroundColor: AppColors.stopRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final product = Product(
        id: widget.existing?.id ?? '',
        name: name,
        price: price,
        recipeIngredients: _recipe,
      );
      if (_isEditing) {
        await _productService.updateProduct(product);
      } else {
        await _productService.addProduct(product);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Product Name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(labelText: 'Price *', prefixText: '₱ '),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recipe', style: GoogleFonts.alfaSlabOne(fontSize: 16, color: AppColors.brown)),
              TextButton.icon(
                onPressed: _loadingIngredients ? null : _openAddIngredientDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Ingredient'),
              ),
            ],
          ),
          const Text(
            'Ingredients consumed each time one unit of this product is sold.',
            style: TextStyle(fontSize: 12, color: AppColors.brown),
          ),
          const SizedBox(height: 8),
          if (_recipe.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No ingredients added yet.'),
            )
          else
            ..._recipe.map((line) {
              final stillExists = _availableIngredients.any((ing) => ing.id == line.ingredientId);
              return Card(
                child: ListTile(
                  leading: stillExists
                      ? null
                      : const Icon(Icons.warning_amber, color: AppColors.stopRed),
                  title: Text(
                    line.ingredientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    stillExists
                        ? '${line.qtyPerUnit} ${line.unit}'
                        : '${line.qtyPerUnit} ${line.unit} • Ingredient deleted from catalog',
                    style: stillExists ? null : const TextStyle(color: AppColors.stopRed, fontWeight: FontWeight.w600),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.stopRed),
                    onPressed: () => _removeRecipeLine(line),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Save Product')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search + sort the ingredient catalog, pick one, then specify how much of
/// it (and in what unit) is used per product sold. Returns the finished
/// RecipeItem via Navigator.pop, or null if cancelled.
class _AddRecipeIngredientDialog extends StatefulWidget {
  final List<Ingredient> ingredients;
  const _AddRecipeIngredientDialog({required this.ingredients});

  @override
  State<_AddRecipeIngredientDialog> createState() => _AddRecipeIngredientDialogState();
}

enum _IngredientSortOption { nameAsc, nameDesc, qtyAsc, qtyDesc }

extension on _IngredientSortOption {
  String get label {
    switch (this) {
      case _IngredientSortOption.nameAsc:
        return 'Name (A–Z)';
      case _IngredientSortOption.nameDesc:
        return 'Name (Z–A)';
      case _IngredientSortOption.qtyAsc:
        return 'Stock (Low–High)';
      case _IngredientSortOption.qtyDesc:
        return 'Stock (High–Low)';
    }
  }
}

class _AddRecipeIngredientDialogState extends State<_AddRecipeIngredientDialog> {
  String _searchQuery = '';
  _IngredientSortOption _sortOption = _IngredientSortOption.nameAsc;
  Ingredient? _selected;

  final _qtyController = TextEditingController();
  MeasurementUnit _unit = MeasurementUnit.piece;
  final _customUnitController = TextEditingController();

  List<Ingredient> get _filteredSorted {
    var result = widget.ingredients.where((i) {
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
      case _IngredientSortOption.qtyAsc:
        result.sort((a, b) => a.freshQty.compareTo(b.freshQty));
        break;
      case _IngredientSortOption.qtyDesc:
        result.sort((a, b) => b.freshQty.compareTo(a.freshQty));
        break;
    }
    return result;
  }

  void _confirm() {
    final qty = num.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0 || qty > maxInputValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a quantity between 0 and $maxInputValue.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final unitLabel = _unit == MeasurementUnit.custom
        ? _customUnitController.text.trim()
        : _unit.shortLabel;
    if (unitLabel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a custom unit label.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    Navigator.of(context).pop(RecipeItem(
      ingredientId: _selected!.id,
      ingredientName: _selected!.name,
      qtyPerUnit: qty,
      unit: unitLabel,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        _selected == null ? 'Select Ingredient' : 'Add to Recipe',
        style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown),
      ),
      content: SizedBox(
        width: 360,
        child: _selected == null ? _buildPickerStep() : _buildDetailsStep(),
      ),
      actions: _selected == null
          ? [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))]
          : [
              TextButton(
                onPressed: () => setState(() => _selected = null),
                child: const Text('Back'),
              ),
              ElevatedButton(onPressed: _confirm, child: const Text('Add to Recipe')),
            ],
    );
  }

  Widget _buildPickerStep() {
    final ingredients = _filteredSorted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Search ingredients...',
                  prefixIcon: Icon(Icons.search, color: AppColors.rust),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<_IngredientSortOption>(
              icon: const Icon(Icons.swap_vert, color: AppColors.rust),
              tooltip: 'Sort ingredients',
              initialValue: _sortOption,
              onSelected: (option) => setState(() => _sortOption = option),
              itemBuilder: (context) => _IngredientSortOption.values
                  .map((option) => PopupMenuItem(value: option, child: Text(option.label)))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          width: double.infinity,
          child: ingredients.isEmpty
              ? const Center(child: Text('No matching ingredients.'))
              : ListView.builder(
                  itemCount: ingredients.length,
                  itemBuilder: (context, i) {
                    final ing = ingredients[i];
                    return ListTile(
                      dense: true,
                      title: Text(ing.name),
                      subtitle: Text('On hand: ${ing.freshQty} ${ing.unit}'),
                      onTap: () => setState(() {
                        _selected = ing;
                        // Pre-fill the recipe-line unit from the ingredient's
                        // own catalog unit so they usually match by default.
                        final match = MeasurementUnit.values.firstWhere(
                          (u) => u.shortLabel == ing.unit,
                          orElse: () => MeasurementUnit.custom,
                        );
                        _unit = match;
                        if (match == MeasurementUnit.custom) {
                          _customUnitController.text = ing.unit;
                        }
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: const Icon(Icons.kitchen, size: 18, color: AppColors.rust),
          label: Text(_selected!.name),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _qtyController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantity used per unit sold'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MeasurementUnit>(
          initialValue: _unit,
          decoration: const InputDecoration(labelText: 'Unit of Measurement'),
          items: MeasurementUnit.values
              .map((u) => DropdownMenuItem(value: u, child: Text(u.displayLabel)))
              .toList(),
          onChanged: (v) => setState(() => _unit = v!),
        ),
        if (_unit == MeasurementUnit.custom) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customUnitController,
            decoration: const InputDecoration(labelText: 'Custom unit label (e.g. "scoop")'),
          ),
        ],
      ],
    );
  }
}
