import 'package:flutter_id_card/shared/print/print_units.dart';

enum CardOrientation {
  vertical,
  horizontal;

  String get label => this == CardOrientation.vertical ? 'Vertical' : 'Horizontal';
}

/// A physical card size in millimetres.
///
/// Sizes are a closed set chosen by the admin per school. They are stored by
/// [id] so that renaming a label never invalidates existing school configs.
class CardSize {
  const CardSize({
    required this.id,
    required this.widthMm,
    required this.heightMm,
  });

  final String id;
  final double widthMm;
  final double heightMm;

  CardOrientation get orientation =>
      heightMm >= widthMm ? CardOrientation.vertical : CardOrientation.horizontal;

  /// Width / height, for `AspectRatio` in the on-screen preview.
  double get aspectRatio => widthMm / heightMm;

  double get widthPt => PrintUnits.mmToPt(widthMm);
  double get heightPt => PrintUnits.mmToPt(heightMm);

  /// Size including bleed on all four sides (bleed is added twice per axis).
  double widthWithBleedMm(double bleedMm) => widthMm + bleedMm * 2;
  double heightWithBleedMm(double bleedMm) => heightMm + bleedMm * 2;

  String get label => '${_fmt(widthMm)} x ${_fmt(heightMm)} mm (${orientation.label})';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // -------------------------------------------------------------------
  // The six supported sizes
  // -------------------------------------------------------------------

  static const CardSize v52x84 = CardSize(id: 'v52x84', widthMm: 52, heightMm: 84);
  static const CardSize v54x86 = CardSize(id: 'v54x86', widthMm: 54, heightMm: 86);
  static const CardSize v56x88 = CardSize(id: 'v56x88', widthMm: 56, heightMm: 88);
  static const CardSize h84x52 = CardSize(id: 'h84x52', widthMm: 84, heightMm: 52);
  static const CardSize h86x54 = CardSize(id: 'h86x54', widthMm: 86, heightMm: 54);
  static const CardSize h88x56 = CardSize(id: 'h88x56', widthMm: 88, heightMm: 56);

  /// The industry-standard size and the one all the reference designs use.
  static const CardSize defaultSize = v54x86;

  static const List<CardSize> all = <CardSize>[
    v52x84,
    v54x86,
    v56x88,
    h84x52,
    h86x54,
    h88x56,
  ];

  static List<CardSize> get vertical =>
      all.where((CardSize s) => s.orientation == CardOrientation.vertical).toList();

  static List<CardSize> get horizontal =>
      all.where((CardSize s) => s.orientation == CardOrientation.horizontal).toList();

  /// Falls back to [defaultSize] rather than throwing: a bad id in a synced
  /// school config must not brick the data-entry app in the field.
  static CardSize fromId(String? id) => all.firstWhere(
        (CardSize s) => s.id == id,
        orElse: () => defaultSize,
      );

  @override
  bool operator ==(Object other) =>
      other is CardSize &&
      other.id == id &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm;

  @override
  int get hashCode => Object.hash(id, widthMm, heightMm);

  @override
  String toString() => 'CardSize($id, ${widthMm}x${heightMm}mm)';
}
