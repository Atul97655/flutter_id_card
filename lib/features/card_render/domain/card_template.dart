/// JSON-driven card layout.
///
/// LAYOUT CONTRACT - read before editing a template file.
///
/// * Every coordinate and dimension is in **millimetres**, measured from the
///   top-left corner of the trimmed card. Nothing here is in pixels or points
///   except [TextElement.sizePt], which is a real typographic point size.
/// * Font sizes are points because that is what the spec fixes them at
///   (Name 8 pt, Address 5 pt, ...) and what the `pdf` package consumes.
/// * Colours are either a literal `#RRGGBB` or one of the tokens in
///   [ColorToken], which resolve against the school's configured palette. Use
///   tokens - hard-coding a hex in a template defeats per-school branding.
///
/// Fixed elements (bands, logo, photo, footer text) carry explicit
/// coordinates. The variable-length part - the `LABEL : VALUE` rows, whose
/// count changes with each school's field toggles - is handled by
/// [FieldBlockElement], which flows only the enabled rows inside a reserved
/// box. Pinning each row to a fixed y would break the moment an admin switched
/// a field off.
library;

import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';

enum ColorToken {
  /// Red by default. Name, Class, Mobile, Address.
  primary,

  /// Blue by default. Father's Name, DOB.
  secondary,

  /// Header band fill. Resolves to the student's division colour when the
  /// school has configured one, otherwise the school's header colour.
  header,

  /// Explicit alias for [header], for templates where the division colouring
  /// is the whole point and the intent should be obvious in the JSON.
  divAccent,

  white,
  black,
  transparent;

  static ColorToken? parse(String raw) {
    if (!raw.startsWith('@')) return null;
    final String name = raw.substring(1);
    for (final ColorToken t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// The resolved colour context for one specific card.
///
/// Carries the student's division alongside the school config because the
/// header/accent colour can vary per division - several reference schools issue
/// the same layout in a different colour for each division.
class CardPalette {
  const CardPalette({required this.config, this.division = ''});

  final SchoolConfig config;
  final String division;

  int get primary => config.primaryColorHex;
  int get secondary => config.secondaryColorHex;
  int get header => config.headerColorFor(division);
  int get photoBackground => config.photoBackgroundHex;
}

/// A colour that is either fixed or resolved from the card's palette.
class ColorRef {
  const ColorRef.literal(this.argb) : token = null;
  const ColorRef.token(ColorToken this.token) : argb = 0;

  final int argb;
  final ColorToken? token;

  static const ColorRef white = ColorRef.token(ColorToken.white);
  static const ColorRef transparent = ColorRef.token(ColorToken.transparent);

  int resolve(CardPalette palette) => switch (token) {
        null => argb,
        ColorToken.primary => palette.primary,
        ColorToken.secondary => palette.secondary,
        // Both resolve through headerColorFor, so any template with a header
        // band picks up division colouring automatically once an admin
        // configures it - no template change needed.
        ColorToken.header || ColorToken.divAccent => palette.header,
        ColorToken.white => 0xFFFFFFFF,
        ColorToken.black => 0xFF000000,
        ColorToken.transparent => 0x00000000,
      };

  /// Accepts `@token` or `#RRGGBB`. Unparseable input resolves to the supplied
  /// fallback rather than throwing - a typo in a template must not stop a
  /// print run.
  static ColorRef parse(Object? raw, {ColorRef fallback = white}) {
    if (raw is! String || raw.isEmpty) return fallback;
    final ColorToken? token = ColorToken.parse(raw);
    if (token != null) return ColorRef.token(token);
    final int parsed = SchoolConfig.parseHex(raw, -1);
    return parsed == -1 ? fallback : ColorRef.literal(parsed);
  }
}

enum TextAlignH {
  left,
  center,
  right;

  static TextAlignH parse(Object? raw) => switch (raw) {
        'center' => TextAlignH.center,
        'right' => TextAlignH.right,
        _ => TextAlignH.left,
      };
}

/// Base for everything drawable. The box is the element's slot on the card.
sealed class CardElement {
  const CardElement({
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.heightMm,
  });

  final double xMm;
  final double yMm;
  final double widthMm;
  final double heightMm;

  static double _num(Object? v, [double fallback = 0]) => switch (v) {
        final num n => n.toDouble(),
        _ => fallback,
      };

  static CardElement? parse(Map<String, Object?> json) {
    final double x = _num(json['x']);
    final double y = _num(json['y']);
    final double w = _num(json['w']);
    final double h = _num(json['h']);

    return switch (json['type']) {
      'rect' => RectElement(
          xMm: x,
          yMm: y,
          widthMm: w,
          heightMm: h,
          fill: ColorRef.parse(json['fill'], fallback: ColorRef.transparent),
          cornerRadiusMm: _num(json['radius']),
        ),
      'text' => TextElement(
          xMm: x,
          yMm: y,
          widthMm: w,
          heightMm: h,
          value: (json['value'] as String?) ?? '',
          sizePt: _num(json['size'], 7),
          bold: json['bold'] == true,
          color: ColorRef.parse(json['color'], fallback: ColorRef.white),
          align: TextAlignH.parse(json['align']),
          maxLines: _num(json['maxLines'], 1).toInt(),
          requiresFieldKey: json['requires'] as String?,
        ),
      'photo' => PhotoElement(
          xMm: x,
          yMm: y,
          widthMm: w,
          heightMm: h,
          borderWidthMm: _num(json['borderWidth']),
          borderColor: ColorRef.parse(json['borderColor'], fallback: ColorRef.transparent),
        ),
      'logo' => LogoElement(xMm: x, yMm: y, widthMm: w, heightMm: h),
      'fields' => FieldBlockElement(
          xMm: x,
          yMm: y,
          widthMm: w,
          heightMm: h,
          labelWidthMm: _num(json['labelWidth'], 14),
          rowGapMm: _num(json['rowGap'], 0.8),
          showLabels: json['showLabels'] != false,
          exclude: <StudentField>{
            ...?(json['exclude'] as List<Object?>?)
                ?.whereType<String>()
                .map(StudentField.fromKey)
                .whereType<StudentField>(),
          },
        ),
      'nameBanner' => NameBannerElement(
          xMm: x,
          yMm: y,
          widthMm: w,
          heightMm: h,
          sizePt: _num(json['size'], 8),
          color: ColorRef.parse(json['color'], fallback: const ColorRef.token(ColorToken.primary)),
          align: TextAlignH.parse(json['align'] ?? 'center'),
        ),
      _ => null,
    };
  }
}

/// Solid block - header bands, footer strips, photo frames.
class RectElement extends CardElement {
  const RectElement({
    required super.xMm,
    required super.yMm,
    required super.widthMm,
    required super.heightMm,
    required this.fill,
    this.cornerRadiusMm = 0,
  });

  final ColorRef fill;
  final double cornerRadiusMm;
}

/// Static text with token substitution.
///
/// School tokens: `{schoolName}`, `{addressLine}`, `{contactLine}`.
/// Student tokens: `{name}`, `{class}`, `{division}`, `{dob}`, `{mobile}`.
///
/// Student tokens let a template letter a badge such as `DIV-{division}`
/// without a bespoke element type. Pair them with [requiresFieldKey] so the
/// badge disappears entirely rather than printing a bare "DIV-" when the
/// student has no division.
class TextElement extends CardElement {
  const TextElement({
    required super.xMm,
    required super.yMm,
    required super.widthMm,
    required super.heightMm,
    required this.value,
    required this.sizePt,
    required this.bold,
    required this.color,
    required this.align,
    this.maxLines = 1,
    this.requiresFieldKey,
  });

  final String value;
  final double sizePt;
  final bool bold;
  final ColorRef color;
  final TextAlignH align;
  final int maxLines;

  /// Skip this element when the named student field is empty. `null` means
  /// always draw it.
  final String? requiresFieldKey;

  String resolve(SchoolConfig config, StudentEntry? entry) {
    String out = value
        .replaceAll('{schoolName}', config.name)
        .replaceAll('{addressLine}', config.addressLine)
        .replaceAll('{contactLine}', config.contactLine);

    if (entry != null) {
      out = out
          .replaceAll('{name}', entry.name)
          .replaceAll('{class}', entry.studentClass)
          .replaceAll('{division}', entry.division)
          .replaceAll('{dob}', entry.formattedDob)
          .replaceAll('{mobile}', entry.mobile);
    }
    return out;
  }

  /// Whether this element should be drawn for [entry].
  bool appliesTo(StudentEntry? entry) {
    final String? key = requiresFieldKey;
    if (key == null) return true;
    if (entry == null) return false;
    final StudentField? field = StudentField.fromKey(key);
    if (field == null) return true;
    return entry.valueOf(field).trim().isNotEmpty;
  }
}

class PhotoElement extends CardElement {
  const PhotoElement({
    required super.xMm,
    required super.yMm,
    required super.widthMm,
    required super.heightMm,
    this.borderWidthMm = 0,
    this.borderColor = ColorRef.transparent,
  });

  final double borderWidthMm;
  final ColorRef borderColor;
}

class LogoElement extends CardElement {
  const LogoElement({
    required super.xMm,
    required super.yMm,
    required super.widthMm,
    required super.heightMm,
  });
}

/// The student's name rendered as a prominent centred banner rather than as a
/// `LABEL : VALUE` row - the treatment used by most of the reference designs.
class NameBannerElement extends CardElement {
  const NameBannerElement({
    required super.xMm,
    required super.yMm,
    required super.widthMm,
    required super.heightMm,
    required this.sizePt,
    required this.color,
    required this.align,
  });

  final double sizePt;
  final ColorRef color;
  final TextAlignH align;
}

/// Reserved area into which the enabled `LABEL : VALUE` rows are flowed.
///
/// The renderer decides row height and spacing from the number of enabled
/// fields and the box height, which is what lets one template serve a school
/// showing three fields and another showing eight.
class FieldBlockElement extends CardElement {
  const FieldBlockElement({
    required super.xMm,
    required super.yMm,
    required super.widthMm,
    required super.heightMm,
    this.labelWidthMm = 14,
    this.rowGapMm = 0.8,
    this.showLabels = true,
    this.exclude = const <StudentField>{},
  });

  /// Width of the label column, so every colon lines up vertically the way the
  /// reference cards do.
  final double labelWidthMm;

  final double rowGapMm;
  final bool showLabels;

  /// Fields drawn elsewhere on this template (typically `name`, which has its
  /// own banner) and so must not be repeated in the flow.
  final Set<StudentField> exclude;
}

class CardTemplate {
  const CardTemplate({
    required this.id,
    required this.name,
    required this.cardSizeId,
    required this.elements,
    this.backgroundColor = const ColorRef.token(ColorToken.white),
  });

  final String id;
  final String name;

  /// The size this template was authored against. A template can still be
  /// rendered at another size - the renderer scales proportionally - but
  /// staying on the authored size gives the intended result.
  final String cardSizeId;

  final ColorRef backgroundColor;
  final List<CardElement> elements;

  CardSize get authoredSize => CardSize.fromId(cardSizeId);

  CardOrientation get orientation => authoredSize.orientation;

  static CardTemplate fromJson(Map<String, Object?> json) {
    final List<CardElement> elements = <CardElement>[];
    for (final Object? raw in (json['elements'] as List<Object?>?) ?? const <Object?>[]) {
      if (raw is! Map<String, Object?>) continue;
      final CardElement? element = CardElement.parse(raw);
      // Unknown element types are skipped rather than fatal, so a template
      // authored by a newer build still renders its known parts.
      if (element != null) elements.add(element);
    }

    return CardTemplate(
      id: (json['id'] as String?) ?? 'unnamed',
      name: (json['name'] as String?) ?? 'Unnamed template',
      cardSizeId: (json['cardSizeId'] as String?) ?? CardSize.defaultSize.id,
      backgroundColor: ColorRef.parse(json['background'], fallback: ColorRef.white),
      elements: elements,
    );
  }

  @override
  String toString() => 'CardTemplate($id, $cardSizeId, ${elements.length} elements)';
}
