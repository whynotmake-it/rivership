// ignore_for_file: avoid_print

import 'dart:io';

import 'package:snaptest/src/constants.dart';

import 'util/util.dart';

Future<void> main(List<String> args) async {
  try {
    final dirName = args.isNotEmpty ? args[0] : kDefaultSnaptestDir;
    await cleanSnapshots(getTopLevelSnapDir(dirName), dirName);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<void> cleanSnapshots(Directory topLevelSnapDir, String dirName) async {
  var snapshotsDeleted = 0;

  // Clean the top level snap directory
  deleteDirectoryIfExists(topLevelSnapDir);

  // Clean all snap directories under test/
  await for (final snapDir in findSnapDirectoriesInTest(dirName)) {
    deleteDirectoryIfExists(snapDir);
    snapshotsDeleted++;
  }

  if (snapshotsDeleted == 0) {
    print('No snapshots found to clean.');
    return;
  }

  print('Cleaned snapshots from $snapshotsDeleted locations');
}
