import 'package:flutter/material.dart';
import '../models/app_user.dart';
import 'dashboard_shell.dart';
import 'ingredients_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';
import 'low_stock_screen.dart';
import 'inventory_movements_screen.dart';

/// Employee dashboard: employees can process sales, record stock-in/out,
/// and view ingredient usage — but don't manage the product/recipe catalog
/// or see revenue figures (Owner/Admin territory). The "Today" stats row
/// therefore shows items sold only.
///
/// Navigation is unchanged; layout lives in [DashboardShell].
class EmployeeDashboard extends StatelessWidget {
  final AppUser user;
  const EmployeeDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      user: user,
      roleLabel: 'Employee',
      showSalesFigures: false,
      items: [
        DashboardMenuItem(
          title: 'Process Sale (POS)',
          subtitle: 'Ring up customer orders',
          icon: Icons.point_of_sale,
          builder: (ctx) => const PosScreen(),
        ),
        DashboardMenuItem(
          title: 'Ingredients & Stock',
          subtitle: 'Stock in, out and expiry',
          icon: Icons.inventory_2,
          builder: (ctx) => const IngredientsScreen(canManageCatalog: false),
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
          builder: (ctx) => const LowStockScreen(),
        ),
        DashboardMenuItem(
          title: 'Ingredient Usage Report',
          subtitle: 'What has been used',
          icon: Icons.bar_chart,
          builder: (ctx) => const ReportsScreen(showSalesFigures: false),
        ),
      ],
    );
  }
}
