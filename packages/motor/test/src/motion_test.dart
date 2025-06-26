import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('CupertinoMotion', () {
    test('generate constant SpringDescriptions', () async {
      expect(const CupertinoMotion().description, equalsSpring(standard));
      expect(const CupertinoMotion.bouncy().description, equalsSpring(bouncy));
      expect(const CupertinoMotion.snappy().description, equalsSpring(snappy));
      expect(const CupertinoMotion.smooth().description, equalsSpring(smooth));
      expect(
        const CupertinoMotion.interactive().description,
        equalsSpring(interactive),
      );
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
