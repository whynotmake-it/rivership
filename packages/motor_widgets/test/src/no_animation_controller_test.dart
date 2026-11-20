import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter animation APIs that restart on interruption or use curves. The
/// widgets in this package are driven by Motor springs only.
final _forbidden = RegExp(
  r'\b(AnimationController|\w*Tween|CurvedAnimation|ImplicitlyAnimatedWidget|'
  r'AnimatedWidgetBaseState|Curves?)\b'
  // Constructing a Flutter implicit animation widget. Its static builders,
  // such as AnimatedSwitcher.defaultTransitionBuilder, are fine.
  r'|\bAnimated[A-Z]\w*\(',
);

void main() {
  test(
    'lib uses no AnimationController, tween, curve or implicit animation',
    () {
      final offenders = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          // Docs may name the Flutter widgets these replace.
          if (line.startsWith('///') || line.startsWith('//')) continue;
          if (_forbidden.hasMatch(line)) {
            offenders.add('${file.path}:${i + 1}: $line');
          }
        }
      }
      expect(files, isNotEmpty);
      expect(offenders, isEmpty);
    },
  );
}
