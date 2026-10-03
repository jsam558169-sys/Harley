import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A bordered, padded container used to visually group a section of a
/// screen (a title plus its content) — gives screens like Reports actual
/// visual structure instead of everything floating in one flat column.
class SectionPanel extends StatelessWidget {
  final Widget child;

  const SectionPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}
