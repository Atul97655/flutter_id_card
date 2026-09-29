import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';

/// A student's face, from whichever copy of it this device actually holds.
///
/// There are three, and until now every list in the app used only the first:
///
///  1. `localPhotoPath` - the file captured on this device.
///  2. `photoThumb` - a small base64 JPEG that rides on the entry document
///     and is synced down with it.
///  3. `remotePhotoUrl` - a Cloud Storage URL, for installations where
///     Storage is provisioned.
///
/// Reading only the first is why a reinstalled app showed a grey silhouette
/// for a card whose photo was captured, approved and synced months ago: the
/// photo files live in the app's documents directory, which an uninstall
/// wipes, while the thumbnail sat safely in Firestore the whole time and
/// nothing ever looked at it.
///
/// The fallback costs nothing when the file is present. It is reached through
/// `errorBuilder` rather than an `existsSync()` check, so the common case does
/// no synchronous disk IO - which matters, because these are drawn one per
/// row in a scrolling list.
class EntryPhoto extends StatefulWidget {
  const EntryPhoto({
    super.key,
    required this.entry,
    this.size = 44,
    this.width,
    this.height,
    this.shape = BoxShape.circle,
    this.radius,
    this.placeholderIcon = Icons.person,
  });

  final StudentEntry entry;

  /// Convenience for a square. [width] and [height] win when given, which is
  /// what the saved-entries list needs - it shows the photo at the card's
  /// own 1.2:1.5 crop rather than as a circle.
  final double size;
  final double? width;
  final double? height;

  final BoxShape shape;

  /// Only used when [shape] is [BoxShape.rectangle].
  final BorderRadius? radius;

  final IconData placeholderIcon;

  @override
  State<EntryPhoto> createState() => _EntryPhotoState();
}

class _EntryPhotoState extends State<EntryPhoto> {
  /// Decoded once rather than on every build. `MemoryImage` keys its cache on
  /// the byte list, so decoding afresh each build would defeat the image
  /// cache and re-upload the texture on every frame of a scroll.
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _decodeThumb();
  }

  @override
  void didUpdateWidget(EntryPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.photoThumb != widget.entry.photoThumb) {
      _decodeThumb();
    }
  }

  void _decodeThumb() {
    final String? raw = widget.entry.photoThumb;
    if (raw == null || raw.isEmpty) {
      _thumb = null;
      return;
    }
    try {
      // Stored as raw base64 JPEG, but tolerate a data: prefix in case one
      // ever arrives from elsewhere.
      final int comma = raw.indexOf(',');
      _thumb = base64Decode(comma >= 0 ? raw.substring(comma + 1) : raw);
    } on Object {
      // A corrupt thumbnail is not worth an exception in a list row.
      _thumb = null;
    }
  }

  double get _w => widget.width ?? widget.size;
  double get _h => widget.height ?? widget.size;

  Widget _placeholder() => Icon(
    widget.placeholderIcon,
    size: (_w < _h ? _w : _h) * 0.55,
    color: AppColors.inkMuted,
  );

  /// Everything after the local file: the synced thumbnail, then the remote
  /// URL, then a silhouette.
  Widget _remoteOrPlaceholder() {
    final Uint8List? thumb = _thumb;
    if (thumb != null) {
      return Image.memory(
        thumb,
        fit: BoxFit.cover,
        width: _w,
        height: _h,
        gaplessPlayback: true,
        errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
            _placeholder(),
      );
    }

    final String? url = widget.entry.remotePhotoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: _w,
        height: _h,
        errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
            _placeholder(),
      );
    }

    return _placeholder();
  }

  @override
  Widget build(BuildContext context) {
    final String? path = widget.entry.localPhotoPath;

    // Decided with a synchronous existsSync() rather than by waiting for
    // Image.file to fail. Two reasons, and the second is the important one:
    //
    //  - On a device, waiting for the error means a visible flash of empty
    //    tile before the thumbnail swaps in, on every row at once.
    //  - Image.file reports a missing file asynchronously, off the frame
    //    pipeline, so a widget test can never observe the fallback. A
    //    behaviour that cannot be tested is one that quietly rots.
    //
    // The cost is a stat() per row, which is microseconds, and the
    // saved-entries list already did exactly this before.
    final bool hasLocal =
        path != null && path.isNotEmpty && File(path).existsSync();

    final Widget image = !hasLocal
        ? _remoteOrPlaceholder()
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            width: _w,
            height: _h,
            // Second line of defence: the file exists but is unreadable or
            // corrupt. Same fallback.
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                _remoteOrPlaceholder(),
          );

    return Container(
      width: _w,
      height: _h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.mist,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.rectangle
            ? (widget.radius ?? BorderRadius.circular(10))
            : null,
      ),
      child: Center(child: image),
    );
  }
}
