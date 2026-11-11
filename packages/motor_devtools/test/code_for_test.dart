import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/motion_editor.dart';

void main() {
  group('copied code', () {
    test('names the Motion class, so it compiles on every supported SDK', () {
      expect(
        codeFor(
          const Motion.cupertino(
            duration: Duration(milliseconds: 400),
            bounce: 0.2,
          ),
        ),
        'Motion.cupertino(duration: Duration(milliseconds: 400), '
        'bounce: 0.2)',
      );
      expect(
        codeFor(const Motion.linear(Duration(milliseconds: 300))),
        'Motion.linear(Duration(milliseconds: 300))',
      );
      expect(
        codeFor(const Motion.curved(Duration(seconds: 1), Curves.easeOut)),
        'Motion.curved(Duration(milliseconds: 1000), Curves.easeOut)',
      );
    });

    test('writes short decimals', () {
      expect(
        codeFor(
          const Motion.cupertino(duration: Duration(seconds: 1), bounce: 0.25),
        ),
        'Motion.cupertino(duration: Duration(milliseconds: 1000), '
        'bounce: 0.25)',
      );
    });

    test('keeps snapToEnd when it is off', () {
      expect(
        codeFor(
          const CupertinoMotion(
            bounce: 0.2,
            snapToEnd: false,
          ),
        ),
        'Motion.cupertino(duration: Duration(milliseconds: 500), '
        'bounce: 0.2, snapToEnd: false)',
      );
    });

    test('is null for a curve it cannot name', () {
      expect(
        codeFor(const Motion.curved(Duration(seconds: 1), Curves.bounceOut)),
        isNull,
      );
    });
  });
}
