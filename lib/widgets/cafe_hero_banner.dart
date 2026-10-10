import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// The "marquee sign" banner at the top of the dashboards — engine-brown
/// rounded card, cream/gold slab-serif title. Now a self-contained card
/// (rounded on all corners) so it can sit inside page padding.
class CafeHeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const CafeHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.brown,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.alfaSlabOne(
                    fontSize: 24,
                    color: AppColors.gold,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
