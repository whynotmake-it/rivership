import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/motion_editor.dart';

void main() {
  test('copyable code uses dot shorthands and short decimals', () {
    expect(
      codeFor(
        const Motion.cupertino(
          duration: Duration(milliseconds: 500),
          bounce: 0.2,
        ),
      ),
      '.cupertino(duration: Duration(milliseconds: 500), bounce: 0.2)',
    );
    expect(
      codeFor(
        const Motion.cupertino(duration: Duration(seconds: 1), bounce: 0.25),
      ),
      '.cupertino(duration: Duration(milliseconds: 1000), bounce: 0.25)',
    );
    expect(
      codeFor(const Motion.linear(Duration(milliseconds: 300))),
      '.linear(Duration(milliseconds: 300))',
    );
    expect(
      codeFor(const Motion.curved(Duration(seconds: 1), Curves.easeOut)),
      '.curved(Duration(milliseconds: 1000), Curves.easeOut)',
    );
  });
}
