import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/ingredient_service.dart';
import '../services/settings_service.dart';
import '../services/low_stock_event_service.dart';
import '../theme/app_colors.dart';
import '../widgets/info_list_card.dart';
import 'low_stock_history_screen.dart';

class _LowStockData {
  final List<Product> lowProducts;
  final Map<String, int> servingsByProduct;
  final DateTime checkedAt;
  _LowStockData(this.lowProducts, this.servingsByProduct, this.checkedAt);
}

/// Shows products that are at or below the low-stock serving threshold
/// (5 by default — Owner/Admin can change it). Each time this loads or is
/// refreshed it also compares against the last known state and logs an
/// entry to the low-stock history for any product that newly crossed
/// into low stock.
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
  final _settingsService = SettingsService();
  final _eventService = LowStockEventService();

  Future<_LowStockData>? _dataFuture;
  int? _loadedForThreshold;

  Future<_LowStockData> _loadData(int threshold) async {
    final allProducts = await _productService.getAllProducts();
    final servings = <String, int>{};
    for (final p in allProducts) {
      servings[p.id] = await _ingredientService.servingsAvailable(p);
    }
    final low = allProducts.where((p) => (servings[p.id] ?? 0) <= threshold).toList();

    // Log any product that has newly crossed into low stock since the
    // last time this ran. A logging failure shouldn't hide the alerts
    // themselves, so it's swallowed here.
    try {
      await _eventService.checkAndLogTransitions(
        allProducts: allProducts,
        servingsByProduct: servings,
        threshold: threshold,
      );
    } catch (_) {}

    return _LowStockData(low, servings, DateTime.now());
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
            const Text('Alert when a product\'s available servings fall at or below:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Servings'),
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
                  const SnackBar(content: Text('Enter a value between 0 and 999.'), behavior: SnackBarBehavior.floating),
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
                return const Center(child: Text('Couldn\'t load low stock data. Tap refresh to try again.'));
              }
              final data = snapshot.data!;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Threshold: $threshold serving(s) or fewer • Last checked ${_formatCheckedAt(data.checkedAt)}',
                            style: TextStyle(fontSize: 12, color: AppColors.brown.withValues(alpha: 0.7)),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: () => _refresh(threshold)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: data.lowProducts.isEmpty
                        ? const Center(child: Text('No low-stock items right now.'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: data.lowProducts.length,
                            itemBuilder: (context, i) {
                              final p = data.lowProducts[i];
                              final servings = data.servingsByProduct[p.id] ?? 0;
                              final soldOut = servings <= 0;
                              return InfoListCard(
                                leadingIcon: Icons.warning_amber,
                                accentColor: AppColors.stopRed,
                                title: p.name,
                                idText: 'ID: ${p.id}',
                                pills: [
                                  StatPill(
                                    label: soldOut ? 'Sold out' : 'Only $servings serving(s) left',
                                    color: AppColors.stopRed,
                                  ),
                                  StatPill(label: 'Threshold: $threshold', color: AppColors.brown, muted: true),
                                ],
                              );
                            },
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
