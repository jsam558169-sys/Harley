import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Shows a confirmation dialog before a destructive action. Returns true
/// if the user confirmed, false/null otherwise.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return confirmAction(
    context,
    title: title,
    message: message,
    confirmLabel: 'Delete',
    confirmColor: AppColors.stopRed,
  );
}

/// Generic yes/no confirmation dialog with a customizable confirm button
/// label and color — for confirmations that aren't a delete (e.g. "this
/// will affect other data, continue?", or a logout confirmation).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  Color confirmColor = AppColors.rust,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelLabel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
