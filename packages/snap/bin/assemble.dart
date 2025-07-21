// ignore_for_file: avoid_print

import 'dart:io';

import 'package:path/path.dart' as path;

import 'util/util.dart';

Future<void> main(List<String> args) async {
  try {
    await assembleScreenshots(
      Directory(path.join(topLevelSnapDir.path, 'assets')),
    );
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<void> assembleScreenshots(
  Directory inDirectory,
) async {
  final currentDir = Directory.current;
  final testDir = Directory(path.join(currentDir.path, 'test'));

  if (!testDir.existsSync()) {
    print('No test directory found.');
    return;
  }

  ensureDirectoryExists(inDirectory);

  var screenshotsMoved = 0;
  // Find all .snap directories under test/
  await for (final snapDir in findSnapDirectoriesInTest()) {
    screenshotsMoved += await _processSnapDirectory(
      snapDir,
      testDir.path,
      inDirectory.path,
    );
  }

  if (screenshotsMoved == 0) {
    print('No screenshots found to assemble.');
    return;
  }

  print('Assembled $screenshotsMoved screenshots in ${inDirectory.path}');
}

Future<int> _processSnapDirectory(
  Directory snapDir,
  String testBasePath,
  String targetBasePath,
) async {
  // Calculate the relative path from the test directory
  final relativePath = path.relative(
    path.dirname(snapDir.path),
    from: testBasePath,
  );

  var filesMoved = 0;
  await for (final entity in snapDir.list()) {
    if (entity is File && entity.path.endsWith('.png')) {
      final fileName = path.basename(entity.path);
      final targetDir = Directory(path.join(targetBasePath, relativePath));

      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      final targetPath = path.join(targetDir.path, fileName);

      // If target file exists, remove it first
      final targetFile = File(targetPath);
      if (targetFile.existsSync()) {
        await targetFile.delete();
      }

      // Move the file instead of copying
      await entity.rename(targetPath);
      filesMoved++;
    }
  }

  // Remove the source .snap directory if it's empty
  if ((await snapDir.list().toList()).isEmpty) {
    await snapDir.delete();
  }

  return filesMoved;
}
