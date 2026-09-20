import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A chat attachment packaged to travel inside Firestore instead of Cloud
/// Storage.
///
/// The same problem as `InlinePhoto` in `inline_photo.dart`, in the one other
/// place it bites: Storage is not provisioned on this project, so picking a
/// photo in a conversation failed with a raw Firebase error and the message
/// never sent. An earlier change made that error readable; it did not make the
/// feature work. This does.
///
/// Two shapes, because two kinds of file:
///
///   * **Images** are re-encoded and shrunk. A phone camera JPEG is 3-6 MB,
///     which no document can hold, and nobody needs a 12 MP frame in a chat
///     bubble. They also get a thumbnail, so a conversation renders without
///     fetching a full frame per message.
///   * **Everything else** (PDF, Word, Excel, text) is sent byte-for-byte.
///     Re-encoding a document would corrupt it, so the only question is
///     whether it fits - and if it does not, the sender is told plainly rather
///     than having it silently truncated.
@immutable
class InlineAttachment {
  const InlineAttachment({
    required this.dataBase64,
    required this.contentType,
    required this.bytes,
    this.thumbBase64,
    this.width,
    this.height,
  });

  /// The whole file, base64. Lives in the message's `media/file` document.
  final String dataBase64;

  final String contentType;

  /// Decoded size of [dataBase64], for the size guard and the UI.
  final int bytes;

  /// Base64 JPEG preview for images, small enough to ride on the message
  /// document itself. Null for documents, which have nothing to preview.
  final String? thumbBase64;

  final int? width;
  final int? height;

  bool get isImage => contentType.startsWith('image/');
}

/// Why an attachment could not be packaged.
///
/// A sealed result rather than an exception: "this file is too big" is a
/// normal thing for a person to do, not an error condition, and it needs to
/// reach them as a sentence rather than a stack trace.
@immutable
class InlineAttachmentFailure {
  const InlineAttachmentFailure(this.message);
  final String message;
}

/// Firestore caps a document just under 1 MiB including field names and
/// overhead. This is what the base64 payload alone may occupy.
const int kMaxInlineAttachmentChars = 700 * 1024;

/// Longest edge an inlined chat image is resampled to.
///
/// 1280 keeps a photo of a document or a whiteboard readable when opened full
/// screen, which is what these are actually used for, while landing well
/// inside the budget above at ordinary JPEG quality.
const int kInlineImageLongEdge = 1280;

/// Tall edge of the bubble preview.
const int kInlineThumbLongEdge = 256;

/// Packages [bytes] for transport inside Firestore.
///
/// Returns an [InlineAttachment] on success or an [InlineAttachmentFailure]
/// with a sentence fit to show the sender. Runs on a background isolate:
/// resampling a camera photo is tens of milliseconds and the composer should
/// not drop frames while it happens.
Future<Object> encodeInlineAttachment({
  required Uint8List bytes,
  required String contentType,
}) {
  return compute(
    _encodeInlineAttachment,
    _Request(bytes: bytes, contentType: contentType),
  );
}

@immutable
class _Request {
  const _Request({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
}

Object _encodeInlineAttachment(_Request req) {
  if (req.contentType.startsWith('image/')) {
    return _encodeImage(req.bytes);
  }

  // Not an image: the bytes are the file and must not be touched.
  final String encoded = base64Encode(req.bytes);
  if (encoded.length > kMaxInlineAttachmentChars) {
    return InlineAttachmentFailure(
      'That file is ${_mb(req.bytes.length)} MB, which is too large to send '
      'while file storage is switched off for this project. Under '
      '${_mb((kMaxInlineAttachmentChars * 3) ~/ 4)} MB will send.',
    );
  }
  return InlineAttachment(
    dataBase64: encoded,
    contentType: req.contentType,
    bytes: req.bytes.length,
  );
}

Object _encodeImage(Uint8List bytes) {
  // Same trap as the student photo pipeline: `decodeImage` probes each format
  // in turn and a truncated file can make one of those probes read past the
  // end and throw, rather than returning null.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    return const InlineAttachmentFailure(
      'That image could not be read. It may be damaged - try taking it again.',
    );
  }
  if (decoded == null) {
    return const InlineAttachmentFailure(
      'That image could not be read. It may be damaged - try taking it again.',
    );
  }

  final img.Image oriented = img.bakeOrientation(decoded);

  // Only ever downscale. Enlarging a small image would inflate it towards the
  // budget for no gain in what anyone can actually see.
  final int longEdge = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final img.Image sized = longEdge <= kInlineImageLongEdge
      ? oriented
      : (oriented.width >= oriented.height
            ? img.copyResize(oriented, width: kInlineImageLongEdge)
            : img.copyResize(oriented, height: kInlineImageLongEdge));

  // Quality ladder. The first rung is what a photo should normally encode at;
  // the rest exist so an unusually noisy image degrades in sharpness rather
  // than failing to send.
  String? data;
  int size = 0;
  for (final int quality in <int>[80, 68, 55, 42]) {
    final Uint8List jpeg = img.encodeJpg(sized, quality: quality);
    final String encoded = base64Encode(jpeg);
    if (encoded.length <= kMaxInlineAttachmentChars) {
      data = encoded;
      size = jpeg.length;
      break;
    }
  }
  if (data == null) {
    final img.Image smaller = img.copyResize(sized, width: 720);
    final Uint8List jpeg = img.encodeJpg(smaller, quality: 60);
    data = base64Encode(jpeg);
    size = jpeg.length;
  }

  final img.Image thumb = sized.width >= sized.height
      ? img.copyResize(
          sized,
          width: kInlineThumbLongEdge,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          sized,
          height: kInlineThumbLongEdge,
          interpolation: img.Interpolation.average,
        );

  return InlineAttachment(
    dataBase64: data,
    contentType: 'image/jpeg',
    bytes: size,
    thumbBase64: base64Encode(img.encodeJpg(thumb, quality: 70)),
    width: sized.width,
    height: sized.height,
  );
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
