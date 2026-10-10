import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/finished_product.dart';
import '../models/ingredient.dart';
import '../models/product.dart';
import '../services/finished_product_service.dart';
import '../services/ingredient_service.dart';
import '../services/low_stock_event_service.dart';
import '../services/product_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/info_list_card.dart';
import 'low_stock_history_screen.dart';

/// One recipe line of a product, with how many servings that ingredient
/// alone could still support.
class _RecipeLine {
  final RecipeItem item;
  final Ingredient? ingredient; // null if deleted from the catalog
  final int servings;
  _RecipeLine(this.item, this.ingredient, this.servings);

  String get name => ingredient?.name ?? item.ingredientName;
  bool isLow(int threshold) => servings <= threshold;
}

class _ProductStatus {
  final Product product;
  final int servings;
  final List<_RecipeLine> lines; // sorted: tightest ingredient first
  _ProductStatus(this.product, this.servings, this.lines);

  List<_RecipeLine> lowLines(int threshold) =>
      lines.where((l) => l.isLow(threshold)).toList();
}

class _AffectedProduct {
  final Product product;
  final int servings; // servings of that product this ingredient supports
  _AffectedProduct(this.product, this.servings);
}

class _IngredientAlert {
  final Ingredient ingredient;
  final List<_AffectedProduct> affected;
  _IngredientAlert(this.ingredient, this.affected);

  int get tightest => affected.map((a) => a.servings).reduce((a, b) => a < b ? a : b);
}

class _LowStockData {
  final List<_ProductStatus> products; // only the low ones
  final List<_IngredientAlert> ingredients;
  final List<FinishedProduct> finished; // only the low ones
  final DateTime checkedAt;
  _LowStockData(this.products, this.ingredients, this.finished, this.checkedAt);

  int get total => products.length + ingredients.length + finished.length;
}

enum _KindFilter { all, products, ingredients, finished }

/// Low stock alerts for three kinds of items, each labelled:
///  - Product: a menu item whose available servings are at/below the
///    threshold. Tap it to see which ingredient(s) are running low.
///  - Ingredient: an ingredient that is the reason a product is low.
///  - Finished Product: a ready-made item (e.g. bottled drinks) whose
///    quantity on hand is at/below the threshold.
/// Each load also logs newly-low products to the low-stock history.
class LowStockScreen extends StatefulWidget {
  /// Whether this user can edit the low-stock threshold. Owner/Admin only.
  final bool canEditThreshold;

  const LowStockScreen({super.key, this.canEditThreshold = false});

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  final _productService = ProductService();
  final _ingredientService = IngredientService();
  final _finishedProductService = FinishedProductService();
  final _settingsService = SettingsService();
  final _eventService = LowStockEventService();

  Future<_LowStockData>? _dataFuture;
  int? _loadedForThreshold;
  _KindFilter _filter = _KindFilter.all;

  Future<_LowStockData> _loadData(int threshold) async {
    final allProducts = await _productService.getAllProducts();
    final allIngredients = await _ingredientService.getAllIngredients();
    final allFinished = await _finishedProductService.getAllFinishedProducts();
    final ingredientsById = {for (final i in allIngredients) i.id: i};

    final servingsByProduct = <String, int>{};
    final lowProducts = <_ProductStatus>[];
    final affectedByIngredient = <String, List<_AffectedProduct>>{};

    for (final p in allProducts) {
      final lines = <_RecipeLine>[];
      int? minServings;
      for (final item in p.recipeIngredients) {
        final ing = ingredientsById[item.ingredientId];
        var possible = (ing == null || item.qtyPerUnit <= 0)
            ? 0
            : (ing.freshQty / item.qtyPerUnit).floor();
        if (possible < 0) possible = 0;
        lines.add(_RecipeLine(item, ing, possible));
        if (minServings == null || possible < minServings) minServings = possible;
      }
      // Same rule the POS uses: no recipe means nothing can be served.
      final servings = p.recipeIngredients.isEmpty ? 0 : (minServings ?? 0);
      servingsByProduct[p.id] = servings;
      lines.sort((a, b) => a.servings.compareTo(b.servings));

      if (servings <= threshold) {
        final status = _ProductStatus(p, servings, lines);
        lowProducts.add(status);
        for (final line in status.lowLines(threshold)) {
          final ing = line.ingredient;
          if (ing == null) continue;
          affectedByIngredient
              .putIfAbsent(ing.id, () => [])
              .add(_AffectedProduct(p, line.servings));
        }
      }
    }

    lowProducts.sort((a, b) {
      final c = a.servings.compareTo(b.servings);
      return c != 0 ? c : a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
    });

    final ingredientAlerts = <_IngredientAlert>[
      for (final entry in affectedByIngredient.entries)
        if (ingredientsById[entry.key] != null)
          _IngredientAlert(ingredientsById[entry.key]!, entry.value),
    ]..sort((a, b) => a.tightest.compareTo(b.tightest));

    final lowFinished = allFinished.where((f) => f.qty <= threshold).toList()
      ..sort((a, b) => a.qty.compareTo(b.qty));

    // Log any product that has newly crossed into low stock since the
    // last time this ran. A logging failure shouldn't hide the alerts
    // themselves, so it's swallowed here.
    try {
      await _eventService.checkAndLogTransitions(
        allProducts: allProducts,
        servingsByProduct: servingsByProduct,
        threshold: threshold,
      );
    } catch (_) {}

    return _LowStockData(lowProducts, ingredientAlerts, lowFinished, DateTime.now());
  }

  void _refresh(int threshold) {
    setState(() {
      _dataFuture = _loadData(threshold);
      _loadedForThreshold = threshold;
    });
  }

  Future<void> _editThreshold(int current) async {
    final controller = TextEditingController(text: current.toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Low Stock Threshold', style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alert when a product\'s available servings (or a finished product\'s quantity) fall at or below:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Servings / quantity'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 999) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a value between 0 and 999.')),
                );
                return;
              }
              await _settingsService.setLowStockThreshold(value);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatCheckedAt(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  // ---------------------------------------------------------------- dialogs

  Future<void> _showDetailsDialog({
    required String title,
    required String badge,
    required List<Widget> children,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brown.withValues(alpha: 0.75)),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.brown.withValues(alpha: 0.75))),
      );

  Widget _detailRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String pill,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.brown)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.brown.withValues(alpha: 0.65))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatPill(label: pill, color: color),
        ],
      ),
    );
  }

  String _servingsLabel(int n) => n <= 0 ? 'Out' : '$n left';

  void _showProductDetails(_ProductStatus s, int threshold) {
    final low = s.lowLines(threshold);
    final headline = s.product.recipeIngredients.isEmpty
        ? 'This product has no recipe yet, so no servings can be made. Add ingredients in Products / Recipes.'
        : '${s.servings <= 0 ? "Sold out" : "${s.servings} serving(s) left"} '
            '(alert at ${threshold} or fewer). The ingredients marked red are the ones running low.';

    _showDetailsDialog(
      title: s.product.name,
      badge: 'Product',
      children: [
        _note(headline),
        for (final line in s.lines)
          _detailRow(
            icon: line.isLow(threshold) ? Icons.warning_amber : Icons.check_circle_outline,
            color: line.isLow(threshold) ? AppColors.stopRed : AppColors.teal,
            title: line.name,
            subtitle: line.ingredient == null
                ? 'Deleted from the ingredient catalog'
                : 'On hand: ${line.ingredient!.freshQty} ${line.ingredient!.unit} • '
                    'needs ${line.item.qtyPerUnit} ${line.item.unit} per serving',
            pill: line.isLow(threshold) ? _servingsLabel(line.servings) : '${line.servings} servings',
          ),
        if (low.isEmpty && s.product.recipeIngredients.isNotEmpty)
          _note('No single ingredient is flagged.'),
      ],
    );
  }

  void _showIngredientDetails(_IngredientAlert a, int threshold) {
    final ing = a.ingredient;
    _showDetailsDialog(
      title: ing.name,
      badge: 'Ingredient',
      children: [
        _note(
          'Fresh on hand: ${ing.freshQty} ${ing.unit}'
          '${ing.expiredQty > 0 ? " • Expired: ${ing.expiredQty} ${ing.unit}" : ""}.\n'
          'This ingredient is limiting the products below.',
        ),
        for (final ap in a.affected)
          _detailRow(
            icon: Icons.restaurant_menu,
            color: AppColors.stopRed,
            title: ap.product.name,
            subtitle: 'Enough ${ing.name} for ${ap.servings} serving(s)',
            pill: _servingsLabel(ap.servings),
          ),
      ],
    );
  }

  void _showFinishedDetails(FinishedProduct f, int threshold) {
    _showDetailsDialog(
      title: f.name,
      badge: 'Finished Product',
      children: [
        _note(
          f.qty <= 0
              ? 'Out of stock. Alert is at $threshold or fewer.'
              : '${f.qty} left on hand. Alert is at $threshold or fewer.',
        ),
        _note('Finished products are stocked as ready-made items rather than made from a recipe.'),
      ],
    );
  }

  // ------------------------------------------------------------------ cards

  Widget _chevron() => Icon(Icons.chevron_right, color: AppColors.brown.withValues(alpha: 0.45));

  Widget _productCard(_ProductStatus s, int threshold) {
    final soldOut = s.servings <= 0;
    final low = s.lowLines(threshold);
    final names = low.map((l) => l.name).toList();
    final lowText = names.length <= 2 ? names.join(', ') : '${names.take(2).join(', ')} +${names.length - 2}';

    return InfoListCard(
      leadingIcon: Icons.restaurant_menu,
      accentColor: AppColors.rust,
      title: s.product.name,
      idText: 'ID: ${s.product.id}',
      badgeText: 'Product',
      trailingAction: _chevron(),
      onTap: () => _showProductDetails(s, threshold),
      pills: [
        StatPill(
          label: soldOut ? 'Sold out' : 'Only ${s.servings} serving(s) left',
          color: AppColors.stopRed,
        ),
        if (s.product.recipeIngredients.isEmpty)
          const StatPill(label: 'No recipe', color: AppColors.brown, muted: true)
        else if (names.isNotEmpty)
          StatPill(label: 'Low: $lowText', color: AppColors.gold),
      ],
      footerText: 'Tap to see which ingredients are running low',
    );
  }

  Widget _ingredientCard(_IngredientAlert a, int threshold) {
    final ing = a.ingredient;
    return InfoListCard(
      leadingIcon: Icons.kitchen,
      accentColor: AppColors.teal,
      title: ing.name,
      idText: 'ID: ${ing.id}',
      badgeText: 'Ingredient',
      trailingAction: _chevron(),
      onTap: () => _showIngredientDetails(a, threshold),
      pills: [
        StatPill(label: 'Fresh: ${ing.freshQty} ${ing.unit}', color: AppColors.stopRed),
        StatPill(label: 'Limits ${a.affected.length} product(s)', color: AppColors.brown, muted: true),
      ],
      footerText: 'Tap to see which products it affects',
    );
  }

  Widget _finishedCard(FinishedProduct f, int threshold) {
    return InfoListCard(
      leadingIcon: Icons.local_drink_outlined,
      accentColor: AppColors.gold,
      title: f.name,
      idText: 'ID: ${f.id}',
      badgeText: 'Finished Product',
      trailingAction: _chevron(),
      onTap: () => _showFinishedDetails(f, threshold),
      pills: [
        StatPill(
          label: f.qty <= 0 ? 'Out of stock' : 'Only ${f.qty} left',
          color: AppColors.stopRed,
        ),
        StatPill(label: 'Threshold: $threshold', color: AppColors.brown, muted: true),
      ],
    );
  }

  Widget _filterChip(String label, _KindFilter value, int count) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.rust.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? AppColors.rust : AppColors.brown,
      ),
      side: BorderSide(color: selected ? AppColors.rust : AppColors.cardBorder),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _settingsService.watchLowStockThreshold(),
      builder: (context, thresholdSnap) {
        // Wait for the real saved threshold before loading anything — if we
        // loaded with the default first, we could log low-stock events
        // against a threshold that isn't actually the one in effect.
        if (!thresholdSnap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Low Stock Alerts')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final threshold = thresholdSnap.data!;

        if (_dataFuture == null || _loadedForThreshold != threshold) {
          _dataFuture = _loadData(threshold);
          _loadedForThreshold = threshold;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Low Stock Alerts'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Low stock history',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LowStockHistoryScreen()),
                ),
              ),
              if (widget.canEditThreshold)
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Edit threshold',
                  onPressed: () => _editThreshold(threshold),
                ),
            ],
          ),
          body: FutureBuilder<_LowStockData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Couldn\'t load low stock data.'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: () => _refresh(threshold), child: const Text('Try again')),
                    ],
                  ),
                );
              }
              final data = snapshot.data!;

              final cards = <Widget>[
                if (_filter == _KindFilter.all || _filter == _KindFilter.products)
                  for (final s in data.products) _productCard(s, threshold),
                if (_filter == _KindFilter.all || _filter == _KindFilter.ingredients)
                  for (final a in data.ingredients) _ingredientCard(a, threshold),
                if (_filter == _KindFilter.all || _filter == _KindFilter.finished)
                  for (final f in data.finished) _finishedCard(f, threshold),
              ];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alert at $threshold or fewer • Last checked ${_formatCheckedAt(data.checkedAt)}',
                            style: TextStyle(fontSize: 12, color: AppColors.brown.withValues(alpha: 0.7)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                          onPressed: () => _refresh(threshold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _filterChip('All', _KindFilter.all, data.total),
                          _filterChip('Products', _KindFilter.products, data.products.length),
                          _filterChip('Ingredients', _KindFilter.ingredients, data.ingredients.length),
                          _filterChip('Finished', _KindFilter.finished, data.finished.length),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: cards.isEmpty
                        ? Center(
                            child: Text(
                              data.total == 0
                                  ? 'No low-stock items right now.'
                                  : 'Nothing low in this category.',
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.only(top: 4, bottom: 16),
                            children: cards,
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
