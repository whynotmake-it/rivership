import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:springster/springster.dart';

import 'util.dart';

void main() {
  group('CupertinoMotion', () {
    void printConstructor(SpringDescription spring, String name) {
      // ignore: avoid_print
      print('''
static const $name = CupertinoMotion._(
  SpringDescription(
    mass: ${spring.mass},
    stiffness: ${spring.stiffness},
    damping: ${spring.damping},
  ),
);
''');
    }

    test('generate constant SpringDescriptions', () async {
      try {
        expect(CupertinoMotion.standard.description, equalsSpring(standard));
        expect(CupertinoMotion.bouncy.description, equalsSpring(bouncy));
        expect(CupertinoMotion.snappy.description, equalsSpring(snappy));
        expect(CupertinoMotion.smooth.description, equalsSpring(smooth));
        expect(
          CupertinoMotion.interactive.description,
          equalsSpring(interactive),
        );
      } on TestFailure {
        // If we fail we print the correct constructors:
        printConstructor(bouncy, 'bouncy');
        printConstructor(snappy, 'snappy');
        printConstructor(smooth, 'smooth');
        printConstructor(interactive, 'interactive');
        rethrow;
      }
    });
  });
}

/// A smooth spring with no bounce.
///
/// This uses the [default values for iOS](https://developer.apple.com/documentation/swiftui/animation/default).
final standard = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 550),
);

/// A spring with a predefined duration and higher amount of bounce.
final bouncy = SpringDescription.withDurationAndBounce(bounce: 0.3);

/// A snappy spring with a damping fraction of 0.85.
final snappy = SpringDescription.withDurationAndBounce(bounce: 0.15);

/// A smooth spring with a predefined duration and no bounce.
final smooth = SpringDescription.withDurationAndBounce();

/// A spring animation with a lower response value,
/// intended for driving interactive animations.
final interactive = SpringDescription.withDurationAndBounce(
  bounce: 0.14,
  duration: const Duration(milliseconds: 150),
);
