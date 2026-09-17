import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A student photo packaged to travel inside Firestore instead of Cloud
/// Storage.
///
/// ## Why this exists
///
/// The card renderer and the admin panel both need the student's picture, and
/// until now the only route off the capturing device was Cloud Storage. That
/// bucket is not provisioned on this project and cannot be without moving the
/// Firebase project to the Blaze plan, so in practice **no photo ever left the
/// phone**: the office saw every approved card as "no photo - cannot print",
/// and the one job the system exists to do could not be done from any device
/// other than the one that took the picture.
///
/// Firestore is already provisioned, already has rules, and a document may
/// hold just under 1 MiB. A 360 x 450 card portrait re-encoded as JPEG is a
/// few tens of kilobytes. So the photo rides in Firestore until Storage
/// exists, at which point the sync worker prefers Storage again and this becomes
/// the fallback rather than the only path.
///
/// ## Why it is split in two
///
/// The full picture lives in its own document, `entries/{id}/media/photo`, and
/// only a thumbnail rides on the entry document itself. That split is the
/// whole reason this is affordable: the admin panel lists every submission
/// across every school in one query, and a full photo on each entry would mean
/// downloading tens of megabytes to render a table of names. The thumbnail is
/// small enough to carry everywhere; the full frame is fetched only when
/// something actually needs to render or print it.
@immutable
class InlinePhoto {
  const InlinePhoto({
    required this.thumbBase64,
    required this.fullBase64,
    required this.fullBytes,
    required this.width,
    required this.height,
  });

  /// Base64 JPEG, [kThumbLongEdge] px tall. Rides on the entry document.
  final String thumbBase64;

  /// Base64 JPEG at card resolution. Lives in the entry's `media/photo` doc.
  final String fullBase64;

  /// Decoded size of [fullBase64], for the size guard and for reporting.
  final int fullBytes;

  final int width;
  final int height;
}

/// Firestore's hard limit is 1,048,576 bytes for an entire document including
/// field names and overhead. The budget below is what the photo field alone
/// may occupy once base64-encoded, leaving generous room for everything else
/// in the document. Anything larger is re-encoded at lower quality rather than
/// rejected - a slightly softer photo beats a submission that cannot sync.
const int kMaxInlinePhotoChars = 700 * 1024;

/// Tall edge of the thumbnail. 128 px covers a 48 px avatar at 2.5x density
/// without being large enough to matter in a list of hundreds.
const int kThumbLongEdge = 128;

/// Re-encodes a processed card portrait for transport.
///
/// Runs on a background isolate: JPEG encoding a 360 x 450 image is only a few
/// milliseconds, but this is called from the sync worker while the operator is
/// still using the app, and there is no reason to spend those frames.
///
/// Returns null if [pngBytes] cannot be decoded, which is treated by the caller
/// as "no photo" rather than as an error - a corrupt file should not block the
/// student's details from reaching the office.
Future<InlinePhoto?> encodeInlinePhoto(Uint8List pngBytes) {
  return compute(_encodeInlinePhoto, pngBytes);
}

InlinePhoto? _encodeInlinePhoto(Uint8List pngBytes) {
  // `decodeImage` does not merely return null on rubbish - it probes each
  // format in turn, and a truncated file can make one of those probes read
  // past the end and throw. Catching here is what makes the documented
  // contract ("null means no photo") actually true, rather than leaving every
  // caller to guess which failures arrive as a return value and which as an
  // exception.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(pngBytes);
  } on Object {
    return null;
  }
  if (decoded == null) return null;

  // JPEG has no alpha channel. The processed photo is already composited onto
  // a white background by the capture pipeline, so flattening is a no-op here
  // - but a photo that arrived by some other route might still be transparent,
  // and without this it would encode as black.
  final img.Image opaque = decoded.hasAlpha
      ? img.compositeImage(
          img.Image(width: decoded.width, height: decoded.height)
            ..clear(img.ColorRgb8(255, 255, 255)),
          decoded,
        )
      : decoded;

  // Quality ladder. The first rung is what the photo should normally encode
  // at; the rest exist only so an unusually noisy image (which compresses
  // badly) degrades in sharpness instead of failing to sync at all.
  String? full;
  int fullBytes = 0;
  for (final int quality in <int>[82, 70, 58, 45]) {
    final Uint8List jpeg = img.encodeJpg(opaque, quality: quality);
    final String encoded = base64Encode(jpeg);
    if (encoded.length <= kMaxInlinePhotoChars) {
      full = encoded;
      fullBytes = jpeg.length;
      break;
    }
  }
  // Every rung overflowed - only possible for an image far larger than the
  // card portrait this pipeline produces. Scale it down and take what fits.
  if (full == null) {
    final img.Image shrunk = img.copyResize(opaque, height: 600);
    final Uint8List jpeg = img.encodeJpg(shrunk, quality: 60);
    full = base64Encode(jpeg);
    fullBytes = jpeg.length;
  }

  final img.Image thumb = img.copyResize(
    opaque,
    height: kThumbLongEdge,
    interpolation: img.Interpolation.average,
  );

  return InlinePhoto(
    thumbBase64: base64Encode(img.encodeJpg(thumb, quality: 72)),
    fullBase64: full,
    fullBytes: fullBytes,
    width: opaque.width,
    height: opaque.height,
  );
}
