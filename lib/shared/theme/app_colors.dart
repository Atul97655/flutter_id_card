import 'package:flutter/material.dart';

/// Every colour the app chrome uses.
///
/// Centralised on purpose. The previous theme derived almost everything from
/// one seed and let individual widgets reach for `colorScheme.primary`, which
/// meant a glass surface could not be tuned without moving every button with
/// it. These are named by role, not by hue, so a screen asks for
/// "the tint behind an approved badge" rather than for a particular green.
///
/// Deliberately NOT the card colours. A school's printed card carries its own
/// red/blue artwork configured per school; sharing constants would let a
/// school's branding repaint the operator's app.
abstract final class AppColors {
  // --- brand ---------------------------------------------------------

  /// The darkest blue in the header gradient. Text on this is white.
  static const Color navy = Color(0xFF16346E);

  /// Mid blue - the body of a header gradient and the primary action.
  static const Color royal = Color(0xFF2B5BD7);

  /// The lighter end of a blue gradient, and a resting icon tint.
  static const Color soft = Color(0xFF6E9BF0);

  /// Behind a tinted icon tile on a light surface.
  static const Color mist = Color(0xFFE6EDFB);

  /// The accent that gives the CTA its violet tail.
  static const Color violet = Color(0xFF7C4DDB);

  /// A lavender wash, used in gradients and the selected nav pill.
  static const Color lavender = Color(0xFFCBC3F2);

  // --- surfaces ------------------------------------------------------

  /// The page behind everything. Screens paint a gradient over it; this is
  /// what shows if one forgets to.
  static const Color canvas = Color(0xFFEFF3FB);

  /// A solid card on a light page - the dashboard's white cards.
  static const Color card = Color(0xFFFFFFFF);

  /// The fill of a frosted panel. Low alpha on purpose: the blur behind it
  /// is what makes it read as glass, not the colour.
  static const Color glassFill = Color(0x66FFFFFF);

  /// A slightly heavier fill, for glass that sits over a busy gradient and
  /// has to stay legible.
  static const Color glassFillStrong = Color(0x99FFFFFF);

  /// The hairline that gives a glass edge its lift. Without it a frosted
  /// panel dissolves into whatever is behind it.
  static const Color glassBorder = Color(0x59FFFFFF);

  /// The same edge on a light surface, where pure white would vanish.
  static const Color hairline = Color(0x1416346E);

  // --- text ----------------------------------------------------------

  /// Headings and anything that must be read at a glance.
  static const Color ink = Color(0xFF14213D);

  /// Body text.
  static const Color inkBody = Color(0xFF34406A);

  /// Supporting text, placeholders, timestamps.
  static const Color inkMuted = Color(0xFF7A85A8);

  /// On a navy or royal surface.
  static const Color onDark = Color(0xFFFFFFFF);

  /// Supporting text on a navy surface. Pure white at small sizes reads as
  /// shouting; this is the quieter second line.
  static const Color onDarkMuted = Color(0xCCFFFFFF);

  // --- status --------------------------------------------------------
  //
  // Each status is a pair: a saturated colour for the icon and label, and a
  // soft tint for the surface behind it. Never use the saturated one as a
  // background - at badge size it is loud enough to pull the eye off the
  // name beside it, which is the thing that actually matters.

  static const Color approved = Color(0xFF1B9E58);
  static const Color approvedTint = Color(0xFFDDF4E7);

  static const Color rejected = Color(0xFFD64550);
  static const Color rejectedTint = Color(0xFFFCE3E5);

  static const Color pending = Color(0xFFE08A1E);
  static const Color pendingTint = Color(0xFFFDF0DC);

  static const Color printed = Color(0xFF6D4BC4);
  static const Color printedTint = Color(0xFFEBE5FA);

  static const Color info = Color(0xFF2B7FD4);
  static const Color infoTint = Color(0xFFDFEDFB);

  // --- messaging -----------------------------------------------------
  //
  // The conversation keeps its green. That was a deliberate split before this
  // redesign and it survives it: chat borrows a layout people already know,
  // while the card pipeline is an office tool. The greens are softened here
  // to sit inside glass rather than on a flat bar.

  static const Color chatDeep = Color(0xFF0F7A6C);
  static const Color chatAccent = Color(0xFF14A085);

  /// An outgoing bubble.
  static const Color chatMine = Color(0xB3D9F0E6);

  /// An incoming bubble.
  static const Color chatTheirs = Color(0xCCFFFFFF);
}
