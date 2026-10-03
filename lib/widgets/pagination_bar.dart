import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const List<int> defaultPageSizeOptions = [10, 30, 50, 100];

/// A "Show: 10/30/50/100 per page" dropdown plus Previous/Next buttons and
/// a "Page X of Y" label — the same pagination control used on Stock
/// Movement Log and the Reports Product Sales list, so long lists don't
/// force endless scrolling.
class PaginationBar extends StatelessWidget {
  final int pageSize;
  final int currentPage; // 0-indexed
  final int totalItems;
  final ValueChanged<int> onPageSizeChanged;
  final ValueChanged<int> onPageChanged;
  final List<int> pageSizeOptions;

  /// Optional content (e.g. filter chips) shown at the start of this same
  /// row, left-aligned against the pagination controls on the right —
  /// so a filter row and the pagination row read as one aligned toolbar
  /// instead of two separately-indented rows.
  final Widget? leading;

  const PaginationBar({
    super.key,
    required this.pageSize,
    required this.currentPage,
    required this.totalItems,
    required this.onPageSizeChanged,
    required this.onPageChanged,
    this.pageSizeOptions = defaultPageSizeOptions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = totalItems == 0 ? 1 : (totalItems / pageSize).ceil();
    final page = currentPage.clamp(0, totalPages - 1);
    final startItem = totalItems == 0 ? 0 : page * pageSize + 1;
    final endItem = ((page + 1) * pageSize).clamp(0, totalItems);

    final pageSizeControl = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Show:', style: TextStyle(fontSize: 12, color: AppColors.brown.withValues(alpha: 0.7))),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: pageSize,
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brown),
          items: pageSizeOptions
              .map((n) => DropdownMenuItem(value: n, child: Text('$n per page')))
              .toList(),
          onChanged: (v) {
            if (v != null) onPageSizeChanged(v);
          },
        ),
      ],
    );

    final pageNavControl = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          totalItems == 0 ? 'No results' : '$startItem–$endItem of $totalItems',
          style: TextStyle(fontSize: 12, color: AppColors.brown.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous page',
          onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
          visualDensity: VisualDensity.compact,
        ),
        Text('${page + 1} / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next page',
          onPressed: page < totalPages - 1 ? () => onPageChanged(page + 1) : null,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          if (leading != null)
            Row(mainAxisSize: MainAxisSize.min, children: [leading!, const SizedBox(width: 16), pageSizeControl])
          else
            pageSizeControl,
          pageNavControl,
        ],
      ),
    );
  }
}

/// Slices [items] to the given page/pageSize, clamping the page to a valid
/// range so callers don't need to repeat that logic everywhere.
List<T> paginate<T>(List<T> items, int page, int pageSize) {
  if (items.isEmpty) return items;
  final totalPages = (items.length / pageSize).ceil();
  final clampedPage = page.clamp(0, totalPages - 1);
  final start = clampedPage * pageSize;
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}
