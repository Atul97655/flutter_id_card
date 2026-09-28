import 'package:flutter/material.dart';

/// Shadows, as a small fixed set.
///
/// Glass only reads as glass if it appears to float, and a shadow is what
/// does that - but the brief warns against excessive shadows, and it is
/// right: a page where everything casts the same heavy drop reads as noise
/// rather than depth. So there are four, ordered by how far off the page the
/// surface is meant to sit, and nothing invents its own.
///
/// All of them are tinted with the app's navy rather than black. A pure
/// black shadow under a blue-tinted glass surface looks like dirt.
abstract final class AppShadows {
  static const Color _tint = Color(0xFF16346E);

  /// A row inside a panel, or a resting chip. Barely there.
  static List<BoxShadow> get subtle => <BoxShadow>[
    BoxShadow(
      color: _tint.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  /// A card on the page. The default.
  static List<BoxShadow> get card => <BoxShadow>[
    BoxShadow(
      color: _tint.withValues(alpha: 0.08),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
  ];

  /// A primary action, or anything meant to be the focal point.
  static List<BoxShadow> get lifted => <BoxShadow>[
    BoxShadow(
      color: _tint.withValues(alpha: 0.16),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];

  /// The floating navigation bar and bottom sheets, which sit above
  /// everything and need to look like it.
  static List<BoxShadow> get floating => <BoxShadow>[
    BoxShadow(
      color: _tint.withValues(alpha: 0.14),
      blurRadius: 28,
      offset: const Offset(0, -2),
    ),
  ];

  /// A coloured glow under a gradient button, taking the button's own hue so
  /// the light looks like it came from the button rather than from nowhere.
  static List<BoxShadow> glow(Color color) => <BoxShadow>[
    BoxShadow(
      color: color.withValues(alpha: 0.34),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}
