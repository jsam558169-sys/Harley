import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The consistent list-card layout used across Ingredients & Stock,
/// Products, Stock Movement Log, Reports, and Low Stock Alerts.
///
/// Layout: a tinted rounded-square icon badge on the left, then a title row
/// (with an optional small badge and trailing action), an ID line, stat
/// pills, an optional extra widget (e.g. action buttons) and a muted footer.
/// Everything below the title is aligned with the title text, not the badge.
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
    final indent = _hasLeading ? 48.0 : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leadingWidget != null) ...[
                    leadingWidget!,
                    const SizedBox(width: 12),
                  ] else if (leadingIcon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(leadingIcon, color: accentColor, size: 19),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.brown,
                      ),
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brown.withValues(alpha: 0.75),
                        ),
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
                  child: Text(
                    idText!,
                    style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.5)),
                  ),
                ),
              ],
              if (pills.isNotEmpty) ...[
                const SizedBox(height: 10),
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
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: Text(
                    footerText!,
                    style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.55)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded status/stat badge — "Fresh: 20 kg", "Today: 5", etc.
/// A soft tint with a faint outline; no heavy borders.
class StatPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool muted;

  const StatPill({super.key, required this.label, this.color = AppColors.teal, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: muted ? 0.07 : 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: muted ? 0.2 : 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: muted ? AppColors.brown.withValues(alpha: 0.55) : AppColors.brown,
        ),
      ),
    );
  }
}
