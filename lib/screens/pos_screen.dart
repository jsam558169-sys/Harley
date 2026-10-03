import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../models/ingredient.dart';
import '../services/product_service.dart';
import '../services/ingredient_service.dart';
import '../services/sales_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive.dart';

enum SortOption { nameAsc, nameDesc, priceAsc, priceDesc, mostAvailable }

extension on SortOption {
  String get label {
    switch (this) {
      case SortOption.nameAsc:
        return 'Name (A–Z)';
      case SortOption.nameDesc:
        return 'Name (Z–A)';
      case SortOption.priceAsc:
        return 'Price (Low–High)';
      case SortOption.priceDesc:
        return 'Price (High–Low)';
      case SortOption.mostAvailable:
        return 'Most Available';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.nameAsc:
      case SortOption.nameDesc:
        return Icons.sort_by_alpha;
      case SortOption.priceAsc:
      case SortOption.priceDesc:
        return Icons.attach_money;
      case SortOption.mostAvailable:
        return Icons.check_circle_outline;
    }
  }
}

/// How many of each product could be added to the cart right now, given
/// current FRESH stock minus whatever every OTHER cart line already
/// reserves from shared ingredients. This is what actually lets POS catch
/// "these two products both need eggs, and together you've run out" at
/// add-to-cart time instead of only discovering it when checkout fails.
///
/// A product's own existing cart quantity does NOT count against itself —
/// only what *other* products in the cart draw from the same ingredients.
/// So this answers "how many total of X could the cart hold right now",
/// which the UI then compares against the current cart quantity to decide
/// whether "+" should still be enabled.
Map<String, int> _computeServingsAccountingForCart(
  List<Product> allProducts,
  Map<String, Ingredient> ingredientsById,
  Map<String, int> cart,
) {
  final productsById = {for (final p in allProducts) p.id: p};

  // Total reserved per ingredient across every line currently in the cart.
  final totalReserved = <String, num>{};
  for (final entry in cart.entries) {
    final product = productsById[entry.key];
    if (product == null) continue;
    for (final item in product.recipeIngredients) {
      totalReserved.update(
        item.ingredientId,
        (v) => v + item.qtyPerUnit * entry.value,
        ifAbsent: () => item.qtyPerUnit * entry.value,
      );
    }
  }

  final result = <String, int>{};
  for (final product in allProducts) {
    if (product.recipeIngredients.isEmpty) {
      result[product.id] = 0;
      continue;
    }
    int? minServings;
    for (final item in product.recipeIngredients) {
      final ingredient = ingredientsById[item.ingredientId];
      if (ingredient == null || item.qtyPerUnit <= 0) {
        minServings = 0;
        break;
      }
      final ownCartQty = cart[product.id] ?? 0;
      final ownReservation = item.qtyPerUnit * ownCartQty;
      final reservedByOthers = (totalReserved[item.ingredientId] ?? 0) - ownReservation;
      final effectiveFresh = ingredient.freshQty - reservedByOthers;
      final possible = (effectiveFresh / item.qtyPerUnit).floor();
      if (minServings == null || possible < minServings) minServings = possible;
    }
    result[product.id] = (minServings ?? 0) < 0 ? 0 : (minServings ?? 0);
  }
  return result;
}

/// The actual point-of-sale screen: search/sort the menu, pick products and
/// quantities, then check out. Checkout asks for the amount tendered and
/// computes change before completing the sale. On completion, SalesService
/// deducts recipe ingredients, logs usage, and logs the stock-out movement
/// automatically.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _productService = ProductService();
  final _ingredientService = IngredientService();
  final _salesService = SalesService();
  final _searchController = TextEditingController();

  final Map<String, int> _cart = {}; // productId -> qty
  String _searchQuery = '';
  SortOption _sortOption = SortOption.nameAsc;
  List<Product> _latestProducts = []; // kept in sync with the stream for checkout math
  bool _processing = false;

  void _incrementCart(String productId, int maxServings) {
    setState(() {
      final current = _cart[productId] ?? 0;
      if (current >= maxServings) return; // can't add more than what's available
      _cart[productId] = current + 1;
    });
  }

  void _decrementCart(String productId) {
    setState(() {
      if (!_cart.containsKey(productId)) return;
      final newQty = _cart[productId]! - 1;
      if (newQty <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = newQty;
      }
    });
  }

  List<Product> _filterAndSort(List<Product> products, Map<String, int> servingsByProduct) {
    var result = products.where((p) {
      if (_searchQuery.trim().isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    switch (_sortOption) {
      case SortOption.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.nameDesc:
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.priceAsc:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceDesc:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.mostAvailable:
        result.sort((a, b) =>
            (servingsByProduct[b.id] ?? 0).compareTo(servingsByProduct[a.id] ?? 0));
        break;
    }
    return result;
  }

  double _computeTotal(List<Product> products) {
    double total = 0;
    for (final entry in _cart.entries) {
      final p = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => Product(id: '', name: '', price: 0, recipeIngredients: []),
      );
      total += p.price * entry.value;
    }
    return total;
  }

  Future<void> _onCompleteSalePressed() async {
    if (_cart.isEmpty) return;
    final total = _computeTotal(_latestProducts);

    final tendered = await showDialog<double>(
      context: context,
      builder: (_) => _TenderDialog(total: total),
    );
    if (tendered == null) return; // cashier cancelled

    await _checkout(total: total, tendered: tendered);
  }

  Future<void> _checkout({required double total, required double tendered}) async {
    setState(() => _processing = true);
    try {
      final uid = AuthService().currentFirebaseUser?.uid ?? 'unknown';
      final saleId = await _salesService.completeSale(
        cartItems: _cart,
        recordedByUid: uid,
        branch: 'Juan Luna', // TODO: let the cashier pick a branch
      );
      setState(() => _cart.clear());
      if (!mounted) return;
      await _showSuccessDialog(saleId: saleId, change: tendered - total);
    } on InsufficientStockException catch (e) {
      _showErrorSnackBar('Cannot complete sale: ${e.toString()}');
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.stopRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showSuccessDialog({required String saleId, required double change}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.teal,
              child: Icon(Icons.check, color: AppColors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Sale Completed',
              style: GoogleFonts.alfaSlabOne(fontSize: 22, color: AppColors.brown),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Text('Transaction ID', style: TextStyle(fontSize: 12, color: AppColors.brown)),
                  const SizedBox(height: 4),
                  SelectableText(
                    saleId,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brown,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Change Due', style: TextStyle(fontSize: 13, color: AppColors.brown.withValues(alpha: 0.7))),
            const SizedBox(height: 2),
            Text(
              '₱${change.toStringAsFixed(2)}',
              style: GoogleFonts.alfaSlabOne(fontSize: 32, color: AppColors.rust),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('New Sale'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Process Sale (POS)')),
      body: StreamBuilder<List<Product>>(
        stream: _productService.watchProducts(),
        builder: (context, productSnapshot) {
          if (!productSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final allProducts = productSnapshot.data!;
          _latestProducts = allProducts;

          return StreamBuilder<List<Ingredient>>(
            stream: _ingredientService.watchIngredients(),
            builder: (context, ingredientSnapshot) {
              if (!ingredientSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final ingredientsById = {
                for (final i in ingredientSnapshot.data!) i.id: i,
              };
              final servingsByProduct = _computeServingsAccountingForCart(allProducts, ingredientsById, _cart);

              final products = _filterAndSort(allProducts, servingsByProduct);
              final total = _computeTotal(allProducts);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final productArea = Column(
                    children: [
                      _buildSearchSortBar(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Sorted by: ${_sortOption.label}',
                            style: TextStyle(fontSize: 12, color: AppColors.brown.withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildProductGrid(products, allProducts, servingsByProduct),
                      ),
                    ],
                  );

                  // Tablet: product grid on the left, a fixed itemized cart
                  // panel pinned on the right, instead of stacking the
                  // total/checkout bar under a full-width product list.
                  if (isTabletWidth(constraints.maxWidth)) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: productArea),
                        Container(
                          width: 340,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            border: Border(left: BorderSide(color: AppColors.cardBorder, width: 1.5)),
                          ),
                          child: _buildCartPanel(allProducts, total, servingsByProduct),
                        ),
                      ],
                    );
                  }

                  // Phone: original stacked layout — product list, then a
                  // bottom bar with the total and checkout button.
                  return Column(
                    children: [
                      Expanded(child: productArea),
                      _buildCheckoutBar(total),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchSortBar() {
    return Padding(
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
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.swap_vert, color: AppColors.rust),
            tooltip: 'Sort products',
            initialValue: _sortOption,
            onSelected: (option) => setState(() => _sortOption = option),
            itemBuilder: (context) => SortOption.values
                .map((option) => PopupMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          Icon(option.icon, size: 18, color: AppColors.brown),
                          const SizedBox(width: 10),
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
    );
  }

  /// Product listing — a responsive width-aware grid (single column on
  /// phones, multiple columns on tablets) rather than a fixed ListView, so
  /// a wide screen isn't wasted on one narrow column of cards.
  Widget _buildProductGrid(
    List<Product> products,
    List<Product> allProducts,
    Map<String, int> servingsByProduct,
  ) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          allProducts.isEmpty
              ? 'No products yet — add some from Products / Recipes.'
              : 'No products match "$_searchQuery".',
          textAlign: TextAlign.center,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = gridColumnsForWidth(constraints.maxWidth);
        final cardWidth = wrapCardWidth(constraints.maxWidth, columns);
        return SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: products.map((p) {
              final qty = _cart[p.id] ?? 0;
              final servings = servingsByProduct[p.id] ?? 0;
              final isSoldOut = servings <= 0;
              final atMax = qty >= servings;

              return SizedBox(
                width: cardWidth,
                child: Opacity(
                  opacity: isSoldOut ? 0.55 : 1,
                  child: Card(
                    child: ListTile(
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        isSoldOut
                            ? '₱${p.price.toStringAsFixed(2)} • Sold Out'
                            : '₱${p.price.toStringAsFixed(2)} • $servings available',
                        style: isSoldOut
                            ? const TextStyle(color: AppColors.stopRed, fontWeight: FontWeight.w700)
                            : null,
                      ),
                      trailing: isSoldOut
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.stopRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.stopRed.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'Sold Out',
                                style: TextStyle(color: AppColors.stopRed, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: qty == 0 ? null : () => _decrementCart(p.id),
                                ),
                                SizedBox(
                                  width: 22,
                                  child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppColors.rust),
                                  onPressed: atMax ? null : () => _incrementCart(p.id, servings),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// Tablet-only: itemized cart list + totals + checkout, pinned to the
  /// right of the product grid instead of a bottom bar.
  Widget _buildCartPanel(List<Product> allProducts, double total, Map<String, int> servingsByProduct) {
    final cartEntries = _cart.entries.map((e) {
      final product = allProducts.firstWhere(
        (p) => p.id == e.key,
        orElse: () => Product(id: e.key, name: 'Unknown item', price: 0, recipeIngredients: []),
      );
      return MapEntry(product, e.value);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Your Order', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
          ),
        ),
        Expanded(
          child: cartEntries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Cart is empty. Tap "+" on a product to add it.', textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: cartEntries.length,
                  itemBuilder: (context, i) {
                    final product = cartEntries[i].key;
                    final qty = cartEntries[i].value;
                    final servings = servingsByProduct[product.id] ?? qty;
                    return ListTile(
                      dense: true,
                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text('₱${product.price.toStringAsFixed(2)} × $qty = ₱${(product.price * qty).toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () => _decrementCart(product.id),
                          ),
                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: AppColors.rust, size: 20),
                            onPressed: qty >= servings ? null : () => _incrementCart(product.id, servings),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _buildCheckoutBar(total),
      ],
    );
  }

  Widget _buildCheckoutBar(double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                '₱${total.toStringAsFixed(2)}',
                style: GoogleFonts.alfaSlabOne(fontSize: 24, color: AppColors.rust),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_processing || _cart.isEmpty) ? null : _onCompleteSalePressed,
              child: Text(_processing ? 'Processing...' : 'Complete Sale'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal that asks the cashier for the amount tendered, live-computes
/// change, and blocks confirming until the tendered amount covers the total.
class _TenderDialog extends StatefulWidget {
  final double total;
  const _TenderDialog({required this.total});

  @override
  State<_TenderDialog> createState() => _TenderDialogState();
}

class _TenderDialogState extends State<_TenderDialog> {
  final _controller = TextEditingController();
  double? _tendered;

  double get _change => (_tendered ?? 0) - widget.total;
  bool get _isSufficient => (_tendered ?? 0) >= widget.total;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Amount Tendered', style: GoogleFonts.alfaSlabOne(fontSize: 20, color: AppColors.brown)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Due'),
              Text('₱${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cash Tendered',
              prefixText: '₱ ',
            ),
            onChanged: (v) => setState(() => _tendered = double.tryParse(v)),
            onSubmitted: (_) {
              if (_isSufficient && _tendered != null) Navigator.of(context).pop(_tendered);
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Change'),
              Text(
                _tendered == null ? '—' : '₱${_change.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _tendered == null
                      ? AppColors.brown
                      : (_isSufficient ? AppColors.teal : AppColors.stopRed),
                ),
              ),
            ],
          ),
          if (_tendered != null && !_isSufficient)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Tendered amount is less than the total due.',
                style: TextStyle(color: AppColors.stopRed, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_tendered != null && _isSufficient)
              ? () => Navigator.of(context).pop(_tendered)
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
