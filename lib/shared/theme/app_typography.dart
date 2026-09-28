import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';

/// The type scale.
///
/// On the platform font, not Inter. The brief recommends Inter, and it would
/// look slightly better - but the usual way to get it, `google_fonts`,
/// fetches the family over the network on first use. This app is
/// offline-first for schools with bad connectivity, so a teacher opening it
/// on their first morning would be the one person guaranteed to see the
/// fallback. Bundling the TTFs as assets is the correct fix and is a
/// deliberate decision to take, not something to slip in here.
///
/// Roboto, tuned, gets most of the way: the reference designs read as
/// premium because of the SIZES and WEIGHTS and the space around them, far
/// more than because of the letterforms.
///
/// Note what is not here: no `Arial`. That family is bundled for the printed
/// card, where metrics must be identical on every device, and it has an
/// outstanding licensing question. The screen UI has no such constraint and
/// must not inherit that problem.
abstract final class AppTypography {
  /// A screen title - "ID entity", "Profile".
  static const TextStyle display = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.15,
    color: AppColors.ink,
  );

  /// The line under a screen title.
  static const TextStyle displaySub = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.inkMuted,
  );

  /// A card's headline - a school name, a student's name.
  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
    color: AppColors.ink,
  );

  /// A section heading inside a panel.
  static const TextStyle section = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.inkBody,
  );

  /// A second line, a subtitle, a hint.
  static const TextStyle support = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.inkMuted,
  );

  /// The label above an input.
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  /// What the user types.
  static const TextStyle input = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  /// The grey text inside an empty input.
  static const TextStyle placeholder = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    color: AppColors.inkMuted,
  );

  /// A status pill.
  static const TextStyle badge = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// The number on a statistic tile. Tabular so a column of them does not
  /// jitter as the counts change.
  static const TextStyle stat = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    color: AppColors.ink,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The word under a statistic.
  static const TextStyle statLabel = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.inkMuted,
  );

  /// Text on a filled action.
  static const TextStyle button = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.onDark,
  );

  /// A timestamp beside a message.
  static const TextStyle timestamp = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.inkMuted,
  );

  /// The same scale, recoloured for a navy header.
  static TextStyle get displayOnDark =>
      display.copyWith(color: AppColors.onDark);
  static TextStyle get displaySubOnDark =>
      displaySub.copyWith(color: AppColors.onDarkMuted);
  static TextStyle get titleOnDark => title.copyWith(color: AppColors.onDark);
  static TextStyle get supportOnDark =>
      support.copyWith(color: AppColors.onDarkMuted);
}
