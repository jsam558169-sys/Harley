import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// A bordered, padded container used to group a section of a screen.
/// Existing usages (just a [child]) keep working; [title] and [trailing]
/// are optional extras for a consistent header row.
class SectionPanel extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;

  const SectionPanel({super.key, required this.child, this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
    );
  }
}
