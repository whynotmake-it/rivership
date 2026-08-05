import 'dart:io';

/// Returns the Flutter SDK root directory based on the current flutter
/// executable.
Directory flutterSdkRoot() => flutterSdkRootFromExecutable(
  Platform.executable,
  windows: Platform.isWindows,
);

/// Locates a Flutter SDK above the `bin/cache` segment of [executable].
///
/// Flutter widget tests run through `flutter_tester`, which is stored below
/// that cache directory. A [StateError] is thrown for unrelated executables
/// instead of silently returning an invalid directory.
Directory flutterSdkRootFromExecutable(
  String executable, {
  required bool windows,
}) {
  final normalized = executable.replaceAll(r'\', '/');
  const cacheSegment = '/bin/cache/';
  final cacheIndex = normalized.toLowerCase().indexOf(cacheSegment);

  if (cacheIndex < 0) {
    throw StateError(
      'Cannot locate the Flutter SDK from executable "$executable".',
    );
  }

  final root = normalized.substring(0, cacheIndex);
  return Directory(windows ? root.replaceAll('/', r'\') : root);
}
