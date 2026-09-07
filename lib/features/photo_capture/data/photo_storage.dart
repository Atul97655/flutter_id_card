import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Where processed student photos live on the device.
///
/// Photos are kept in the app's documents directory rather than the cache:
/// an entry can sit unsynced for days if a school is offline, and the OS is
/// free to purge the cache directory at any time. Losing the photo would leave
/// an un-printable record with no way to recover it.
class PhotoStorage {
  PhotoStorage({this.baseDirectory});

  final Directory? baseDirectory;
  static const String _folder = 'student_photos';
  static const Uuid _uuid = Uuid();

  Future<Directory> directory() async {
    final Directory base =
        baseDirectory ?? await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(base.path, _folder));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Writes processed bytes and returns the absolute path.
  ///
  /// If [sourceRawPath] is provided, copies the original uncropped capture
  /// alongside the processed photo as `<id>_raw.<ext>` so it can be re-adjusted
  /// later without having to retake the student's photo.
  Future<String> save(Uint8List pngBytes, {String? sourceRawPath}) async {
    final Directory dir = await directory();
    final String id = _uuid.v4();
    final File file = File(p.join(dir.path, '$id.png'));
    await file.writeAsBytes(pngBytes, flush: true);

    if (sourceRawPath != null && sourceRawPath.isNotEmpty) {
      final File rawSource = File(sourceRawPath);
      if (rawSource.existsSync()) {
        final String rawExt = p.extension(sourceRawPath).isNotEmpty
            ? p.extension(sourceRawPath)
            : '.jpg';
        final File rawTarget = File(p.join(dir.path, '${id}_raw$rawExt'));
        await rawSource.copy(rawTarget.path);
      }
    }

    return file.path;
  }

  /// Returns the path to the raw original capture if it exists for [processedPath].
  String? rawPathFor(String? processedPath) {
    if (processedPath == null || processedPath.isEmpty) return null;
    final String dir = p.dirname(processedPath);
    final String base = p.basenameWithoutExtension(processedPath);
    for (final String ext in <String>['.jpg', '.jpeg', '.png']) {
      final String candidate = p.join(dir, '${base}_raw$ext');
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Deletes a photo and its accompanying raw capture if present. Failures are
  /// ignored - an orphaned file is a housekeeping problem, not something worth
  /// interrupting the operator for.
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final File file = File(path);
      if (file.existsSync()) await file.delete();
      final String? raw = rawPathFor(path);
      if (raw != null) {
        final File rawFile = File(raw);
        if (rawFile.existsSync()) await rawFile.delete();
      }
    } on FileSystemException {
      // See doc comment.
    }
  }

  /// Total bytes held in the photo folder, for the storage readout in settings.
  Future<int> usedBytes() async {
    final Directory dir = await directory();
    int total = 0;
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
