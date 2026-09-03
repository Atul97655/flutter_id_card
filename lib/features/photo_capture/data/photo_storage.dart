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
  PhotoStorage();

  static const String _folder = 'student_photos';
  static const Uuid _uuid = Uuid();

  Future<Directory> directory() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(base.path, _folder));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Writes processed bytes and returns the absolute path.
  Future<String> save(Uint8List pngBytes) async {
    final Directory dir = await directory();
    final File file = File(p.join(dir.path, '${_uuid.v4()}.png'));
    await file.writeAsBytes(pngBytes, flush: true);
    return file.path;
  }

  /// Deletes a photo that is no longer referenced. Failures are ignored - an
  /// orphaned file is a housekeeping problem, not something worth interrupting
  /// the operator for.
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final File file = File(path);
      if (file.existsSync()) await file.delete();
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
