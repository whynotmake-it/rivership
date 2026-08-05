// Portions of this file were adapted from passsy/spot v0.18.0
// (https://github.com/passsy/spot), Copyright 2022 Pascal Welsch, and were
// modified for Snaptest. Spot is licensed under the Apache License, Version
// 2.0. See LICENSE and NOTICE in the Snaptest package.

import 'dart:io';

/// Returns the Flutter SDK root directory based on the current flutter
/// executable.
Directory flutterSdkRoot() {
  final flutterTesterExe = Platform.executable;
  final String flutterRoot;
  if (Platform.isWindows) {
    flutterRoot = flutterTesterExe.split(r'\bin\cache\')[0];
  } else {
    flutterRoot = flutterTesterExe.split('/bin/cache/')[0];
  }
  return Directory(flutterRoot);
}
