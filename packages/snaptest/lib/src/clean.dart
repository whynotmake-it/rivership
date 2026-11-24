import 'dart:io';

import 'package:meta/meta.dart';
import 'package:snaptest/src/constants.dart';
import 'package:snaptest/src/util.dart';

/// Cleans all snapshots from the top-level snap directory and all snap
/// directories under the `test/` folder.
///
/// Because this deletes **all** matching directories (`.snaptest/` by default),
/// call it once before your test suite runs (for example, from a script or CI
/// step, or via `dart run snaptest:clean`) rather than inside
/// `flutter_test_config.dart`, which runs once per test file and would wipe
/// snapshots from earlier files.
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
