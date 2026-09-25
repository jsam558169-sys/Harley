import 'package:flutter/material.dart';

/// Shared breakpoint logic so every screen agrees on what counts as
/// "tablet-wide" and how many columns to show at a given width.
const double tabletBreakpoint = 700;
const double wideTabletBreakpoint = 1100;

bool isTabletWidth(double width) => width >= tabletBreakpoint;

int gridColumnsForWidth(double width) {
  if (width >= wideTabletBreakpoint) return 3;
  if (width >= tabletBreakpoint) return 2;
  return 1;
}

/// Width for one card inside a Wrap-based responsive grid, given the
/// available width and desired column count. Using Wrap (rather than
/// GridView) here deliberately — several cards in this app have
/// variable height (pills, buttons, multi-line text), and GridView's
/// fixed-aspect-ratio cells either overflow or waste space with content
/// like that. Wrap lets each card keep its natural height while still
/// flowing into columns on wider screens.
double wrapCardWidth(double availableWidth, int columns, {double gap = 12}) {
  final totalGap = gap * (columns - 1);
  return (availableWidth - totalGap) / columns;
}
