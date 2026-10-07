import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ticket_nav_card.dart';
import '../widgets/responsive.dart';
import '../widgets/confirm_dialog.dart';
import 'login_screen.dart';
import 'products_screen.dart';
import 'ingredients_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';
import 'low_stock_screen.dart';
import 'inventory_movements_screen.dart';

/// Owner/Admin dashboard: every operational screen an Employee has, plus
/// menu/recipe management and full Reports (which now also includes Losses
/// as one of its report views). User accounts (Owner/Employee) are managed
/// directly in Firestore, so
/// there's no in-app "register user" flow — see the README for how to add
/// one via the Firebase console.
///
/// Laid out as a responsive grid of ticket-style nav cards rather than a
/// plain vertical list — on a tablet, a single-column menu leaves most of
/// the screen empty.
class AdminDashboard extends StatelessWidget {
  final AppUser user;
  const AdminDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      _MenuItem('Process Sale (POS)', Icons.point_of_sale, (ctx) => const PosScreen()),
      _MenuItem('Products / Recipes', Icons.restaurant_menu, (ctx) => const ProductsScreen()),
      _MenuItem('Ingredients & Stock', Icons.inventory_2, (ctx) => const IngredientsScreen(canManageCatalog: true)),
      _MenuItem('Stock Movement Log', Icons.swap_vert, (ctx) => const InventoryMovementsScreen()),
      _MenuItem('Low Stock Alerts', Icons.warning_amber, (ctx) => const LowStockScreen(canEditThreshold: true)),
      _MenuItem('Reports', Icons.bar_chart, (ctx) => const ReportsScreen(showSalesFigures: true)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Owner/Admin - ${user.displayName.isNotEmpty ? user.displayName : user.email}'),
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
