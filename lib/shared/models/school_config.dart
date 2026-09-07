import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';

/// Per-school settings, owned by the admin panel and consumed by the
/// data-entry app.
///
/// This object is what makes the form "dynamic": the form builder renders
/// exactly the fields in [enabledFields], in enum order, and nothing else.
/// It is cached locally so a school that has never been online since its last
/// settings change still renders the right form.
class SchoolConfig {
  const SchoolConfig({
    required this.id,
    required this.name,
    this.addressLine = '',
    this.contactLine = '',
    this.logoUrl,
    this.localLogoPath,
    this.cardSizeId = 'v54x86',
    this.templateId = 'default_vertical',
    this.enabledFieldKeys = const <String>{},
    this.primaryColorHex = kDefaultPrimaryHex,
    this.secondaryColorHex = kDefaultSecondaryHex,
    this.headerColorHex = kDefaultHeaderHex,
    this.photoBackgroundHex = kDefaultPhotoBackgroundHex,
    this.divisionColors = const <String, int>{},
    this.classes = defaultClasses,
    this.divisions = defaultDivisions,
    this.principalSignatureUrl,
    this.localPrincipalSignaturePath,
    this.updatedAt,
  });

  /// Default red, used for Name / Class / Mobile / Address.
  static const int kDefaultPrimaryHex = 0xFFD32F2F;

  /// Default blue, used for Father's Name / DOB.
  static const int kDefaultSecondaryHex = 0xFF1565C0;

  /// Header band colour. The reference designs all use a saturated block of
  /// school colour across the top.
  static const int kDefaultHeaderHex = 0xFF1565C0;

  /// White, the standard studio backdrop after background removal.
  static const int kDefaultPhotoBackgroundHex = 0xFFFFFFFF;

  static const List<String> defaultClasses = <String>[
    'NURSERY',
    'LKG',
    'UKG',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  static const List<String> defaultDivisions = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
  ];

  final String id;
  final String name;

  /// Printed under the school name in the header band.
  final String addressLine;

  /// Optional footer line (phone / email), as seen on several reference cards.
  final String contactLine;

  final String? logoUrl;

  /// Cached copy of the logo so the card renders offline.
  final String? localLogoPath;

  /// Allowed classes for student entry dropdown.
  final List<String> classes;

  /// Allowed divisions for student entry dropdown.
  final List<String> divisions;

  final String? principalSignatureUrl;
  final String? localPrincipalSignaturePath;

  final String cardSizeId;
  final String templateId;

  /// Stored as keys rather than enum values so an unknown key from a newer
  /// admin build is ignored instead of crashing an older data-entry build.
  final Set<String> enabledFieldKeys;

  final int primaryColorHex;
  final int secondaryColorHex;
  final int headerColorHex;
  final int photoBackgroundHex;

  /// Accent colour per division, keyed by the UPPERCASE division value
  /// (`'A'`, `'B'`, ...).
  ///
  /// Several schools in the reference set issue the same card in one colour per
  /// division - Sacred Heart Convent runs Div A red, B blue, C pink, D green,
  /// E orange, F purple - so a teacher can spot a wrong card across a room.
  ///
  /// When a division has an entry here it overrides [headerColorHex] for that
  /// student's card. Leave the map empty and every card uses the school colour,
  /// which is exactly the previous behaviour.
  final Map<String, int> divisionColors;

  final DateTime? updatedAt;

  /// Header/accent colour for a specific student's card.
  ///
  /// Lookup is case- and whitespace-insensitive because the division arrives
  /// from a free-text field an operator typed.
  int headerColorFor(String? division) {
    if (divisionColors.isEmpty) return headerColorHex;
    final String key = (division ?? '').trim().toUpperCase();
    if (key.isEmpty) return headerColorHex;
    return divisionColors[key] ?? headerColorHex;
  }

  bool get usesDivisionColors => divisionColors.isNotEmpty;

  /// Sets or clears one division's colour. Passing null removes the override.
  SchoolConfig withDivisionColor(String division, int? argb) {
    final String key = division.trim().toUpperCase();
    if (key.isEmpty) return this;
    final Map<String, int> next = Map<String, int>.of(divisionColors);
    if (argb == null) {
      next.remove(key);
    } else {
      next[key] = argb;
    }
    return copyWith(divisionColors: next);
  }

  CardSize get cardSize => CardSize.fromId(cardSizeId);

  /// The fields the form should render and the card should print, in the
  /// canonical enum order. Always-on fields are forced in regardless of what
  /// the stored set says.
  List<StudentField> get enabledFields => StudentField.values
      .where((StudentField f) => f.alwaysEnabled || enabledFieldKeys.contains(f.key))
      .toList();

  bool isEnabled(StudentField field) =>
      field.alwaysEnabled || enabledFieldKeys.contains(field.key);

  /// Sensible starting point for a newly created school: everything on.
  static Set<String> get allFieldKeys =>
      StudentField.values.map((StudentField f) => f.key).toSet();

  static SchoolConfig fallback(String id) => SchoolConfig(
        id: id,
        name: 'SCHOOL',
        enabledFieldKeys: allFieldKeys,
      );

  SchoolConfig copyWith({
    String? id,
    String? name,
    String? addressLine,
    String? contactLine,
    String? logoUrl,
    String? localLogoPath,
    String? cardSizeId,
    String? templateId,
    Set<String>? enabledFieldKeys,
    int? primaryColorHex,
    int? secondaryColorHex,
    int? headerColorHex,
    int? photoBackgroundHex,
    Map<String, int>? divisionColors,
    List<String>? classes,
    List<String>? divisions,
    String? principalSignatureUrl,
    String? localPrincipalSignaturePath,
    DateTime? updatedAt,
  }) {
    return SchoolConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      addressLine: addressLine ?? this.addressLine,
      contactLine: contactLine ?? this.contactLine,
      logoUrl: logoUrl ?? this.logoUrl,
      localLogoPath: localLogoPath ?? this.localLogoPath,
      cardSizeId: cardSizeId ?? this.cardSizeId,
      templateId: templateId ?? this.templateId,
      enabledFieldKeys: enabledFieldKeys ?? this.enabledFieldKeys,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      headerColorHex: headerColorHex ?? this.headerColorHex,
      photoBackgroundHex: photoBackgroundHex ?? this.photoBackgroundHex,
      divisionColors: divisionColors ?? this.divisionColors,
      classes: classes ?? this.classes,
      divisions: divisions ?? this.divisions,
      principalSignatureUrl: principalSignatureUrl ?? this.principalSignatureUrl,
      localPrincipalSignaturePath:
          localPrincipalSignaturePath ?? this.localPrincipalSignaturePath,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Toggle helper used by the admin settings screen.
  SchoolConfig withFieldEnabled(StudentField field, bool enabled) {
    if (field.alwaysEnabled) return this;
    final Set<String> next = Set<String>.of(enabledFieldKeys);
    if (enabled) {
      next.add(field.key);
    } else {
      next.remove(field.key);
    }
    return copyWith(enabledFieldKeys: next);
  }

  Map<String, Object?> toFirestoreMap() => <String, Object?>{
        'name': name,
        'addressLine': addressLine,
        'contactLine': contactLine,
        'logoUrl': logoUrl,
        'principalSignatureUrl': principalSignatureUrl,
        'cardSizeId': cardSizeId,
        'templateId': templateId,
        'enabledFields': enabledFieldKeys.toList()..sort(),
        'classes': classes,
        'divisions': divisions,
        'primaryColor': _toHexString(primaryColorHex),
        'secondaryColor': _toHexString(secondaryColorHex),
        'headerColor': _toHexString(headerColorHex),
        'photoBackground': _toHexString(photoBackgroundHex),
        // Stored as a native Firestore map of division -> hex so it is legible
        // and editable straight from the console.
        'divisionColors': <String, String>{
          for (final MapEntry<String, int> e in divisionColors.entries)
            e.key: _toHexString(e.value),
        },
        'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  static SchoolConfig fromFirestoreMap(String id, Map<String, Object?> map) {
    return SchoolConfig(
      id: id,
      name: (map['name'] as String?) ?? 'SCHOOL',
      addressLine: (map['addressLine'] as String?) ?? '',
      contactLine: (map['contactLine'] as String?) ?? '',
      logoUrl: map['logoUrl'] as String?,
      principalSignatureUrl: map['principalSignatureUrl'] as String?,
      cardSizeId: (map['cardSizeId'] as String?) ?? 'v54x86',
      templateId: (map['templateId'] as String?) ?? 'default_vertical',
      enabledFieldKeys: <String>{
        ...?(map['enabledFields'] as List<Object?>?)?.whereType<String>(),
      },
      classes: (map['classes'] as List<Object?>?)?.whereType<String>().toList() ??
          defaultClasses,
      divisions:
          (map['divisions'] as List<Object?>?)?.whereType<String>().toList() ??
              defaultDivisions,
      primaryColorHex: parseHex(map['primaryColor'] as String?, kDefaultPrimaryHex),
      secondaryColorHex: parseHex(map['secondaryColor'] as String?, kDefaultSecondaryHex),
      headerColorHex: parseHex(map['headerColor'] as String?, kDefaultHeaderHex),
      photoBackgroundHex: parseHex(map['photoBackground'] as String?, kDefaultPhotoBackgroundHex),
      divisionColors: decodeDivisionColors(map['divisionColors']),
      updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? ''),
    );
  }

  /// Reads the division -> colour map defensively.
  ///
  /// Anything unparseable is skipped rather than throwing: a colour typed by
  /// hand in the Firestore console must not stop a school from printing.
  static Map<String, int> decodeDivisionColors(Object? raw) {
    if (raw is! Map<Object?, Object?>) return const <String, int>{};
    final Map<String, int> result = <String, int>{};
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
      final Object? key = entry.key;
      final Object? value = entry.value;
      if (key is! String || value is! String) continue;
      final String division = key.trim().toUpperCase();
      if (division.isEmpty) continue;
      final int parsed = parseHex(value, -1);
      if (parsed == -1) continue;
      result[division] = parsed;
    }
    return result;
  }

  /// Accepts `#RRGGBB`, `RRGGBB`, `#AARRGGBB` or `AARRGGBB`. Returns
  /// [fallbackValue] on anything unparseable - a typo in a colour override must
  /// never stop a school from printing.
  static int parseHex(String? raw, int fallbackValue) {
    if (raw == null) return fallbackValue;
    final String cleaned = raw.replaceAll('#', '').trim();
    if (cleaned.length != 6 && cleaned.length != 8) return fallbackValue;
    final int? parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return fallbackValue;
    // Assume fully opaque when no alpha channel was supplied.
    return cleaned.length == 6 ? 0xFF000000 | parsed : parsed;
  }

  static String _toHexString(int value) =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  String toString() => 'SchoolConfig($id, $name, $cardSizeId)';
}
