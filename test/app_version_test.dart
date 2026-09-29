import 'dart:io';

import 'package:flutter_id_card/shared/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// The version constants must match pubspec.yaml.
///
/// Not a nicety. Seven release APKs went out carrying an unchanged
/// `1.1.1+4`, which Android reads as the same build - so installing a new one
/// over the old could do nothing at all, and neither the person installing it
/// nor the person who built it could tell. The constants only help if they
/// are true, so this makes drift impossible rather than merely discouraged.
void main() {
  test('app_version.dart agrees with pubspec.yaml', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    final RegExpMatch? m = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(
      m,
      isNotNull,
      reason: 'pubspec.yaml needs a "version: x.y.z+n" line',
    );

    expect(
      kAppVersion,
      m!.group(1),
      reason: 'kAppVersion drifted from pubspec.yaml',
    );
    expect(
      kBuildNumber,
      int.parse(m.group(2)!),
      reason:
          'kBuildNumber drifted from pubspec.yaml - an APK built with a '
          'stale build number installs as a no-op',
    );
  });

  test('the label reads the way it is shown on screen', () {
    expect(kVersionLabel, 'v$kAppVersion ($kBuildNumber)');
  });
}
