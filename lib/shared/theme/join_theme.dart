import 'package:flutter/material.dart';

/// The green chrome the screen spec gives to onboarding and messaging.
///
/// The card pipeline and the admin panel keep the navy in `AppTheme`. These
/// are deliberately different: the joining and messaging screens borrow a
/// layout people already know from a consumer chat app, while the rest of the
/// product is an office tool and should look like one.
///
/// Two palettes in one app is usually a mistake. Here it is a signal about
/// which half of the product you are standing in, and it is confined to a
/// named set of screens rather than leaking into shared widgets.
abstract final class JoinTheme {
  /// Header and primary surfaces.
  static const Color header = Color(0xFF0F7A6C);

  /// Buttons, selection, the active state of anything tappable.
  static const Color accent = Color(0xFF14A085);

  /// A tint of [accent] for filled chips and callout backgrounds.
  static const Color accentSoft = Color(0xFFE6F4F1);

  /// The dark surface the scanner runs on, so the camera preview is the
  /// brightest thing on screen.
  static const Color scannerBackdrop = Color(0xFF1B2430);

  /// Waiting, not failing. Screen 18 is a normal state, and colouring it red
  /// would tell a teacher something is wrong when nothing is.
  static const Color waiting = Color(0xFFF1C453);

  static const Color waitingSoft = Color(0xFFFBF3DC);

  /// A button that matches the green chrome without restyling the whole app.
  static ButtonStyle filledButton() => FilledButton.styleFrom(
    backgroundColor: header,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
  );

  static ButtonStyle outlinedButton() => OutlinedButton.styleFrom(
    foregroundColor: header,
    minimumSize: const Size.fromHeight(52),
    side: const BorderSide(color: header, width: 1.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
  );
}
