import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';

/// Loads card layout templates.
///
/// Two templates ship in the app bundle as the working defaults. A school can
/// later be pointed at a custom template stored in Firestore; the lookup order
/// is custom-then-bundled, and an unknown id falls back to the bundled default
/// for the card's orientation rather than failing the render.
class TemplateRepository {
  TemplateRepository();

  static const String defaultVerticalId = 'default_vertical';
  static const String defaultHorizontalId = 'default_horizontal';

  /// Sacred Heart Convent style - bold bands and a DIV badge, all driven by the
  /// division colour. Pick this when a school colour-codes its divisions.
  static const String divBadgeVerticalId = 'div_badge_vertical';

  /// St John Samaritan / Tapasya style - coloured ground, inset white body,
  /// photo left and fields right.
  static const String sidePanelHorizontalId = 'side_panel_horizontal';

  /// Pratibha Vikas style - coloured frame, centred photo and name, signature
  /// line at the foot.
  static const String framedVerticalId = 'framed_vertical';

  static const Map<String, String> _bundledAssets = <String, String>{
    defaultVerticalId: 'assets/templates/default_vertical.json',
    defaultHorizontalId: 'assets/templates/default_horizontal.json',
    divBadgeVerticalId: 'assets/templates/div_badge_vertical.json',
    sidePanelHorizontalId: 'assets/templates/side_panel_horizontal.json',
    framedVerticalId: 'assets/templates/framed_vertical.json',
  };

  final Map<String, CardTemplate> _cache = <String, CardTemplate>{};

  /// Custom templates pushed down from Firestore, keyed by id. Populated by
  /// the sync service; empty until then.
  final Map<String, Map<String, Object?>> _remoteJson = <String, Map<String, Object?>>{};

  List<String> get bundledIds => _bundledAssets.keys.toList();

  void registerRemoteTemplate(String id, Map<String, Object?> json) {
    _remoteJson[id] = json;
    _cache.remove(id);
  }

  /// Resolves a template for a school.
  ///
  /// [cardSize] decides the fallback: asking for a missing template on an
  /// 86x54 card should not hand back a portrait layout.
  Future<CardTemplate> resolve({
    required String templateId,
    required CardSize cardSize,
  }) async {
    final CardTemplate? found = await _tryLoad(templateId);
    if (found != null) return found;

    final String fallbackId = cardSize.orientation == CardOrientation.horizontal
        ? defaultHorizontalId
        : defaultVerticalId;

    final CardTemplate? fallback = await _tryLoad(fallbackId);
    if (fallback != null) return fallback;

    // Both the requested template and the bundled default are unavailable.
    // This means the asset bundle is broken, which is a programming error
    // rather than something to paper over.
    throw StateError(
      'No card template available: "$templateId" is unknown and the bundled '
      'default "$fallbackId" could not be loaded.',
    );
  }

  Future<CardTemplate?> _tryLoad(String id) async {
    final CardTemplate? cached = _cache[id];
    if (cached != null) return cached;

    final Map<String, Object?>? remote = _remoteJson[id];
    if (remote != null) {
      final CardTemplate template = CardTemplate.fromJson(remote);
      _cache[id] = template;
      return template;
    }

    final String? assetPath = _bundledAssets[id];
    if (assetPath == null) return null;

    try {
      final String raw = await rootBundle.loadString(assetPath);
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final CardTemplate template = CardTemplate.fromJson(decoded);
      _cache[id] = template;
      return template;
    } on Object {
      return null;
    }
  }

  /// Loads every bundled template, for the admin panel's template picker.
  Future<List<CardTemplate>> loadAllBundled() async {
    final List<CardTemplate> result = <CardTemplate>[];
    for (final String id in _bundledAssets.keys) {
      final CardTemplate? t = await _tryLoad(id);
      if (t != null) result.add(t);
    }
    return result;
  }

  void clearCache() => _cache.clear();
}
