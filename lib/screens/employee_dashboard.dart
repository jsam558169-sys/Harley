import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ticket_nav_card.dart';
import '../widgets/responsive.dart';
import '../widgets/confirm_dialog.dart';
import 'login_screen.dart';
import 'ingredients_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';
import 'low_stock_screen.dart';
import 'inventory_movements_screen.dart';

/// Employee dashboard: per the feasibility study, employees can process
/// sales, record stock-in/stock-out, and access ingredient usage reports —
/// but don't manage the product/recipe catalog or see full sales-figure
/// reports (that's Owner/Admin territory). Same responsive nav-card grid
/// as the Admin dashboard.
class EmployeeDashboard extends StatelessWidget {
  final AppUser user;
  const EmployeeDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      _MenuItem('Process Sale (POS)', Icons.point_of_sale, (ctx) => const PosScreen()),
      _MenuItem('Ingredients & Stock', Icons.inventory_2, (ctx) => const IngredientsScreen(canManageCatalog: false)),
      _MenuItem('Stock Movement Log', Icons.swap_vert, (ctx) => const InventoryMovementsScreen()),
      _MenuItem('Low Stock Alerts', Icons.warning_amber, (ctx) => const LowStockScreen()),
      _MenuItem('Ingredient Usage Report', Icons.bar_chart, (ctx) => const ReportsScreen(showSalesFigures: false)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Employee - ${user.displayName.isNotEmpty ? user.displayName : user.email}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await confirmAction(
                context,
                title: 'Log Out',
                message: 'Are you sure you want to log out?',
                confirmLabel: 'Log Out',
              );
              if (!confirmed) return;
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = gridColumnsForWidth(constraints.maxWidth);
          final cardWidth = wrapCardWidth(constraints.maxWidth - 32, columns, gap: 12);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map((item) => SizedBox(
                        width: cardWidth,
                        height: 120,
                        child: TicketNavCard(
                          icon: item.icon,
                          label: item.title,
                          accent: AppColors.rust,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: item.builder),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final WidgetBuilder builder;
  _MenuItem(this.title, this.icon, this.builder);
}
