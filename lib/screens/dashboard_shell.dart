import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/sales_report.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cafe_hero_banner.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/responsive.dart';
import '../widgets/ticket_nav_card.dart';
import 'login_screen.dart';

/// One navigation entry on a dashboard. Same destinations as before —
/// this just adds a short description line under the label.
class DashboardMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;

  const DashboardMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

/// Shared layout for the Owner/Admin and Employee dashboards:
///   1. a welcome banner,
///   2. a "Today" stats row (revenue figures only when [showSalesFigures]),
///   3. a responsive grid of navigation tiles.
/// Content is capped at 1100px wide and centered on large screens.
class DashboardShell extends StatefulWidget {
  final AppUser user;
  final String roleLabel;
  final bool showSalesFigures;
  final List<DashboardMenuItem> items;

  const DashboardShell({
    super.key,
    required this.user,
    required this.roleLabel,
    required this.showSalesFigures,
    required this.items,
  });

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final _reportService = ReportService();
  late Future<SalesReport> _todayFuture;

  @override
  void initState() {
    super.initState();
    _todayFuture = _loadToday();
  }

  Future<SalesReport> _loadToday() =>
      _reportService.generateSalesReport(period: ReportPeriod.daily);

  void _refresh() => setState(() => _todayFuture = _loadToday());

  Future<void> _logout() async {
    final confirmed = await confirmAction(
      context,
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log Out',
    );
    if (!confirmed) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _open(DashboardMenuItem item) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: item.builder));
    // Coming back from POS etc. — refresh today's numbers.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final name = user.displayName.isNotEmpty ? user.displayName : user.email;
    final today = DateFormat('EEEE, MMM d, y').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CafeHeroBanner(
                    title: name,
                    subtitle: 'Welcome back  •  $today',
                    trailing: _RolePill(label: widget.roleLabel),
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeading(title: 'Today'),
                  const SizedBox(height: 10),
                  _buildStats(),
                  const SizedBox(height: 26),
                  const _SectionHeading(title: 'Quick access'),
                  const SizedBox(height: 10),
                  _buildNavGrid(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return FutureBuilder<SalesReport>(
      future: _todayFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final report = snapshot.data;
        String value(String Function(SalesReport r) f) {
          if (loading) return '…';
          if (report == null) return '—';
          return f(report);
        }

        final money = NumberFormat('#,##0.00');
        final tiles = <_StatTile>[
          if (widget.showSalesFigures)
            _StatTile(
              label: "Today's sales",
              value: value((r) => '₱${money.format(r.totalSales)}'),
              icon: Icons.payments_outlined,
              color: AppColors.rust,
            ),
          if (widget.showSalesFigures)
            _StatTile(
              label: 'Transactions',
              value: value((r) => '${r.totalTransactions}'),
              icon: Icons.receipt_long_outlined,
              color: AppColors.teal,
            ),
          _StatTile(
            label: 'Items sold',
            value: value((r) => '${r.totalItemsSold}'),
            icon: Icons.shopping_bag_outlined,
            color: AppColors.gold,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = isTabletWidth(constraints.maxWidth) ? 3 : 2;
            final cardWidth = wrapCardWidth(constraints.maxWidth, columns, gap: 12);
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tiles.map((t) => SizedBox(width: cardWidth, child: t)).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildNavGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns = w >= wideTabletBreakpoint - 32 ? 4 : (w >= tabletBreakpoint - 32 ? 3 : 2);
        final cardWidth = wrapCardWidth(w, columns, gap: 12);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.items
              .map((item) => SizedBox(
                    width: cardWidth,
                    height: 140,
                    child: TicketNavCard(
                      icon: item.icon,
                      label: item.title,
                      subtitle: item.subtitle,
                      accent: AppColors.rust,
                      onTap: () => _open(item),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.brown),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  const _RolePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gold),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brown,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
