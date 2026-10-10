import 'package:flutter/material.dart';
import '../models/app_user.dart';
import 'dashboard_shell.dart';
import 'products_screen.dart';
import 'ingredients_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';
import 'low_stock_screen.dart';
import 'inventory_movements_screen.dart';

/// Owner/Admin dashboard: every operational screen an Employee has, plus
/// menu/recipe management and full Reports (which includes Losses).
/// User accounts are managed directly in Firestore — see the README.
///
/// Navigation is unchanged; layout lives in [DashboardShell].
class AdminDashboard extends StatelessWidget {
  final AppUser user;
  const AdminDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      user: user,
      roleLabel: 'Owner / Admin',
      showSalesFigures: true,
      items: [
        DashboardMenuItem(
          title: 'Process Sale (POS)',
          subtitle: 'Ring up customer orders',
          icon: Icons.point_of_sale,
          builder: (ctx) => const PosScreen(),
        ),
        DashboardMenuItem(
          title: 'Products / Recipes',
          subtitle: 'Menu items and ingredients',
          icon: Icons.restaurant_menu,
          builder: (ctx) => const ProductsScreen(),
        ),
        DashboardMenuItem(
          title: 'Ingredients & Stock',
          subtitle: 'Stock in, out and expiry',
          icon: Icons.inventory_2,
          builder: (ctx) => const IngredientsScreen(canManageCatalog: true),
        ),
        DashboardMenuItem(
          title: 'Stock Movement Log',
          subtitle: 'Full audit trail',
          icon: Icons.swap_vert,
          builder: (ctx) => const InventoryMovementsScreen(),
        ),
        DashboardMenuItem(
          title: 'Low Stock Alerts',
          subtitle: 'Items running out',
          icon: Icons.warning_amber,
          builder: (ctx) => const LowStockScreen(canEditThreshold: true),
        ),
        DashboardMenuItem(
          title: 'Reports',
          subtitle: 'Sales, profit and usage',
          icon: Icons.bar_chart,
          builder: (ctx) => const ReportsScreen(showSalesFigures: true),
        ),
      ],
    );
  }
}
