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
