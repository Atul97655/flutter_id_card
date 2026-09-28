import 'package:flutter/material.dart';

/// Corner radii, spacing and elevation, in one place.
///
/// The reference designs read as one system largely because the radii agree
/// with each other. Random corner radii are called out explicitly in the
/// brief as something to avoid, and they are the easiest thing to get wrong
/// once twenty screens are each picking their own.
abstract final class AppRadius {
  /// A status pill, a small chip.
  static const double pill = 999;

  /// A tinted icon tile.
  static const double tile = 14;

  /// An input row, a list row.
  static const double field = 16;

  /// A card sitting on the page.
  static const double card = 20;

  /// A large frosted panel containing other things.
  static const double panel = 26;

  /// A bottom sheet or the floating navigation bar.
  static const double sheet = 28;

  static BorderRadius get tileR => BorderRadius.circular(tile);
  static BorderRadius get fieldR => BorderRadius.circular(field);
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get panelR => BorderRadius.circular(panel);
  static BorderRadius get sheetR => BorderRadius.circular(sheet);
}

/// The spacing scale. Multiples of 4, with names for the ones in constant use.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  /// The page margin. Everything on a screen lines up on this.
  static const double gutter = 18;

  /// Minimum touch target.
  ///
  /// Kept from the previous theme and worth keeping: operators use this app
  /// for hours on cheap Android tablets, often standing. Small targets cost
  /// real throughput, and glass surfaces make a too-small target harder to
  /// find rather than easier.
  static const double minTap = 52;

  /// Clearance above the floating navigation bar, so the last row of a list
  /// is not sitting underneath it.
  static const double navClearance = 96;
}
