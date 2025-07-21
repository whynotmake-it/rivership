import 'dart:io';

import 'package:path/path.dart' as path;

/// Gets the top level .snapper directory
Directory get topLevelSnapDir => Directory(
  path.join(Directory.current.path, '.snapper'),
);

/// Gets all .snapper directories under the test folder
Stream<Directory> findSnapDirectoriesInTest() async* {
  final currentDir = Directory.current;
  final testDir = Directory(path.join(currentDir.path, 'test'));

  if (!testDir.existsSync()) {
    // ignore: avoid_print
    print('No test directory found.');
    return;
  }

  await for (final entity in testDir.list(recursive: true)) {
    if (entity is Directory && path.basename(entity.path) == '.snapper') {
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
