import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';
import '../services/ingredient_service.dart';
import '../services/collections.dart';

/// Shows products that are at or below the low-stock serving threshold
/// (system objective: notify when only 5 or fewer servings remain).
class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  final _inventoryService = InventoryService();
  final _ingredientService = IngredientService();
  late Future<List<Product>> _lowStockFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _lowStockFuture = _inventoryService.getLowStockProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Alerts'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
      ),
      body: FutureBuilder<List<Product>>(
        future: _lowStockFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Center(child: Text('No low-stock items right now.'));
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, i) {
              final p = products[i];
              return FutureBuilder<int>(
                future: _ingredientService.servingsAvailable(p),
                builder: (context, servingsSnap) {
                  final servings = servingsSnap.data;
                  return ListTile(
                    leading: const Icon(Icons.warning_amber, color: Colors.orange),
                    title: Text(p.name),
                    subtitle: Text(servings == null
                        ? 'Calculating...'
                        : 'Only $servings serving(s) left (threshold: $lowStockServingThreshold)'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
