// ignore_for_file: avoid_print

import 'dart:io';

import 'util/util.dart';

Future<void> main(List<String> args) async {
  try {
    await cleanSnapshots(topLevelSnapDir);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<void> cleanSnapshots(Directory topLevelSnapDir) async {
  var snapshotsDeleted = 0;

  // Clean the top level .snap directory
  deleteDirectoryIfExists(topLevelSnapDir);

  // Clean all .snap directories under test/
  await for (final snapDir in findSnapDirectoriesInTest()) {
    deleteDirectoryIfExists(snapDir);
    snapshotsDeleted++;
  }

  if (snapshotsDeleted == 0) {
    print('No snapshots found to clean.');
    return;
  }

  print('Cleaned snapshots from $snapshotsDeleted locations');
}
