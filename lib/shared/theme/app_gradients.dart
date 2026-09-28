import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';

/// The gradients the app is built from.
///
/// Named by where they are used rather than by their colours, so a screen
/// asks for `AppGradients.pageBlue` instead of picking two blues and hoping
/// they match the screen next door. That is the whole reason this file
/// exists - the reference designs only hold together because every surface
/// draws from the same small set.
abstract final class AppGradients {
  /// The header block on the dashboard: deep navy falling to royal blue.
  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.navy, Color(0xFF2A55B8)],
  );

  /// The page behind the card pipeline - pale blue into pale lavender.
  ///
  /// Very low contrast on purpose. It is a backdrop for glass, and anything
  /// stronger starts competing with the content sitting on top of it.
  static const LinearGradient pageBlue = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFDCE7F8), Color(0xFFEDEAF8)],
  );

  /// The page behind Profile, where the reference image used a photograph.
  ///
  /// A photo is not shippable - it is somebody's copyrighted image, it would
  /// add megabytes to the APK, and glass over arbitrary photography loses
  /// text contrast wherever the picture happens to be light. This reproduces
  /// the effect: a soft wash with enough variation to give the glass
  /// something to refract.
  static const LinearGradient pageCalm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFE4ECF8), Color(0xFFEFE9F6), Color(0xFFE8F0F4)],
    stops: <double>[0, 0.55, 1],
  );

  /// The conversation backdrop. Keeps the messaging green.
  static const LinearGradient pageChat = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFD9E8E2), Color(0xFFE7EFEA), Color(0xFFDDE8EE)],
    stops: <double>[0, 0.5, 1],
  );

  /// The primary call to action: blue running into violet.
  static const LinearGradient action = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFF3B7BEA), AppColors.violet],
  );

  /// The dark CTA card on the dashboard.
  static const LinearGradient actionDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF16346E), Color(0xFF2E63C8)],
  );

  /// The highlight laid over a glass surface, top-left to nothing.
  ///
  /// This is what makes a frosted panel look lit rather than merely
  /// transparent, and it is the cheapest part of the whole effect - one
  /// gradient, no blur.
  static const LinearGradient glassSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x40FFFFFF), Color(0x0DFFFFFF)],
  );

  /// A circular avatar's fill.
  static const LinearGradient avatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF5B7BE8), AppColors.violet],
  );

  /// A tint pair for a status surface, given the status's own colour.
  static LinearGradient statusTint(Color tint) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[tint, tint.withValues(alpha: 0.45)],
  );
}
