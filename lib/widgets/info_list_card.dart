import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The consistent list-card layout used across Ingredients & Stock,
/// Products, Stock Movement Log, Losses, Reports, and Low Stock Alerts —
/// so scanning down any of these screens feels like the same visual
/// language: a colored icon badge on the left (or a custom leading
/// widget, e.g. a rank number), a title row with an optional small pill
/// on the right, an ID line underneath when relevant, a row of stat
/// pills, an optional extra widget (e.g. action buttons), and a small
/// muted footer line for a date or extra detail.
class InfoListCard extends StatelessWidget {
  final IconData? leadingIcon;
  final Widget? leadingWidget; // overrides leadingIcon when set (e.g. a rank badge)
  final Color accentColor;
  final String title;
  final String? idText;
  final String? badgeText;
  final List<Widget> pills;
  final Widget? extra;
  final String? footerText;
  final Widget? trailingAction;
  final VoidCallback? onTap;

  const InfoListCard({
    super.key,
    this.leadingIcon,
    this.leadingWidget,
    this.accentColor = AppColors.rust,
    required this.title,
    this.idText,
    this.badgeText,
    this.pills = const [],
    this.extra,
    this.footerText,
    this.trailingAction,
    this.onTap,
  });

  bool get _hasLeading => leadingIcon != null || leadingWidget != null;

  @override
  Widget build(BuildContext context) {
    final indent = _hasLeading ? 28.0 : 0.0;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leadingWidget != null) ...[
                    leadingWidget!,
                    const SizedBox(width: 10),
                  ] else if (leadingIcon != null) ...[
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: accentColor.withValues(alpha: 0.15),
                      child: Icon(leadingIcon, color: accentColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brown),
                      ),
                    ),
                  ],
                  if (trailingAction != null) trailingAction!,
                ],
              ),
              if (idText != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: Text(idText!, style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.55))),
                ),
              ],
              if (pills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: Wrap(spacing: 8, runSpacing: 6, children: pills),
                ),
              ],
              if (extra != null) ...[
                const SizedBox(height: 10),
                Padding(padding: EdgeInsets.only(left: indent), child: extra!),
              ],
              if (footerText != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: Text(footerText!, style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.6))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded status/stat badge — "Fresh: 20 kg", "Today: 5",
/// "Used: 12", etc. Used inside InfoListCard's `pills` across every
/// screen that shows this kind of quick stat.
class StatPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool muted;

  const StatPill({super.key, required this.label, this.color = AppColors.teal, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: muted ? 0.08 : 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: muted ? 0.3 : 1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: muted ? AppColors.brown.withValues(alpha: 0.5) : AppColors.brown,
        ),
      ),
    );
  }
}
