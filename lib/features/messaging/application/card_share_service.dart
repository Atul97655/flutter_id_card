import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Turns a student's card into a file that can be sent in a conversation.
///
/// Rasterised from the real PDF rather than drawn separately, for the same
/// reason the preview screen does it: it is the only way to guarantee that
/// what the office opens in a chat is the same artwork that comes off the
/// printer. A second rendering path would drift from the first, and the
/// drift would only show up on a card somebody had already handed to a child.
class CardShareService {
  const CardShareService();

  /// Renders [entry] and writes it to a temporary PNG.
  ///
  /// PNG rather than PDF because this is going into a chat bubble. A document
  /// chip would make the office tap to find out which card arrived, where the
  /// whole reason to send one is so they can see it without opening anything.
  /// The printable artifact remains the Print Centre's job.
  Future<SharedCard> render({
    required StudentEntry entry,
    required SchoolConfig config,
    required CardTemplate template,
  }) async {
    final IdCardRenderer renderer = await IdCardRenderer.load();
    final CardSize size = config.cardSize;

    final Uint8List pdf = await renderer.buildSingleCardPdf(
      entry: entry,
      config: config,
      template: template,
      size: size,
    );

    final PdfRaster raster = await Printing.raster(
      pdf,
      dpi: PrintUnits.printDpi,
    ).first;
    final Uint8List png = await raster.toPng();

    // A cache directory, not documents: this file exists only long enough to
    // be uploaded, and the copy that matters afterwards is the one in the
    // conversation. Leaving these in documents would grow forever on a phone
    // that sends a card a day.
    final Directory dir = await getTemporaryDirectory();
    final File file = File(
      p.join(
        dir.path,
        'card_${entry.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(png, flush: true);

    return SharedCard(file: file, fileName: '${entry.exportBaseName}.png');
  }
}

/// A rendered card on disk, ready to attach.
class SharedCard {
  const SharedCard({required this.file, required this.fileName});

  final File file;

  /// `ADITYA_KUMAR_10TH.png` - the same naming the single-card export uses,
  /// so a card that arrives by chat and a card that arrives by export are
  /// recognisably the same thing in a downloads folder.
  final String fileName;
}
