import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:snaptest/src/constants.dart';

/// Gets the top level .snaptest directory
Directory get topLevelSnapDir => getTopLevelSnapDir(kDefaultSnaptestDir);

/// Gets the top level snap directory with configurable name
Directory getTopLevelSnapDir(String dirName) => Directory(
  path.join(Directory.current.path, dirName),
);

/// Gets all .snaptest directories under the test folder
Stream<Directory> findSnapDirectoriesInTest([
  String dirName = kDefaultSnaptestDir,
]) async* {
  final currentDir = Directory.current;
  final testDir = Directory(path.join(currentDir.path, 'test'));

  if (!testDir.existsSync()) {
    // ignore: avoid_print
    print('No test directory found.');
    return;
  }

  await for (final entity in testDir.list(recursive: true)) {
    if (entity is Directory && path.basename(entity.path) == dirName) {
      yield entity;
    }
  }
}

/// Ensures the directory exists
void ensureDirectoryExists(Directory dir) {
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
}

/// Deletes a directory if it exists
void deleteDirectoryIfExists(Directory dir) {
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}
