/// The build identity, shown in the app so "which build am I running?" is a
/// question anyone can answer by looking.
///
/// This exists because seven release APKs went out carrying the same
/// `1.1.1+4`. Android treats an APK with an unchanged versionCode as the same
/// build, so an install could silently do nothing, and nobody - including the
/// person who made the build - could tell from the running app whether a fix
/// was actually in it. Hours were spent on "the fix isn't there" when the
/// real question was "is this even the new build".
///
/// Kept in sync with pubspec.yaml by a test, not by discipline. See
/// `test/app_version_test.dart` - it reads pubspec.yaml and fails if these
/// drift, so bumping one without the other cannot reach a commit.
library;

/// Matches `version:` in pubspec.yaml, before the `+`.
const String kAppVersion = '1.2.0';

/// Matches the number after the `+`. This is the Android versionCode, and it
/// MUST increase on every build handed to anyone, or the install is a no-op.
const int kBuildNumber = 5;

/// What the Profile screen shows.
const String kVersionLabel = 'v$kAppVersion ($kBuildNumber)';
