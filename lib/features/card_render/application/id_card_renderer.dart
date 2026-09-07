import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/features/card_render/domain/card_typography.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds the printable card.
///
/// THIS IS THE SINGLE RENDERER. The on-screen preview does not re-implement the
/// layout in Flutter widgets - it rasterises the PDF this class produces. That
/// is deliberate: two renderers means two layouts that drift apart, and the
/// operator finds out only after a 25-up sheet has been printed.
///
/// Geometry rules enforced here:
///   * Element boxes arrive in millimetres and are converted to PDF points via
///     [PrintUnits.mmToPt] at the moment they are handed to `pw.Positioned`.
///   * Font sizes are passed through untouched: the `pdf` package's `fontSize`
///     is already in points, which is the unit the spec fixes them in.
///   * Nothing in this file reads MediaQuery, devicePixelRatio, or any other
///     screen-derived value.
class IdCardRenderer {
  IdCardRenderer._(this._regular, this._bold);

  final pw.Font _regular;
  final pw.Font _bold;

  static IdCardRenderer? _cached;

  /// Loads and caches the bundled fonts.
  ///
  /// Fonts are bundled rather than taken from the device so that a card
  /// rendered on a phone, a tablet and the print workstation are byte-identical
  /// in metrics. A system font substitution would reflow text and change where
  /// the address wraps.
  static Future<IdCardRenderer> load() async {
    if (_cached != null) return _cached!;

    final ByteData regular = await rootBundle.load('assets/fonts/Arial-Regular.ttf');
    final ByteData bold = await rootBundle.load('assets/fonts/Arial-Bold.ttf');

    return _cached = IdCardRenderer._(
      pw.Font.ttf(regular),
      pw.Font.ttf(bold),
    );
  }

  pw.Font fontFor({required bool bold}) => bold ? _bold : _regular;

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  /// One card as a standalone document, on a page of exactly the card's size.
  ///
  /// [bleedMm] extends the page beyond the trim on all four sides; the card
  /// artwork is centred inside it so a slightly off cut never exposes paper.
  /// The page geometry for a card, in PDF points.
  ///
  /// This is the function that decides the physical size of the printed
  /// output, so it is kept tiny, pure and directly unit-tested. `marginAll: 0`
  /// is essential - any page margin would shrink the card inside the sheet.
  static PdfPageFormat pageFormatFor(CardSize size, {double bleedMm = 0}) {
    return PdfPageFormat(
      PrintUnits.mmToPt(size.widthMm + bleedMm * 2),
      PrintUnits.mmToPt(size.heightMm + bleedMm * 2),
      marginAll: 0,
    );
  }

  Future<Uint8List> buildSingleCardPdf({
    required StudentEntry entry,
    required SchoolConfig config,
    required CardTemplate template,
    required CardSize size,
    double bleedMm = 0,
    bool cropMarks = false,
    /// Disable only for tests that inspect the raw PDF structure.
    bool compress = true,
  }) async {
    final CardRenderPlan plan = planFor(
      entry: entry,
      config: config,
      template: template,
      size: size,
    );

    final Uint8List? photo = await _readImage(entry.localPhotoPath);
    final Uint8List? logo = await _readImage(config.localLogoPath);
    final Uint8List? signature = await _readImage(config.localPrincipalSignaturePath);

    final pw.Document doc = pw.Document(
      title: '${entry.exportBaseName} ID Card',
      author: config.name,
      compress: compress,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormatFor(size, bleedMm: bleedMm),
        build: (pw.Context context) => pw.Stack(
          children: <pw.Widget>[
            pw.Positioned(
              left: PrintUnits.mmToPt(bleedMm),
              top: PrintUnits.mmToPt(bleedMm),
              child: buildCard(
                plan: plan,
                config: config,
                size: size,
                photoBytes: photo,
                logoBytes: logo,
                signatureBytes: signature,
              ),
            ),
            if (cropMarks)
              ...buildCropMarks(
                cardLeftMm: bleedMm,
                cardTopMm: bleedMm,
                size: size,
              ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// The card as a fixed-size widget, for embedding in an imposition sheet or
  /// rasterising for preview. Size is exactly the card's trim size.
  pw.Widget buildCard({
    required CardRenderPlan plan,
    required SchoolConfig config,
    required CardSize size,
    Uint8List? photoBytes,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) {
    final CardTemplate template = plan.template;
    // Derived once per card: the header/accent colour depends on this
    // student's division when the school has configured division colours.
    final CardPalette palette = CardPalette(
      config: config,
      division: plan.entry.division,
    );

    return pw.SizedBox(
      width: PrintUnits.mmToPt(size.widthMm),
      height: PrintUnits.mmToPt(size.heightMm),
      child: pw.Stack(
        children: <pw.Widget>[
          // Background first, then every element in template order - the JSON
          // list doubles as the z-order.
          pw.Positioned.fill(
            child: pw.Container(
              color: _pdfColor(template.backgroundColor.resolve(palette)),
            ),
          ),
          for (final CardElement element in template.elements)
            ..._buildElement(
              element: element,
              plan: plan,
              palette: palette,
              size: size,
              photoBytes: photoBytes,
              logoBytes: logoBytes,
              signatureBytes: signatureBytes,
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Element dispatch
  // ------------------------------------------------------------------

  List<pw.Widget> _buildElement({
    required CardElement element,
    required CardRenderPlan plan,
    required CardPalette palette,
    required CardSize size,
    Uint8List? photoBytes,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) {
    // Templates are authored against one size; rendering at another scales the
    // whole layout proportionally rather than leaving elements floating.
    final double sx = size.widthMm / plan.template.authoredSize.widthMm;
    final double sy = size.heightMm / plan.template.authoredSize.heightMm;

    pw.Widget position(CardElement e, pw.Widget child) => pw.Positioned(
          left: PrintUnits.mmToPt(e.xMm * sx),
          top: PrintUnits.mmToPt(e.yMm * sy),
          child: pw.SizedBox(
            width: PrintUnits.mmToPt(e.widthMm * sx),
            height: PrintUnits.mmToPt(e.heightMm * sy),
            child: child,
          ),
        );

    switch (element) {
      case final RectElement e:
        return <pw.Widget>[
          position(
            e,
            pw.Container(
              decoration: pw.BoxDecoration(
                color: _pdfColor(e.fill.resolve(palette)),
                borderRadius: e.cornerRadiusMm > 0
                    ? pw.BorderRadius.all(
                        pw.Radius.circular(PrintUnits.mmToPt(e.cornerRadiusMm)),
                      )
                    : null,
              ),
            ),
          ),
        ];

      case final TextElement e:
        // A badge gated on a field the student does not have is dropped
        // entirely - printing a bare "DIV-" reads as a defect.
        if (!e.appliesTo(plan.entry)) return const <pw.Widget>[];
        final String value = e.resolve(palette.config, plan.entry);
        if (value.trim().isEmpty) return const <pw.Widget>[];
        return <pw.Widget>[
          position(
            e,
            _text(
              value,
              sizePt: e.sizePt,
              bold: e.bold,
              color: e.color.resolve(palette),
              align: e.align,
              maxLines: e.maxLines,
            ),
          ),
        ];

      case final NameBannerElement e:
        final String value = plan.entry.name;
        if (value.trim().isEmpty) return const <pw.Widget>[];
        return <pw.Widget>[
          position(
            e,
            _text(
              value,
              sizePt: e.sizePt,
              bold: true,
              color: e.color.resolve(palette),
              align: e.align,
              maxLines: 1,
            ),
          ),
        ];

      case final PhotoElement e:
        return <pw.Widget>[
          position(
            e,
            pw.Container(
              decoration: pw.BoxDecoration(
                color: _pdfColor(palette.photoBackground),
                border: e.borderWidthMm > 0
                    ? pw.Border.all(
                        color: _pdfColor(e.borderColor.resolve(palette)),
                        width: PrintUnits.mmToPt(e.borderWidthMm),
                      )
                    : null,
              ),
              child: photoBytes == null
                  ? pw.SizedBox()
                  : pw.Image(
                      pw.MemoryImage(photoBytes),
                      // Cover, not contain: the photo is already cropped to
                      // exactly 1.2 x 1.5 in upstream, so cover is a no-op for
                      // correct input and crops rather than letterboxes if a
                      // legacy image slips through at the wrong ratio.
                      fit: pw.BoxFit.cover,
                    ),
            ),
          ),
        ];

      case final LogoElement e:
        if (logoBytes == null) return const <pw.Widget>[];
        return <pw.Widget>[
          position(
            e,
            pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
          ),
        ];

      case final SignatureElement e:
        if (signatureBytes == null) return const <pw.Widget>[];
        return <pw.Widget>[
          position(
            e,
            pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
          ),
        ];

      case final FieldBlockElement e:
        return _buildFieldRows(
          block: e,
          plan: plan,
          palette: palette,
          scaleX: sx,
          scaleY: sy,
        );
    }
  }

  // ------------------------------------------------------------------
  // Field row flow
  // ------------------------------------------------------------------

  /// Lays the enabled `LABEL : VALUE` rows out inside the block.
  ///
  /// Rows are absolutely positioned rather than put in a Column so that every
  /// row's baseline is a known millimetre offset - which is what keeps the
  /// colons aligned down the card the way the reference designs have them.
  List<pw.Widget> _buildFieldRows({
    required FieldBlockElement block,
    required CardRenderPlan plan,
    required CardPalette palette,
    required double scaleX,
    required double scaleY,
  }) {
    final List<pw.Widget> widgets = <pw.Widget>[];

    final double blockLeftMm = block.xMm * scaleX;
    final double blockTopMm = block.yMm * scaleY;
    final double blockWidthMm = block.widthMm * scaleX;
    final double labelWidthMm = block.labelWidthMm * scaleX;
    final double gapMm = block.rowGapMm * scaleY;

    double cursorMm = blockTopMm;

    for (final PlannedRow row in plan.rows) {
      final double rowHeightMm = row.heightMm;

      // Label column, right-padded so the colon column lines up.
      if (block.showLabels) {
        widgets.add(
          pw.Positioned(
            left: PrintUnits.mmToPt(blockLeftMm),
            top: PrintUnits.mmToPt(cursorMm),
            child: pw.SizedBox(
              width: PrintUnits.mmToPt(labelWidthMm),
              height: PrintUnits.mmToPt(rowHeightMm),
              child: _text(
                row.field.cardLabel,
                sizePt: row.style.sizePt,
                bold: row.style.bold,
                color: row.style.color.resolve(palette),
                align: TextAlignH.left,
                maxLines: 1,
              ),
            ),
          ),
        );
        widgets.add(
          pw.Positioned(
            left: PrintUnits.mmToPt(blockLeftMm + labelWidthMm),
            top: PrintUnits.mmToPt(cursorMm),
            child: pw.SizedBox(
              width: PrintUnits.mmToPt(_colonWidthMm),
              height: PrintUnits.mmToPt(rowHeightMm),
              child: _text(
                ':',
                sizePt: row.style.sizePt,
                bold: row.style.bold,
                color: row.style.color.resolve(palette),
                align: TextAlignH.left,
                maxLines: 1,
              ),
            ),
          ),
        );
      }

      final double valueLeftMm =
          block.showLabels ? blockLeftMm + labelWidthMm + _colonWidthMm : blockLeftMm;
      final double valueWidthMm = blockWidthMm - (valueLeftMm - blockLeftMm);

      widgets.add(
        pw.Positioned(
          left: PrintUnits.mmToPt(valueLeftMm),
          top: PrintUnits.mmToPt(cursorMm),
          child: pw.SizedBox(
            width: PrintUnits.mmToPt(valueWidthMm),
            height: PrintUnits.mmToPt(rowHeightMm),
            child: _text(
              row.value,
              sizePt: row.style.sizePt,
              bold: row.style.bold,
              color: row.style.color.resolve(palette),
              align: TextAlignH.left,
              maxLines: row.style.maxLines,
            ),
          ),
        ),
      );

      cursorMm += rowHeightMm + gapMm;
    }

    return widgets;
  }

  /// Width reserved for the ':' separator column.
  static const double _colonWidthMm = 1.8;

  // ------------------------------------------------------------------
  // Crop marks
  // ------------------------------------------------------------------

  /// Hairlines at each corner, outside the trim box, for the guillotine
  /// operator to line up on. Drawn as thin filled rectangles because they
  /// reproduce more reliably on a laser printer than stroked lines at
  /// sub-point widths.
  List<pw.Widget> buildCropMarks({
    required double cardLeftMm,
    required double cardTopMm,
    required CardSize size,
  }) {
    const double len = PrintUnits.cropMarkLengthMm;
    const double off = PrintUnits.cropMarkOffsetMm;
    const double w = PrintUnits.cropMarkWidthMm;

    final double left = cardLeftMm;
    final double top = cardTopMm;
    final double right = cardLeftMm + size.widthMm;
    final double bottom = cardTopMm + size.heightMm;

    pw.Widget mark(double xMm, double yMm, double wMm, double hMm) => pw.Positioned(
          left: PrintUnits.mmToPt(xMm),
          top: PrintUnits.mmToPt(yMm),
          child: pw.Container(
            width: PrintUnits.mmToPt(wMm),
            height: PrintUnits.mmToPt(hMm),
            color: PdfColors.black,
          ),
        );

    return <pw.Widget>[
      // Top-left
      mark(left - off - len, top - w / 2, len, w),
      mark(left - w / 2, top - off - len, w, len),
      // Top-right
      mark(right + off, top - w / 2, len, w),
      mark(right - w / 2, top - off - len, w, len),
      // Bottom-left
      mark(left - off - len, bottom - w / 2, len, w),
      mark(left - w / 2, bottom + off, w, len),
      // Bottom-right
      mark(right + off, bottom - w / 2, len, w),
      mark(right - w / 2, bottom + off, w, len),
    ];
  }

  // ------------------------------------------------------------------
  // Primitives
  // ------------------------------------------------------------------

  pw.Widget _text(
    String value, {
    required double sizePt,
    required bool bold,
    required int color,
    required TextAlignH align,
    required int maxLines,
  }) {
    return pw.Align(
      alignment: switch (align) {
        TextAlignH.left => pw.Alignment.centerLeft,
        TextAlignH.center => pw.Alignment.center,
        TextAlignH.right => pw.Alignment.centerRight,
      },
      child: pw.Text(
        value,
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
        textAlign: switch (align) {
          TextAlignH.left => pw.TextAlign.left,
          TextAlignH.center => pw.TextAlign.center,
          TextAlignH.right => pw.TextAlign.right,
        },
        style: pw.TextStyle(
          font: fontFor(bold: bold),
          // fontSize is already in points - no conversion, by design.
          fontSize: sizePt,
          color: _pdfColor(color),
          lineSpacing: 0,
        ),
      ),
    );
  }

  static PdfColor _pdfColor(int argb) => PdfColor(
        ((argb >> 16) & 0xFF) / 255,
        ((argb >> 8) & 0xFF) / 255,
        (argb & 0xFF) / 255,
        ((argb >> 24) & 0xFF) / 255,
      );

  static Future<Uint8List?> _readImage(String? path) async {
    if (path == null || path.isEmpty) return null;
    final File file = File(path);
    if (!file.existsSync()) return null;
    try {
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Planning
  // ------------------------------------------------------------------

  /// Works out which rows to draw and how tall each is, before any drawing
  /// happens.
  ///
  /// Separated from rendering so the same numbers can be unit-tested and so the
  /// preview screen can show fit warnings without building a PDF.
  static CardRenderPlan planFor({
    required StudentEntry entry,
    required SchoolConfig config,
    required CardTemplate template,
    required CardSize size,
  }) {
    final FieldBlockElement? block = template.elements
        .whereType<FieldBlockElement>()
        .cast<FieldBlockElement?>()
        .firstWhere((FieldBlockElement? e) => e != null, orElse: () => null);

    if (block == null) {
      return CardRenderPlan(
        entry: entry,
        template: template,
        rows: const <PlannedRow>[],
        fitScale: 1,
        warnings: const <String>[],
      );
    }

    final double scaleY = size.heightMm / template.authoredSize.heightMm;

    // Only rows that are enabled for this school AND actually have a value.
    // Printing "MOBILE NO :" with nothing after it looks like a defect.
    final List<StudentField> fields = config.enabledFields
        .where((StudentField f) => f.kind != FieldKind.photo)
        .where((StudentField f) => !block.exclude.contains(f))
        .where((StudentField f) => entry.valueOf(f).trim().isNotEmpty)
        .toList();

    // Gaps are fixed template geometry and are NOT scaled with the text - only
    // the type shrinks. So the space the rows have to share is the block height
    // minus the gaps, and fitScale is computed against that. Scaling the rows
    // but not the gaps (or vice versa) makes the flow overflow the block.
    double naturalRowsMm = 0;
    for (final StudentField f in fields) {
      naturalRowsMm += _naturalRowHeightMm(CardTypography.forField(f));
    }
    final double gapsMm =
        block.rowGapMm * scaleY * (fields.length - 1).clamp(0, fields.length);

    final double availableMm = block.heightMm * scaleY;
    final double availableForRowsMm = availableMm - gapsMm;

    final List<String> warnings = <String>[];

    double fitScale;
    if (fields.isEmpty || naturalRowsMm <= 0) {
      fitScale = 1;
    } else if (availableForRowsMm <= 0) {
      // The gaps alone exceed the block: far too many rows for this layout.
      // Clamp hard so the render stays inside its box and say so loudly.
      fitScale = _minimumFitScale;
      warnings.add(
        'Too many fields are enabled to fit the ${size.label} card. Switch '
        'fields off in the admin panel or choose a larger card size.',
      );
    } else {
      fitScale = (availableForRowsMm / naturalRowsMm).clamp(_minimumFitScale, 1.0);
    }

    if (warnings.isEmpty && fitScale < _fitWarningThreshold) {
      warnings.add(
        'The ${fields.length} enabled fields do not fit the '
        '${size.label} card at their specified point sizes. Text has been '
        'reduced to ${(fitScale * 100).round()}% to fit. Switch off a field in '
        'the admin panel or use a larger card to print at full size.',
      );
    }

    final List<PlannedRow> rows = <PlannedRow>[
      for (final StudentField f in fields)
        PlannedRow(
          field: f,
          value: entry.valueOf(f),
          style: CardTypography.forField(f).scaled(fitScale),
          heightMm: _naturalRowHeightMm(CardTypography.forField(f)) * fitScale,
        ),
    ];

    return CardRenderPlan(
      entry: entry,
      template: template,
      rows: rows,
      fitScale: fitScale,
      warnings: warnings,
    );
  }

  /// Below this, the reduction is visible enough that the operator should be
  /// told rather than left to discover it on a printed sheet.
  static const double _fitWarningThreshold = 0.92;

  /// Hard floor on shrinking. Below roughly 60% of the specified sizes the
  /// address (5 pt nominal) drops under 3 pt and stops being legible in print,
  /// so we clamp here and warn instead of rendering something unreadable.
  static const double _minimumFitScale = 0.6;

  static double _naturalRowHeightMm(CardTypography style) =>
      PrintUnits.ptToMm(style.sizePt * CardTypography.lineHeightFactor) *
      style.maxLines;
}

/// One `LABEL : VALUE` row, already sized.
class PlannedRow {
  const PlannedRow({
    required this.field,
    required this.value,
    required this.style,
    required this.heightMm,
  });

  final StudentField field;
  final String value;
  final CardTypography style;
  final double heightMm;
}

/// The measured layout for one card, produced before any drawing.
class CardRenderPlan {
  const CardRenderPlan({
    required this.entry,
    required this.template,
    required this.rows,
    required this.fitScale,
    required this.warnings,
  });

  final StudentEntry entry;
  final CardTemplate template;
  final List<PlannedRow> rows;

  /// 1.0 when everything printed at its specified point size; below 1.0 when
  /// rows had to be reduced to fit the block.
  final double fitScale;

  /// Operator-facing problems found while planning. Empty means a clean render.
  final List<String> warnings;

  bool get hasWarnings => warnings.isNotEmpty;
}
