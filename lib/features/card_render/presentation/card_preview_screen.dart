import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/card_render/application/card_render_providers.dart';
import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/sync_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

/// True-size card preview.
///
/// The image on screen is a raster of the *actual* PDF that would be printed -
/// see [IdCardRenderer]. There is no second Flutter-widget implementation of
/// the layout, so "what you see" and "what prints" cannot drift apart.
///
/// The card is also drawn at its true physical size using the device's real
/// pixel density, so an operator can hold a printed card against the screen and
/// compare.
class CardPreviewScreen extends ConsumerStatefulWidget {
  const CardPreviewScreen({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<CardPreviewScreen> createState() => _CardPreviewScreenState();
}

class _CardPreviewScreenState extends ConsumerState<CardPreviewScreen> {
  Uint8List? _pdfBytes;
  Uint8List? _rasterPng;
  CardRenderPlan? _plan;
  String? _error;
  bool _busy = true;

  /// Signature of the inputs the current raster was built from, so we only
  /// re-render when something that affects the card actually changed.
  String? _renderedSignature;

  bool _trueSize = true;

  @override
  Widget build(BuildContext context) {
    final StudentEntry? entry = ref.watch(entryByIdProvider(widget.entryId));
    final AsyncValue<SchoolConfig> configAsync = ref.watch(
      schoolConfigProvider,
    );
    final AsyncValue<CardTemplate> templateAsync = ref.watch(
      activeTemplateProvider,
    );
    final AsyncValue<IdCardRenderer> rendererAsync = ref.watch(
      idCardRendererProvider,
    );

    if (entry != null &&
        configAsync.hasValue &&
        templateAsync.hasValue &&
        rendererAsync.hasValue) {
      final String signature = _signatureFor(
        entry,
        configAsync.requireValue,
        templateAsync.requireValue,
      );
      if (signature != _renderedSignature) {
        _renderedSignature = signature;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(
              _render(
                entry,
                configAsync.requireValue,
                templateAsync.requireValue,
                rendererAsync.requireValue,
              ),
            );
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Preview'),
        actions: <Widget>[
          IconButton(
            tooltip: _trueSize ? 'Fit to screen' : 'Show at true size',
            icon: Icon(
              _trueSize ? Icons.fit_screen_outlined : Icons.straighten,
            ),
            onPressed: () => setState(() => _trueSize = !_trueSize),
          ),
        ],
      ),
      body: entry == null
          ? const Center(child: CircularProgressIndicator())
          : _body(entry, configAsync.value),
      bottomNavigationBar: entry == null ? null : _actions(entry),
    );
  }

  String _signatureFor(
    StudentEntry entry,
    SchoolConfig config,
    CardTemplate template,
  ) {
    return <Object?>[
      entry.id,
      entry.updatedAt.microsecondsSinceEpoch,
      entry.localPhotoPath,
      config.updatedAt?.microsecondsSinceEpoch,
      config.cardSizeId,
      config.enabledFieldKeys.length,
      config.primaryColorHex,
      config.secondaryColorHex,
      config.headerColorHex,
      template.id,
    ].join('|');
  }

  Future<void> _render(
    StudentEntry entry,
    SchoolConfig config,
    CardTemplate template,
    IdCardRenderer renderer,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final CardSize size = config.cardSize;

      final CardRenderPlan plan = IdCardRenderer.planFor(
        entry: entry,
        config: config,
        template: template,
        size: size,
      );

      final Uint8List pdf = await renderer.buildSingleCardPdf(
        entry: entry,
        config: config,
        template: template,
        size: size,
      );

      // Rasterise the real PDF at print resolution. This is what guarantees the
      // preview and the print are the same artwork.
      final PdfRaster raster = await Printing.raster(
        pdf,
        dpi: PrintUnits.printDpi,
      ).first;
      final Uint8List png = await raster.toPng();

      if (!mounted) return;
      setState(() {
        _pdfBytes = pdf;
        _rasterPng = png;
        _plan = plan;
        _busy = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not render the card: $e';
      });
    }
  }

  Widget _body(StudentEntry entry, SchoolConfig? config) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 44,
                color: StatusColors.failed,
              ),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final Uint8List? png = _rasterPng;
    if (png == null || config == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.gutter),
      children: <Widget>[
        Center(child: _card(png, config.cardSize)),
        const SizedBox(height: 12),
        Center(child: _sizeCaption(config.cardSize)),
        const SizedBox(height: AppTheme.gutter),
        Center(child: SyncStatusChip(status: entry.syncStatus)),
        if (_plan?.hasWarnings ?? false) ...<Widget>[
          const SizedBox(height: AppTheme.gutter),
          for (final String w in _plan!.warnings) _warning(w),
        ],
        const SizedBox(height: AppTheme.gutter),
        _summary(entry),
      ],
    );
  }

  Widget _card(Uint8List png, CardSize size) {
    final Widget image = Container(
      decoration: BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Image.memory(png, fit: BoxFit.contain, gaplessPlayback: true),
    );

    if (!_trueSize) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: AspectRatio(aspectRatio: size.aspectRatio, child: image),
          ),
          if (_busy) const CircularProgressIndicator(),
        ],
      );
    }

    // Near-true size on screen.
    //
    // Be clear about what this is and is not. Flutter exposes no real physical
    // display DPI, so millimetres cannot be converted to screen pixels exactly.
    // A Flutter logical pixel is defined against a 160 dpi baseline (Android's
    // density-independent pixel), which makes this accurate on most Android
    // hardware and a close approximation elsewhere.
    //
    // The physical-size guarantee lives in the PDF, not here - that is what the
    // ruler test measures. This mode is a sanity check, and it is labelled as
    // approximate so nobody signs off a print run on it.
    const double logicalPixelsPerInch = 160.0;
    const double logicalPerMm = logicalPixelsPerInch / PrintUnits.mmPerInch;

    final double widthLogical = size.widthMm * logicalPerMm;
    final double heightLogical = size.heightMm * logicalPerMm;

    return Column(
      children: <Widget>[
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SizedBox(width: widthLogical, height: heightLogical, child: image),
            if (_busy) const CircularProgressIndicator(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Approximate true size - screens do not report their real DPI. '
          'For an exact check, print the PDF at 100% scale and measure it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _sizeCaption(CardSize size) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        size.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _warning(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StatusColors.pending.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: StatusColors.pending.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: StatusColors.pending,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(StudentEntry entry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Saved on this device',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'This entry is stored locally and will upload automatically when '
              'a connection is available.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(StudentEntry entry) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        0,
        AppTheme.gutter,
        12,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.pushReplacement('/entry/${entry.id}'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Print or share this card',
            onPressed: _pdfBytes == null ? null : () => _share(entry),
            icon: const Icon(Icons.print_outlined),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              // The entry is already committed by the form; this confirms the
              // operator has eyeballed the card. `go` rather than `push` so
              // Back from the receipt does not return to a preview of work
              // that is already submitted.
              onPressed: () => context.go('/submitted/${entry.id}'),
              icon: const Icon(Icons.check),
              label: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(StudentEntry entry) async {
    final Uint8List? bytes = _pdfBytes;
    if (bytes == null) return;
    await Printing.layoutPdf(
      name: '${entry.exportBaseName}.pdf',
      onLayout: (_) async => bytes,
    );
  }
}

/// Local `unawaited` so this file does not pull in `package:async` just for it.
void unawaited(Future<void> future) => future.ignore();
