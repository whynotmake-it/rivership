@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('turns uses Motor/fixed_ticker only and never imports coil', () {
    final banned = {
      'TickerProviderStateMixin': RegExp(
        r'\b(Single)?TickerProviderStateMixin\b',
      ),
      'AnimationController': RegExp(r'\bAnimationController\b'),
      'package:coil/': RegExp('package:coil/'),
    };
    final violations = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (n, line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//'))
              for (final MapEntry(key: name, value: pattern) in banned.entries)
                if (pattern.hasMatch(line)) '${file.path}:${n + 1} uses $name',
    ];
    expect(violations, isEmpty);
  });
}
