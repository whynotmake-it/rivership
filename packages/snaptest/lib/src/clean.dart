import 'dart:io';

import 'package:meta/meta.dart';
import 'package:snaptest/src/constants.dart';
import 'package:snaptest/src/util.dart';

/// Cleans all snapshots from the top level snap directory and all snap
/// directories under the test/ folder.
///
/// You can add this to your `flutter_test_config.dart` file to automatically
/// clean screenshots from all `.snaptest/` directories before each test run:
///
/// ```dart
/// // flutter_test_config.dart
///
/// import 'package:snaptest/snaptest.dart';
///
/// Future<void> testExecutable(Future<void> Function() testMain) async {
///   await cleanSnaps();
///   await testMain();
/// }
/// ```
Future<void> cleanSnaps([
  String dirName = kDefaultSnaptestDir,
]) async {
  await internalCleanSnapshots(getTopLevelSnapDir(dirName), dirName);
}

@internal
Future<int> internalCleanSnapshots(
  Directory? topLevelSnapDir,
  String dirName,
) async {
  var snapshotsDeleted = 0;

  if (topLevelSnapDir case final dir?) {
    // Clean the top level snap directory
    deleteDirectoryIfExists(dir);
  }

  // Clean all snap directories under test/
  await for (final snapDir in findSnapDirectoriesInTest(dirName)) {
    deleteDirectoryIfExists(snapDir);
    snapshotsDeleted++;
  }

  return snapshotsDeleted;
}
